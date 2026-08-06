#pragma once
#include <cstdint>
#include "normalizer/internal_protocol/types.hpp"

namespace normalizer::internal_protocol {
    enum class SequenceNumberAssignStatus : std::uint8_t { 
        Ok, 
        SequenceNumberExhausted 
    };

    struct SequenceNumberAssignResult {
        std::uint32_t sequenceNumber{};
        SequenceNumberAssignStatus status{SequenceNumberAssignStatus::Ok};
    };

    class OutboundSequencer {
      public:
        [[nodiscard]] SequenceNumberAssignResult assignSequenceNumber(InternalProtocolObject& object) noexcept;

      private:
        std::uint32_t nextSequenceNumber_{1};
    };
}