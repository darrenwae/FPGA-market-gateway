#pragma once
#include "normalizer/internal_protocol/types.hpp"
#include <cstdint>
#include <span>

namespace normalizer::internal_protocol {

    enum class OrderDecisionDecodeStatus : std::uint8_t {
        Ok,
        PayloadLengthMismatch,
        UnexpectedMessageType,
        ReservedFieldNonzero,
        InvalidDecision,
        InvalidRejectReason,
        DecisionRejectReasonMismatch,
    };

    [[nodiscard]] OrderDecisionDecodeStatus decodeOrderDecision(std::span<const std::uint8_t> payload, OrderDecision& output) noexcept;

} // namespace normalizer::internal_protocol