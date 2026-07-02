#pragma once
#include <cstdint>
#include <cstddef>
#include <array>
#include <cstring>
#include "normalizer/internal_protocol/types.hpp"


namespace normalizer::transport {
    enum class BatchStatus : std::uint8_t {
        Ok,
        Flushed,
        SendFailed
    };

    template <typename Sink>
    class UdpBatcher {
        public:
        explicit UdpBatcher(Sink& sink, std::uint64_t maxTobBatchDelayNs) noexcept : sink_ {sink}, maxTobBatchDelayNs_ {maxTobBatchDelayNs} {}

        BatchStatus append(const internal_protocol::InternalProtocolObject& object, std::uint64_t nowNs) noexcept {
            BatchStatus expiryFlushStatus = flushExpired(nowNs); //flush if TOB update  in buffer has expired
            if (expiryFlushStatus == BatchStatus::SendFailed) {
                return expiryFlushStatus;
            }

            if (messageCount_ == MaxMessageCount) {
                const BatchStatus fullFlushStatus = flush(); //ensure full buffer is emptied successfully before any append
                if (fullFlushStatus == BatchStatus::SendFailed) {
                    return fullFlushStatus;
                }
            }

            const std::size_t offset = messageCount_ * internal_protocol::ObjectSize;
            std::memcpy(buffer_.data() + offset, object.data(), internal_protocol::ObjectSize);
            if (messageCount_ == 0) {
                oldestMessageTimeNs_ = nowNs;
            }
            ++messageCount_;

            //flush buffer if needed
            if (messageCount_ == MaxMessageCount || flushImmediately(object)) {
                return flush();
            }
            return BatchStatus::Ok;
        }

        BatchStatus flush() noexcept {
            if (messageCount_ == 0) {
                return BatchStatus::Ok;
            }

            const std::size_t length = messageCount_ * internal_protocol::ObjectSize;
            const bool sent = sink_.send(buffer_.data(), length);
            if (!sent) {
                return BatchStatus::SendFailed;
            }
            messageCount_ = 0;
            oldestMessageTimeNs_ = 0;
            return BatchStatus::Flushed;
        }

        BatchStatus flushExpired(std::uint64_t nowNs) noexcept {
            if (!expired(nowNs)) {
                return BatchStatus::Ok;
            }
            return flush();
        }

        [[nodiscard]] bool empty() const noexcept {
            return messageCount_ == 0;
        }

        [[nodiscard]] std::uint16_t size() const noexcept {
            return messageCount_;
        }

        private:
        static constexpr std::size_t MaxPayloadBytes {1472};
        static constexpr std::uint16_t MaxMessageCount {46};
        static_assert (MaxPayloadBytes == MaxMessageCount * internal_protocol::ObjectSize);

        Sink& sink_;
        std::array<std::uint8_t, MaxPayloadBytes> buffer_ {};
        std::uint16_t messageCount_ {0};

        std::uint64_t oldestMessageTimeNs_ {0};
        const std::uint64_t maxTobBatchDelayNs_;

        [[nodiscard]] static bool flushImmediately(const internal_protocol::InternalProtocolObject& object) noexcept {
            const auto messageType = static_cast<internal_protocol::MessageType>(object[internal_protocol::MessageTypeOffset]);
            switch(messageType) {
                case internal_protocol::MessageType::SessionStatus:
                case internal_protocol::MessageType::SymbolStatus:
                case internal_protocol::MessageType::OrderIntent:
                case internal_protocol::MessageType::ConfigControl:
                    return true;
                default:
                    return false;
            }
        }

        [[nodiscard]] bool expired(std::uint64_t nowNs) const noexcept {
            return messageCount_ != 0 && maxTobBatchDelayNs_ != 0 && (nowNs - oldestMessageTimeNs_) >= maxTobBatchDelayNs_;
        }
        
    };
}