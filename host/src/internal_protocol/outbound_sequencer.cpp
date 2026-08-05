#include "normalizer/internal_protocol/outbound_sequencer.hpp"
#include "normalizer/util/endian.hpp"


namespace normalizer::internal_protocol {
    SequencedObject OutboundSequencer::assignSequenceNumber(InternalProtocolObject& object) noexcept {
        SequencedObject result{};
        if (nextSequenceNumber_ == 0) {
            result.status = SequenceNumberAssignStatus::SequenceNumberExhausted;
            return result;
        }
        util::writeBE32(object.data() + SequenceNumberOffset, nextSequenceNumber_++);
        result.object = object;
        result.status = SequenceNumberAssignStatus::Ok;
        return result;
    }
}