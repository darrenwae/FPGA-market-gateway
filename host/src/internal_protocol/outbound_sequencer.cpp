#include "normalizer/internal_protocol/outbound_sequencer.hpp"
#include "normalizer/util/endian.hpp"

namespace normalizer::internal_protocol{
    SequenceNumberAssignResult OutboundSequencer::assignSequenceNumber (InternalProtocolObject& object) noexcept {
        if (nextSequenceNumber_ == 0) {
            return { 0, SequenceNumberAssignStatus::SequenceNumberExhausted };
        }

        const std::uint32_t assignedSequenceNumber = nextSequenceNumber_++;
        util::writeBE32 (object.data () + SequenceNumberOffset, assignedSequenceNumber);

        return {assignedSequenceNumber, SequenceNumberAssignStatus::Ok };
    }
}