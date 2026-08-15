#pragma once
#include <cstdint>
#include <array>
#include <cstddef>
#include "gateway/command_source.hpp"
#include "normalizer/book/OrderBook.hpp"
#include "normalizer/events/event_emitter.hpp"
#include "normalizer/internal_protocol/generator.hpp"
#include "normalizer/internal_protocol/order_decision_decoder.hpp"
#include "normalizer/internal_protocol/outbound_sequencer.hpp"
#include "normalizer/itch/decoder.hpp"
#include "normalizer/transport/udp_batcher.hpp"
#include "normalizer/transport/udp_receiver.hpp"
#include "normalizer/transport/udp_sender.hpp"



namespace gateway {

    enum class HostGatewayStatus : std::uint8_t {
        Ok,
        ItchDecodeFailed,
        BookUpdateFailed,
        ProtocolGenerationFailed,
        SequenceNumberExhausted,
        PendingIntentQueueFull,
        DownstreamSendFailed,
        UpstreamReceiveFailed,
        InvalidOrderDecision,
        UnexpectedOrderDecision,
    };

    struct HostGatewayServiceResult {
        HostGatewayStatus status{HostGatewayStatus::Ok};
        bool didWork{false};
    };

    class HostGateway {
    public:
        HostGateway(const GatewayConfig& config, const OrderIntentPolicy& orderPolicy, normalizer::transport::UdpSender& sender, normalizer::transport::UdpReceiver& receiver, std::uint64_t maxTobBatchDelayNs);

        [[nodiscard]] HostGatewayStatus sendStartupConfiguration();
        [[nodiscard]] HostGatewayStatus processRawMessage(const normalizer::itch::RawMessage& rawMessage, std::uint64_t nowNs);

        // Polls one FPGA response and expires a pending TOB batch.
        [[nodiscard]] HostGatewayServiceResult service(std::uint64_t nowNs) noexcept;

        [[nodiscard]] HostGatewayStatus flushDownstream() noexcept;
        [[nodiscard]] std::size_t pendingOrderIntentCount() const noexcept;
        [[nodiscard]] std::size_t sentOrderIntentCount() const noexcept;
        [[nodiscard]] std::size_t receivedOrderDecisionCount() const noexcept;

    private:

        struct PendingOrderIntent {
            std::uint32_t sequenceNumber{0};
            std::uint32_t intentId{0};
            std::uint16_t symbolId{0};
        };

        static constexpr std::size_t PendingIntentCapacity{1024};
        static constexpr std::size_t PendingIntentMask{PendingIntentCapacity - 1};

        normalizer::book::OrderBook orderBook_;
        CommandSource commandSource_;

        normalizer::events::TopOfBookEmitter topOfBookEmitter_;
        normalizer::events::SessionStatusEmitter sessionStatusEmitter_;
        normalizer::events::SymbolStatusEmitter symbolStatusEmitter_;

        normalizer::internal_protocol::Generator generator_;
        normalizer::internal_protocol::OutboundSequencer sequencer_;

        normalizer::transport::UdpBatcher<normalizer::transport::UdpSender> batcher_;
        normalizer::transport::UdpReceiver& receiver_;

        normalizer::itch::DecodedMessage decodedMessage_{};
        std::array<std::uint8_t,normalizer::internal_protocol::ObjectSize> receiveBuffer_{};

        std::array<PendingOrderIntent,PendingIntentCapacity> pendingOrderIntents_{};

        std::size_t pendingReadIndex_{0};
        std::size_t pendingWriteIndex_{0};

        [[nodiscard]] HostGatewayStatus processDecodedMessage(std::uint64_t nowNs);
        [[nodiscard]] HostGatewayStatus processBookUpdate(std::uint64_t sourceTimestamp, const normalizer::book::BookUpdateResult& update, std::uint64_t nowNs);
        [[nodiscard]] HostGatewayStatus sendGeneratedMessage(normalizer::internal_protocol::GenerateResult result, std::uint64_t nowNs);
        [[nodiscard]] HostGatewayStatus sendOrderIntent(const commands::OrderIntent& orderIntent, std::uint64_t nowNs);
        [[nodiscard]] HostGatewayStatus processOrderDecision(std::size_t payloadLength) noexcept;
    };

}