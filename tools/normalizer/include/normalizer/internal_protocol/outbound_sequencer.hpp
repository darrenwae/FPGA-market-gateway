#pragma once
#include <cstdint>
#include "normalizer/internal_protocol/types.hpp"


namespace normalizer::internal_protocol {
    enum class SequenceNumberAssignStatus : std::uint8_t {
       Ok,
       SequenceNumberExhausted
    };

    struct SequencedObject {
        InternalProtocolObject object{};
        SequenceNumberAssignStatus status;
    };

    class OutboundSequencer {
        public:
        [[nodiscard]] SequencedObject assignSequenceNumber(InternalProtocolObject& object) noexcept;

        private:
        std::uint32_t nextSequenceNumber_ {1};
    };
}