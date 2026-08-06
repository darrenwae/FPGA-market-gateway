#include "normalizer/internal_protocol/order_decision_decoder.hpp"
#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <span>
#include <string_view>

namespace {

    using normalizer::internal_protocol::Decision;
    using normalizer::internal_protocol::decodeOrderDecision;
    using normalizer::internal_protocol::OrderDecision;
    using normalizer::internal_protocol::OrderDecisionDecodeStatus;
    using normalizer::internal_protocol::RejectReason;

    using WireMessage = std::array<std::uint8_t, 32>;

    constexpr std::uint32_t ExpectedSequenceNumber = 0x0102'0304;
    constexpr std::uint16_t ExpectedSymbolId = 0x1122;
    constexpr std::uint32_t ExpectedIntentId = 0xA1A2'A3A4;

    int failureCount = 0;

    void expect(bool condition, std::string_view test, std::string_view reason) {
        if (!condition) {
            std::cerr << "FAIL: " << test << ": " << reason << '\n';
            ++failureCount;
        }
    }

    WireMessage makeAcceptMessage() {
        return {
            0x81, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x11, 0x22, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA1, 0xA2, 0xA3, 0xA4,
        };
    }

    void expectStatus(std::span<const std::uint8_t> payload, OrderDecisionDecodeStatus expectedStatus, std::string_view test) {
        OrderDecision output{};
        expect(decodeOrderDecision(payload, output) == expectedStatus, test, "unexpected decoder status");
    }

    void testValidAccept() {
        constexpr std::string_view Test = "valid ACCEPT";
        const WireMessage message = makeAcceptMessage();
        OrderDecision output{};

        expect(decodeOrderDecision(message, output) == OrderDecisionDecodeStatus::Ok, Test, "decode failed");
        expect(output.sequenceNumber == ExpectedSequenceNumber, Test, "wrong sequence number");
        expect(output.symbolId == ExpectedSymbolId, Test, "wrong symbol ID");
        expect(output.decision == Decision::Accept, Test, "wrong decision");
        expect(output.rejectReason == RejectReason::None, Test, "wrong reject reason");
        expect(output.intentId == ExpectedIntentId, Test, "wrong intent ID");
    }

    void testValidReject() {
        constexpr std::string_view Test = "valid REJECT";
        WireMessage message = makeAcceptMessage();
        message[19] = 2;
        message[23] = 11;
        OrderDecision output{};

        expect(decodeOrderDecision(message, output) == OrderDecisionDecodeStatus::Ok, Test, "decode failed");
        expect(output.decision == Decision::Reject, Test, "wrong decision");
        expect(output.rejectReason == RejectReason::PriceBandViolation, Test, "wrong reject reason");
    }

    void testPayloadLengthMismatch() {
        constexpr std::string_view Test = "payload length mismatch";
        const WireMessage message = makeAcceptMessage();
        std::array<std::uint8_t, 33> tooLong{};
        std::copy(message.begin(), message.end(), tooLong.begin());

        expectStatus(std::span<const std::uint8_t>{message.data(), 31}, OrderDecisionDecodeStatus::PayloadLengthMismatch, Test);
        expectStatus(tooLong, OrderDecisionDecodeStatus::PayloadLengthMismatch, Test);
    }

    void testUnexpectedMessageType() {
        WireMessage message = makeAcceptMessage();
        message[0] = 0x04;

        expectStatus(message, OrderDecisionDecodeStatus::UnexpectedMessageType, "unexpected message type");
    }

    void testReservedFields() {
        constexpr std::array<std::size_t, 13> ReservedByteOffsets{1, 2, 3, 10, 11, 12, 13, 14, 15, 24, 25, 26, 27};

        for (const std::size_t offset : ReservedByteOffsets) {
            WireMessage message = makeAcceptMessage();
            message[offset] = 1;
            expectStatus(message, OrderDecisionDecodeStatus::ReservedFieldNonzero, "nonzero reserved byte");
        }
    }

    void testInvalidDecision() {
        WireMessage unknown = makeAcceptMessage();
        unknown[19] = 0;
        expectStatus(unknown, OrderDecisionDecodeStatus::InvalidDecision, "UNKNOWN_INVALID decision");

        WireMessage reserved = makeAcceptMessage();
        reserved[19] = 3;
        expectStatus(reserved, OrderDecisionDecodeStatus::InvalidDecision, "reserved decision");
    }

    void testInvalidRejectReason() {
        WireMessage message = makeAcceptMessage();
        message[19] = 2;
        message[23] = 14;

        expectStatus(message, OrderDecisionDecodeStatus::InvalidRejectReason, "reserved reject reason");
    }

    void testDecisionRejectReasonMismatch() {
        WireMessage acceptedWithReason = makeAcceptMessage();
        acceptedWithReason[23] = 1;
        expectStatus(acceptedWithReason, OrderDecisionDecodeStatus::DecisionRejectReasonMismatch, "ACCEPT with reject reason");

        WireMessage rejectedWithoutReason = makeAcceptMessage();
        rejectedWithoutReason[19] = 2;
        expectStatus(rejectedWithoutReason, OrderDecisionDecodeStatus::DecisionRejectReasonMismatch, "REJECT without reject reason");
    }

} // namespace

int main() {

    testValidAccept();
    testValidReject();
    testPayloadLengthMismatch();
    testUnexpectedMessageType();
    testReservedFields();
    testInvalidDecision();
    testInvalidRejectReason();
    testDecisionRejectReasonMismatch();

    if (failureCount != 0) {
        std::cerr << "FAIL: " << failureCount << " ORDER_DECISION decoder checks failed\n";
        return EXIT_FAILURE;
    }

    std::cout << "PASS: ORDER_DECISION decoder tests\n";
    return EXIT_SUCCESS;
}
