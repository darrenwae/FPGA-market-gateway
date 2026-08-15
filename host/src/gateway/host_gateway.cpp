#include "gateway/host_gateway.hpp"
#include <span>
#include <type_traits>
#include <variant>
#include <chrono>
#include <thread>

namespace gateway {

    HostGateway::HostGateway(const GatewayConfig& config,const OrderIntentPolicy& orderPolicy,normalizer::transport::UdpSender& sender,normalizer::transport::UdpReceiver& receiver,std::uint64_t maxTobBatchDelayNs): 
    orderBook_(std::span<const std::uint16_t>{config.enabledSymbols.data(),config.enabledSymbols.size()}),
    commandSource_(config, orderPolicy),
    batcher_(sender, maxTobBatchDelayNs),
    receiver_(receiver) {}

    HostGatewayStatus HostGateway::sendStartupConfiguration() {
        const auto commands = commandSource_.startupConfig(0);
        // Supports both a fresh FPGA and recovery after a host-only restart.
        for (unsigned resetIndex = 0; resetIndex < 2; ++resetIndex) {
            const auto status = sendGeneratedMessage(generator_.generateConfigCommand(commands.front()), 0);
            if (status != HostGatewayStatus::Ok) {
                return status;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds{1});
        }
    
        for (std::size_t index = 1; index < commands.size(); ++index) {
            const auto status = sendGeneratedMessage(generator_.generateConfigCommand(commands[index]), 0);
            if (status != HostGatewayStatus::Ok) {
                return status;
            }
        }
    
        return HostGatewayStatus::Ok;
    }


    HostGatewayStatus HostGateway::processRawMessage(const normalizer::itch::RawMessage& rawMessage, std::uint64_t nowNs) {

        const auto decodeStatus = normalizer::itch::decodeMessage(rawMessage, decodedMessage_);
        if (decodeStatus == normalizer::itch::DecodeStatus::UnsupportedMessageType) {
            return HostGatewayStatus::Ok;
        }
        if (decodeStatus != normalizer::itch::DecodeStatus::Ok) {
            return HostGatewayStatus::ItchDecodeFailed;
        }
        return processDecodedMessage(nowNs);
    }


    HostGatewayStatus HostGateway::processDecodedMessage(std::uint64_t nowNs) {

        return std::visit([this, nowNs](const auto& message) -> HostGatewayStatus {
                using Message = std::decay_t<decltype(message)>;
                if constexpr (std::is_same_v<Message, std::monostate>) {
                    return HostGatewayStatus::ItchDecodeFailed;
                }
                else if constexpr (std::is_same_v<Message,normalizer::itch::SystemEvent>) {
                    const auto event =sessionStatusEmitter_.onSystemEvent(message);
                    commandSource_.observeSessionStatus(event);

                    return sendGeneratedMessage(generator_.generateSessionStatus(event), nowNs);
                }
                else if constexpr (std::is_same_v<Message,normalizer::itch::StockDirectory>) {
                    // Symbols were selected during the setup pre-scan.
                    return HostGatewayStatus::Ok;
                }
                else if constexpr (std::is_same_v<Message,normalizer::itch::StockTradingAction>) {
                    const auto event =symbolStatusEmitter_.onStockTradingAction(message);
                    commandSource_.observeSymbolStatus(event);

                    return sendGeneratedMessage(generator_.generateSymbolStatus(event), nowNs);
                }
                else if constexpr (std::is_same_v<Message,normalizer::itch::AddOrder>) {
                    return processBookUpdate(message.timestamp, orderBook_.onAddOrder(message), nowNs);
                }
                else if constexpr (std::is_same_v<Message,normalizer::itch::AddOrderWithMPID>) {
                    return processBookUpdate(message.timestamp, orderBook_.onAddOrderWithMPID(message), nowNs);
                }
                else if constexpr (std::is_same_v<Message,normalizer::itch::OrderExecuted>) {
                    return processBookUpdate(message.timestamp,orderBook_.onOrderExecuted(message), nowNs);
                }
                else if constexpr (std::is_same_v<Message,normalizer::itch::OrderExecutedWithPrice>) {
                    return processBookUpdate( message.timestamp, orderBook_.onOrderExecutedWithPrice(message), nowNs);
                }
                else if constexpr (std::is_same_v<Message,normalizer::itch::OrderCancel>) {
                    return processBookUpdate(message.timestamp,orderBook_.onOrderCancel(message), nowNs);
                }
                else if constexpr (std::is_same_v<Message,normalizer::itch::OrderDelete>) {
                    return processBookUpdate(message.timestamp,orderBook_.onOrderDelete(message), nowNs);
                }
                else if constexpr (std::is_same_v<Message, normalizer::itch::OrderReplace>) {
                    return processBookUpdate(message.timestamp, orderBook_.onOrderReplace(message), nowNs);
                }
                else {
                    return HostGatewayStatus::ItchDecodeFailed;
                }
            },

            decodedMessage_
        );
    }


    HostGatewayStatus HostGateway::processBookUpdate(std::uint64_t sourceTimestamp, const normalizer::book::BookUpdateResult& update, std::uint64_t nowNs) {
        
        if (update.status != normalizer::book::BookUpdateStatus::Ok) {
            return HostGatewayStatus::BookUpdateFailed;
        }

        const auto topOfBookEvent = topOfBookEmitter_.onBookUpdate(sourceTimestamp, update);
        if (!topOfBookEvent.has_value()) {
            return HostGatewayStatus::Ok;
        }

        const auto topOfBookStatus = sendGeneratedMessage(generator_.generateTopOfBookUpdate(*topOfBookEvent), nowNs);

        if (topOfBookStatus != HostGatewayStatus::Ok) {
            return topOfBookStatus;
        }

        const auto orderIntent =commandSource_.maybeCreateOrderIntent(*topOfBookEvent);
        if (!orderIntent.has_value()) {
            return HostGatewayStatus::Ok;
        }

        return sendOrderIntent(*orderIntent, nowNs);
    }


    HostGatewayStatus HostGateway::sendGeneratedMessage(normalizer::internal_protocol::GenerateResult result, std::uint64_t nowNs) {

        if (result.status != normalizer::internal_protocol::GenerateStatus::Ok) {
            return HostGatewayStatus::ProtocolGenerationFailed;
        }

        const auto sequenceResult =sequencer_.assignSequenceNumber(result.object);
        if (sequenceResult.status != normalizer::internal_protocol::SequenceNumberAssignStatus::Ok) {
            return HostGatewayStatus::SequenceNumberExhausted;
        }

        const auto batchStatus = batcher_.append(result.object, nowNs);

        if (batchStatus ==normalizer::transport::BatchStatus::SendFailed) {
            return HostGatewayStatus::DownstreamSendFailed;
        }

        return HostGatewayStatus::Ok;
    }


    HostGatewayStatus HostGateway::sendOrderIntent(const commands::OrderIntent& orderIntent, std::uint64_t nowNs) {

        if (pendingOrderIntentCount() == PendingIntentCapacity) {
            return HostGatewayStatus::PendingIntentQueueFull;
        }

        auto result = generator_.generateOrderIntent(orderIntent);
        if (result.status != normalizer::internal_protocol::GenerateStatus::Ok) {
            return HostGatewayStatus::ProtocolGenerationFailed;
        }

        const auto sequenceResult = sequencer_.assignSequenceNumber(result.object);
        if (sequenceResult.status != normalizer::internal_protocol::SequenceNumberAssignStatus::Ok) {
            return HostGatewayStatus::SequenceNumberExhausted;
        }

        const auto batchStatus = batcher_.append(result.object, nowNs);
        if (batchStatus == normalizer::transport::BatchStatus::SendFailed) {
            return HostGatewayStatus::DownstreamSendFailed;
        }

        pendingOrderIntents_[pendingWriteIndex_ & PendingIntentMask] = {sequenceResult.sequenceNumber,orderIntent.intentId,orderIntent.symbolId};
        ++pendingWriteIndex_;
        return HostGatewayStatus::Ok;
    }


    HostGatewayServiceResult HostGateway::service(std::uint64_t nowNs) noexcept {
        HostGatewayServiceResult result{};
        const auto receiveResult = receiver_.receive(receiveBuffer_.data(), receiveBuffer_.size());

        switch (receiveResult.status) {
            case normalizer::transport::UdpReceiveStatus::PacketReceived:
                result.didWork = true;
                result.status = processOrderDecision(receiveResult.payloadLength);
                if (result.status != HostGatewayStatus::Ok) {
                    return result;
                }
                break;

            case normalizer::transport::UdpReceiveStatus::NoPacketAvailable:
                break;

            case normalizer::transport::UdpReceiveStatus::PacketTooLarge:
                return {HostGatewayStatus::InvalidOrderDecision, true};

            case normalizer::transport::UdpReceiveStatus::SocketError:
                return {HostGatewayStatus::UpstreamReceiveFailed, false};
        }

        const auto batchStatus = batcher_.flushExpired(nowNs);
        if (batchStatus == normalizer::transport::BatchStatus::SendFailed) {
            return {HostGatewayStatus::DownstreamSendFailed,result.didWork};
        }

        if (batchStatus == normalizer::transport::BatchStatus::Flushed) {
            result.didWork = true;
        }

        return result;
    }


    HostGatewayStatus HostGateway::processOrderDecision(std::size_t payloadLength) noexcept {
        normalizer::internal_protocol::OrderDecision decision{};

        const auto decodeStatus = normalizer::internal_protocol::decodeOrderDecision({receiveBuffer_.data(),payloadLength}, decision);
        if (decodeStatus != normalizer::internal_protocol::OrderDecisionDecodeStatus::Ok) {
            return HostGatewayStatus::InvalidOrderDecision;
        }

        if (pendingOrderIntentCount() == 0) {
            return HostGatewayStatus::UnexpectedOrderDecision;
        }

        const auto& expected = pendingOrderIntents_[pendingReadIndex_ & PendingIntentMask];
        if (decision.sequenceNumber != expected.sequenceNumber || decision.intentId != expected.intentId || decision.symbolId != expected.symbolId) {
            return HostGatewayStatus::UnexpectedOrderDecision;
        }

        ++pendingReadIndex_;
        return HostGatewayStatus::Ok;
    }


    HostGatewayStatus HostGateway::flushDownstream() noexcept {
        if (batcher_.flush() == normalizer::transport::BatchStatus::SendFailed) {
            return HostGatewayStatus::DownstreamSendFailed;
        }
        return HostGatewayStatus::Ok;
    }


    std::size_t HostGateway::pendingOrderIntentCount() const noexcept {
        return pendingWriteIndex_ - pendingReadIndex_;
    }

    std::size_t HostGateway::sentOrderIntentCount() const noexcept {
        return pendingWriteIndex_;
    }
    
    std::size_t HostGateway::receivedOrderDecisionCount() const noexcept {
        return pendingReadIndex_;
    }

}