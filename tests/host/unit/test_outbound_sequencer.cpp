#include "normalizer/internal_protocol/outbound_sequencer.hpp"
#include <cstddef>
#include <cstdlib>
#include <iostream>
#include <string_view>

namespace {

    using normalizer::internal_protocol::InternalProtocolObject;
    using normalizer::internal_protocol::OutboundSequencer;
    using normalizer::internal_protocol::SequenceNumberAssignStatus;

    int failureCount = 0;

    void
    expect (bool condition, std::string_view reason) {
        if (!condition) {
            std::cerr << "FAIL: " << reason << '\n';
            ++failureCount;
        }
    }

    void
    expectOnlySequenceBytesChanged (const InternalProtocolObject& object, std::uint8_t originalValue) {
        for (std::size_t offset = 0; offset < object.size (); ++offset) {
            if (offset < 4 || offset > 7) {
                expect (object[offset] == originalValue, "sequencer changed another field");
            }
        }
    }

    void
    testFirstTwoSequenceNumbers () {
        OutboundSequencer sequencer;

        InternalProtocolObject firstObject{};
        firstObject.fill (0xA5);
        const auto firstResult = sequencer.assignSequenceNumber (firstObject);

        expect (firstResult.status == SequenceNumberAssignStatus::Ok, "first assignment failed");
        expect (firstResult.sequenceNumber == 1, "first returned sequence was not 1");
        expect (firstObject[4] == 0 && firstObject[5] == 0 && firstObject[6] == 0 && firstObject[7] == 1, "first wire sequence was not big-endian 1");
        expectOnlySequenceBytesChanged (firstObject, 0xA5);

        InternalProtocolObject secondObject{};
        secondObject.fill (0x5A);
        const auto secondResult = sequencer.assignSequenceNumber (secondObject);

        expect (secondResult.status == SequenceNumberAssignStatus::Ok, "second assignment failed");
        expect (secondResult.sequenceNumber == 2,"second returned sequence was not 2");
        expect (secondObject[4] == 0 && secondObject[5] == 0 && secondObject[6] == 0 && secondObject[7] == 2,"second wire sequence was not big-endian 2");
        expectOnlySequenceBytesChanged (secondObject, 0x5A);
    }

} // namespace

int
main () {
    testFirstTwoSequenceNumbers ();

    if (failureCount != 0) {
        std::cerr << "FAIL: " << failureCount << " outbound sequencer checks failed\n";
        return EXIT_FAILURE;
    }

    std::cout << "PASS: outbound sequencer tests\n";
    return EXIT_SUCCESS;
}
