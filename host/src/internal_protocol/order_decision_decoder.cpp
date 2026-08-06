#include "normalizer/internal_protocol/order_decision_decoder.hpp"
#include "normalizer/util/endian.hpp"
#include <cstdint>

namespace normalizer::internal_protocol {

    OrderDecisionDecodeStatus decodeOrderDecision(std::span<const std::uint8_t> payload, OrderDecision& output) noexcept {
        output = {};
        if (payload.size() != ObjectSize) {
            return OrderDecisionDecodeStatus::PayloadLengthMismatch;
        }

        const std::uint8_t* data = payload.data();

        if (data[MessageTypeOffset] != static_cast<std::uint8_t>(MessageType::OrderDecision)) {
            return OrderDecisionDecodeStatus::UnexpectedMessageType;
        }
        if (data[FlagsOffset] != 0 || util::readBE16(data + ReservedOffset) != 0 || util::readBE48(data + TimestampOffset) != 0 || util::readBE32(data + Payload2Offset) != 0) {
            return OrderDecisionDecodeStatus::ReservedFieldNonzero;
        }

        const std::uint32_t decisionValue = util::readBE32(data + Payload0Offset);
        const std::uint32_t rejectReasonValue = util::readBE32(data + Payload1Offset);

        if (decisionValue != static_cast<std::uint32_t>(Decision::Accept) && decisionValue != static_cast<std::uint32_t>(Decision::Reject)) {
            return OrderDecisionDecodeStatus::InvalidDecision;
        }

        if (rejectReasonValue > static_cast<std::uint32_t>(RejectReason::SessionNotTrading)) {
            return OrderDecisionDecodeStatus::InvalidRejectReason;
        }

        const auto decision = static_cast<Decision>(decisionValue);
        const auto rejectReason = static_cast<RejectReason>(rejectReasonValue);

        if ((decision == Decision::Accept && rejectReason != RejectReason::None) || (decision == Decision::Reject && rejectReason == RejectReason::None)) {
            return OrderDecisionDecodeStatus::DecisionRejectReasonMismatch;
        }

        output.sequenceNumber = util::readBE32(data + SequenceNumberOffset);
        output.symbolId = util::readBE16(data + SymbolIdOffset);
        output.decision = decision;
        output.rejectReason = rejectReason;
        output.intentId = util::readBE32(data + Payload3Offset);
        return OrderDecisionDecodeStatus::Ok;
    }

} // namespace normalizer::internal_protocol