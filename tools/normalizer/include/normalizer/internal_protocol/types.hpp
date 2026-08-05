#pragma once
#include <array>
#include <cstddef>
#include <cstdint>

namespace normalizer::internal_protocol {

    inline constexpr std::size_t ObjectSize = 32;
    using InternalProtocolObject = std::array<std::uint8_t, ObjectSize>;
    inline constexpr std::size_t MessageTypeOffset = 0;
    inline constexpr std::size_t FlagsOffset = 1;

    inline constexpr std::size_t ReservedOffset = 2;
    inline constexpr std::size_t ReservedSize = 2;

    inline constexpr std::size_t SequenceNumberOffset = 4;
    inline constexpr std::size_t SequenceNumberSize = 4;

    inline constexpr std::size_t SymbolIdOffset = 8;
    inline constexpr std::size_t SymbolIdSize = 2;

    inline constexpr std::size_t TimestampOffset = 10;
    inline constexpr std::size_t TimestampSize = 6;

    inline constexpr std::size_t Payload0Offset = 16;
    inline constexpr std::size_t Payload1Offset = 20;
    inline constexpr std::size_t Payload2Offset = 24;
    inline constexpr std::size_t Payload3Offset = 28;
    inline constexpr std::size_t PayloadWordSize = 4;

    enum class MessageType : std::uint8_t {
        SessionStatus = 1,
        TopOfBookUpdate = 2,
        SymbolStatus = 3,
        OrderIntent = 4,
        ConfigControl = 5,
        OrderDecision = 0x81
    };

    enum class SessionState : std::uint32_t {
        Invalid = 0,
        StartOfMessages = 1,
        StartOfSystemHours = 2,
        StartOfMarketHours = 3,
        EndOfMarketHours = 4,
        EndOfSystemHours = 5,
        EndOfMessages = 6,
    };

    enum class SymbolStatus : std::uint32_t {
        Invalid = 0,
        Halted = 1,
        Paused = 2,
        QuotationOnly = 3,
        Trading = 4,
    };

    enum class Decision : std::uint32_t {
        UnknownInvalid = 0,
        Accept = 1,
        Reject = 2,
    };

    enum class RejectReason : std::uint32_t {
        None = 0,
        StreamFault = 1,
        OrderIntentProtocolViolation = 2,
        UnknownSymbol = 3,
        SymbolDisabled = 4,
        SymbolNotTrading = 5,
        RequiredTobSideInvalid = 6,
        InvalidOrderSide = 7,
        ZeroOrderQuantity = 8,
        MaxOrderQuantityExceeded = 9,
        ZeroOrderPrice = 10,
        PriceBandViolation = 11,
        MaxNotionalExceeded = 12,
        SessionNotTrading = 13,
    };

    struct OrderDecision {
        std::uint32_t sequenceNumber{0};
        Decision decision{Decision::UnknownInvalid};
        RejectReason rejectReason{RejectReason::None};
        std::uint32_t intentId{0};
        std::uint16_t symbolId{0};
    };

} // namespace normalizer::internal_protocol