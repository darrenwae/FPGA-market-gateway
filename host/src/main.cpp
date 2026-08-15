#include "gateway/host_gateway.hpp"
#include "normalizer/itch/itch_file_reader.hpp"
#include "normalizer/runtime/spsc_ringbuffer.hpp"
#include "normalizer/transport/udp_receiver.hpp"
#include "normalizer/transport/udp_sender.hpp"
#include "normalizer/util/endian.hpp"
#include <winsock2.h>
#include <windows.h>
#include <limits>
#include <cstdint>
#include <cstddef>
#include <thread>
#include <filesystem>
#include <algorithm>
#include <array>
#include <atomic>
#include <charconv>
#include <csignal>
#include <functional>
#include <immintrin.h>
#include <iostream>
#include <memory>
#include <string_view>
#include <utility>
#include <vector>

namespace {

    class WinsockRuntime {
        public:
        WinsockRuntime() noexcept {
            WSADATA data{};
            initialized_ = ::WSAStartup(MAKEWORD(2, 2), &data) == 0;
        }
        ~WinsockRuntime() noexcept {
            if (initialized_) {
                static_cast<void>(::WSACleanup());
            }
        }
        WinsockRuntime(const WinsockRuntime&) = delete;
        WinsockRuntime& operator=(const WinsockRuntime&) = delete;
        [[nodiscard]] bool isInitialized() const noexcept {
            return initialized_;
        }
        
        private:
        bool initialized_{false};
    };

    constexpr std::size_t SymbolCapacity{16'384};
    constexpr std::size_t ReplayQueueCapacity{1'048'576};
    constexpr std::uint64_t MaxTobBatchDelayNs{1'000};

    constexpr char DownstreamHostIpAddress[]{"192.168.3.1"};
    constexpr char DownstreamFpgaIpAddress[]{"192.168.3.2"};
    constexpr char UpstreamHostIpAddress[]{"192.168.2.1"};
    constexpr char UpstreamFpgaIpAddress[]{"192.168.2.2"};
    constexpr std::uint16_t FpgaUdpPort{5000};
    constexpr std::uint16_t HostUdpPort{5001};

    using ReplayQueue = normalizer::runtime::SpscRingBuffer<normalizer::itch::RawMessage,ReplayQueueCapacity>;

    enum class ReplayStatus : std::uint8_t {
        Starting,
        Ready,
        Running,
        Complete,
        Stopped,
        AffinityFailed,
        FileOpenFailed,
        ReadFailed,
        InvalidTimestamp,
        QueueOverflow,
    };

    volatile std::sig_atomic_t interruptRequested{0};

    void handleInterrupt(int) noexcept {
        interruptRequested = 1;
    }

    double performanceCounterNanosecondsPerTick() noexcept {
        LARGE_INTEGER frequency{};
        ::QueryPerformanceFrequency(&frequency);
        return 1'000'000'000.0 / static_cast<double>(frequency.QuadPart);
    }
    
    std::uint64_t monotonicTimeNs() noexcept {
        static const double NanosecondsPerTick{performanceCounterNanosecondsPerTick()};
        LARGE_INTEGER counter{};
        ::QueryPerformanceCounter(&counter);
        return static_cast<std::uint64_t>(static_cast<double>(counter.QuadPart) *NanosecondsPerTick);
    }


    bool parseCpu(const char* text, unsigned& cpu) noexcept {
        const std::string_view value{text};
        const auto result = std::from_chars(value.data(), value.data() + value.size(), cpu);

        return result.ec == std::errc{} && result.ptr == value.data() + value.size();
    }


    bool pinCurrentThread(unsigned cpu) noexcept {
        if (cpu >= static_cast<unsigned>(std::numeric_limits<DWORD_PTR>::digits)) {
            return false;
        }
        const DWORD_PTR affinityMask{DWORD_PTR{1} << cpu};
        return ::SetThreadAffinityMask(::GetCurrentThread(),affinityMask) != 0;
    }


    bool discoverSymbols(const std::filesystem::path& filePath, std::vector<std::uint16_t>& symbols){
        normalizer::itch::FileReader reader{filePath};

        if (!reader.isOpen()) {
            std::cerr << "Unable to open ITCH file\n";
            return false;
        }

        std::array<bool, SymbolCapacity> seen{};
        normalizer::itch::RawMessage message{};

        while (true) {
            const auto status = reader.readNextMessage(message);
            if (status == normalizer::itch::ReadStatus::EndOfFile) {
                break;
            }

            if (status != normalizer::itch::ReadStatus::Ok || message.length == 0) {
                std::cerr << "Invalid ITCH file during symbol scan\n";
                return false;
            }

            if (message.payload[0] != static_cast<std::uint8_t>('R')) {
                continue;
            }

            if (message.length != 39) {
                std::cerr << "Invalid Stock Directory message\n";
                return false;
            }

            const auto stockLocate = normalizer::util::readBE16(message.payload.data() + 1);

            if (stockLocate == 0 || stockLocate >= SymbolCapacity) {
                std::cerr << "Stock locate exceeds FPGA symbol capacity\n";
                return false;
            }

            if (!seen[stockLocate]) {
                seen[stockLocate] = true;
                symbols.push_back(stockLocate);
            }
        }

        if (symbols.empty()) {
            std::cerr << "No Stock Directory messages found\n";
            return false;
        }

        std::sort(symbols.begin(), symbols.end());
        return true;
    }

    bool extractItchTimestamp(const normalizer::itch::RawMessage& message,std::uint64_t& timestamp) noexcept {
        if (message.length < 11) {
            return false;
        }
        timestamp = normalizer::util::readBE48(message.payload.data() + 5);
        return true;
    }


    void runReplay(const std::filesystem::path& filePath, unsigned replayCpu, ReplayQueue& queue, std::atomic<bool>& startReplay, std::atomic<bool>& stopRequested, std::atomic<ReplayStatus>& replayStatus) {
        if (!pinCurrentThread(replayCpu)) {
            replayStatus.store(ReplayStatus::AffinityFailed, std::memory_order_release);
            return;
        }

        normalizer::itch::FileReader reader{filePath};

        if (!reader.isOpen()) {
            replayStatus.store(ReplayStatus::FileOpenFailed, std::memory_order_release);
            return;
        }

        normalizer::itch::RawMessage message{};
        auto readStatus = reader.readNextMessage(message);

        if (readStatus != normalizer::itch::ReadStatus::Ok) {
            replayStatus.store(readStatus == normalizer::itch::ReadStatus::EndOfFile ? ReplayStatus::Complete : ReplayStatus::ReadFailed, std::memory_order_release);
            return;
        }

        std::uint64_t firstTimestamp{};
        if (!extractItchTimestamp(message, firstTimestamp)) {
            replayStatus.store(ReplayStatus::InvalidTimestamp, std::memory_order_release);
            return;
        }

        replayStatus.store(ReplayStatus::Ready, std::memory_order_release);
        while (!startReplay.load(std::memory_order_acquire)) {
            if (stopRequested.load(std::memory_order_relaxed)) {
                replayStatus.store(ReplayStatus::Stopped, std::memory_order_release);
                return;
            }
            _mm_pause();
        }

        const std::uint64_t replayStartTime = monotonicTimeNs();
        replayStatus.store(ReplayStatus::Running, std::memory_order_release);

        while (true) {
            std::uint64_t messageTimestamp{};

            if (!extractItchTimestamp(message, messageTimestamp) || messageTimestamp < firstTimestamp) {
                replayStatus.store(ReplayStatus::InvalidTimestamp, std::memory_order_release);
                return;
            }

            const std::uint64_t targetTime = replayStartTime + messageTimestamp - firstTimestamp;

            while (monotonicTimeNs() < targetTime) {
                if (stopRequested.load(std::memory_order_relaxed)) {
                    replayStatus.store(ReplayStatus::Stopped,std::memory_order_release);
                    return;
                }
                _mm_pause();
            }

            if (!queue.tryPush(std::move(message))) {
                replayStatus.store(ReplayStatus::QueueOverflow, std::memory_order_release);
                return;
            }

            readStatus = reader.readNextMessage(message);
            if (readStatus == normalizer::itch::ReadStatus::EndOfFile) {
                replayStatus.store(ReplayStatus::Complete, std::memory_order_release);
                return;
            }

            if (readStatus != normalizer::itch::ReadStatus::Ok) {
                replayStatus.store(ReplayStatus::ReadFailed, std::memory_order_release);
                return;
            }
        }
    }

    bool replayFailed(ReplayStatus status) noexcept {
        switch (status) {
            case ReplayStatus::Starting:
            case ReplayStatus::Ready:
            case ReplayStatus::Running:
            case ReplayStatus::Complete:
            case ReplayStatus::Stopped:
                return false;
            default:
                return true;
        }
    }

    constexpr std::string_view hostGatewayStatusName(
        gateway::HostGatewayStatus status) noexcept {

        switch (status) {
            case gateway::HostGatewayStatus::Ok:
                return "Ok";
            case gateway::HostGatewayStatus::ItchDecodeFailed:
                return "ItchDecodeFailed";
            case gateway::HostGatewayStatus::BookUpdateFailed:
                return "BookUpdateFailed";
            case gateway::HostGatewayStatus::ProtocolGenerationFailed:
                return "ProtocolGenerationFailed";
            case gateway::HostGatewayStatus::SequenceNumberExhausted:
                return "SequenceNumberExhausted";
            case gateway::HostGatewayStatus::PendingIntentQueueFull:
                return "PendingIntentQueueFull";
            case gateway::HostGatewayStatus::DownstreamSendFailed:
                return "DownstreamSendFailed";
            case gateway::HostGatewayStatus::UpstreamReceiveFailed:
                return "UpstreamReceiveFailed";
            case gateway::HostGatewayStatus::InvalidOrderDecision:
                return "InvalidOrderDecision";
            case gateway::HostGatewayStatus::UnexpectedOrderDecision:
                return "UnexpectedOrderDecision";
        }

        return "Unknown";
    }

}


int main(int argc, char** argv) {
    if (argc != 4) {
        std::cerr << "Usage: fpga_market_gateway " << "<itch-file> <host-cpu> <replay-cpu>\n";
        return 1;
    }

    WinsockRuntime winsockRuntime;
    if (!winsockRuntime.isInitialized()) {
        std::cerr << "Unable to initialize Winsock\n";
        return 1;
    }

    unsigned hostCpu{};
    unsigned replayCpu{};

    if (!parseCpu(argv[2], hostCpu) || !parseCpu(argv[3], replayCpu) || hostCpu == replayCpu) {
        std::cerr << "Invalid CPU selection\n";
        return 1;
    }

    const std::filesystem::path filePath{argv[1]};
    std::vector<std::uint16_t> enabledSymbols;
    enabledSymbols.reserve(SymbolCapacity);

    if (!discoverSymbols(filePath, enabledSymbols)) {
        return 1;
    }

    std::cout << "Discovered " << enabledSymbols.size() << " symbols\n";

    gateway::GatewayConfig gatewayConfig{};
    gatewayConfig.enabledSymbols = std::move(enabledSymbols);
    gateway::OrderIntentPolicy orderPolicy{};
    normalizer::transport::UdpSender sender{DownstreamHostIpAddress,DownstreamFpgaIpAddress,FpgaUdpPort};
    normalizer::transport::UdpReceiver receiver{UpstreamHostIpAddress,HostUdpPort,UpstreamFpgaIpAddress,FpgaUdpPort};

    if (!sender.isOpen() || !receiver.isOpen()) {
        std::cerr << "Unable to open UDP transport\n";
        return 1;
    }

    auto queue = std::make_unique<ReplayQueue>();
    auto hostGateway = std::make_unique<gateway::HostGateway>(gatewayConfig, orderPolicy, sender, receiver, MaxTobBatchDelayNs);
    const auto startupStatus = hostGateway->sendStartupConfiguration();

    if (startupStatus != gateway::HostGatewayStatus::Ok) {
        std::cerr << "Unable to send FPGA startup configuration\n";
        return 1;
    }

    if (!pinCurrentThread(hostCpu)) {
        std::cerr << "Unable to pin host processing thread\n";
        return 1;
    }

    std::signal(SIGINT, handleInterrupt);
    std::signal(SIGTERM, handleInterrupt);

    std::atomic<bool> startReplay{false};
    std::atomic<bool> stopRequested{false};
    std::atomic<ReplayStatus> replayStatus{ReplayStatus::Starting};

    std::thread replayThread{runReplay,std::cref(filePath),replayCpu,std::ref(*queue),std::ref(startReplay),std::ref(stopRequested),std::ref(replayStatus)};

    while (replayStatus.load(std::memory_order_acquire) == ReplayStatus::Starting) {
        if (interruptRequested != 0) {
            stopRequested.store(true, std::memory_order_relaxed);
        }
        _mm_pause();
    }

    if (replayStatus.load(std::memory_order_acquire) != ReplayStatus::Ready) {
        stopRequested.store(true, std::memory_order_relaxed);
        replayThread.join();
        std::cerr << "Replay failed during setup\n";
        return 1;
    }

    startReplay.store(true, std::memory_order_release);

    normalizer::itch::RawMessage message{};
    gateway::HostGatewayStatus gatewayFailure{gateway::HostGatewayStatus::Ok};
    const char* gatewayFailureStage{"none"};
    std::uint64_t processedMessageCount{};
    std::uint64_t lastItchTimestamp{};
    char lastItchMessageType{'?'};
    bool downstreamFlushed{false};

    while (interruptRequested == 0) {
        bool didWork{false};
        const std::uint64_t nowNs = monotonicTimeNs();
        const auto serviceResult = hostGateway->service(nowNs);

        if (serviceResult.status != gateway::HostGatewayStatus::Ok) {
            gatewayFailure = serviceResult.status;
            gatewayFailureStage = "service";
            break;
        }

        didWork = serviceResult.didWork;

        if (queue->tryPop(message)) {
            didWork = true;
            lastItchMessageType = static_cast<char>(message.payload[0]);
            static_cast<void>(extractItchTimestamp(message, lastItchTimestamp));

            const auto processStatus =
                hostGateway->processRawMessage(message, nowNs);

            if (processStatus != gateway::HostGatewayStatus::Ok) {
                gatewayFailure = processStatus;
                gatewayFailureStage = "message processing";
                break;
            }

            ++processedMessageCount;
        }

        const ReplayStatus currentReplayStatus = replayStatus.load(std::memory_order_acquire);

        if (replayFailed(currentReplayStatus)) {
            break;
        }

        if (currentReplayStatus == ReplayStatus::Complete && queue->empty()) {
            if (!downstreamFlushed) {
                gatewayFailure = hostGateway->flushDownstream();
                if (gatewayFailure != gateway::HostGatewayStatus::Ok) {
                    gatewayFailureStage = "final downstream flush";
                    break;
                }
                downstreamFlushed = true;
            }

            if (hostGateway->pendingOrderIntentCount() == 0) {
                break;
            }
        }

        if (!didWork) {
            _mm_pause();
        }
    }

    stopRequested.store(true, std::memory_order_relaxed);
    replayThread.join();

    if (interruptRequested != 0) {
        std::cout << "Replay interrupted\n";
        return 130;
    }

    if (gatewayFailure != gateway::HostGatewayStatus::Ok) {
        std::cerr
            << "Host gateway processing failed:"
            << " status=" << hostGatewayStatusName(gatewayFailure)
            << " stage=" << gatewayFailureStage
            << " processed_messages=" << processedMessageCount
            << " last_itch_type=" << lastItchMessageType
            << " last_itch_timestamp_ns=" << lastItchTimestamp
            << " pending_order_intents="
            << hostGateway->pendingOrderIntentCount()
            << " sent_order_intents="
            << hostGateway->sentOrderIntentCount()
            << " received_order_decisions="
            << hostGateway->receivedOrderDecisionCount()
            << '\n';
        return 1;
    }

    const ReplayStatus finalReplayStatus = replayStatus.load(std::memory_order_acquire);

    if (replayFailed(finalReplayStatus)) {
        std::cerr << "ITCH replay failed\n";
        return 1;
    }

    std::cout << "Full-day replay completed\n";
    return 0;
}
