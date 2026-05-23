#pragma once
#include <variant>
#include <cstdint>
#include <array>
#include "normalizer/itch/raw_message.hpp"


namespace normalizer::itch {
    enum class DecodeStatus {
        Ok,
        EmptyMessage,
        LengthMismatch,
        UnsupportedMessageType,
        InvalidFieldValue
    };

    enum class MessageType: char {
        SystemEvent = 'S',
        StockDirectory = 'R',
        StockTradingAction = 'H',
        AddOrder = 'A',
        AddOrderWithMPID = 'F',
        OrderExecuted = 'E',
        OrderExecutedWithPrice = 'C',
        OrderCancel = 'X',
        OrderDelete = 'D',
        OrderReplace = 'U',
    };

    enum class EventCode: char {
        StartOfMessages = 'O',
        StartOfSystemHours = 'S',
        StartOfMarketHours = 'Q',
        EndOfMarketHours = 'M',
        EndOfSystemHours = 'E',
        EndOfMessages = 'C',
    };

    enum class TradingState: char {
        Halted = 'H',
        Paused = 'P',
        QuotationOnly = 'Q',
        Trading = 'T',
    };

    enum class BuySellIndicator: char {
        Buy = 'B',
        Sell = 'S',
    };


    struct SystemEvent {
        MessageType messageType{MessageType::SystemEvent};
        std::uint16_t stockLocate{0};
        std::uint16_t trackingNumber{0};
        std::uint64_t timestamp{0};
        EventCode eventCode{};
    };

    struct StockDirectory {
        MessageType messageType{MessageType::StockDirectory};
        std::uint16_t stockLocate{0};
        std::uint16_t trackingNumber{0};
        std::uint64_t timestamp{0};
        std::array<char,8> stock{};
        char marketCategory{' '};
        char financialStatusIndicator{' '};
        std::uint32_t roundLotSize{0};
        char roundLotsOnly{' '};
        char issueClassification{' '};
        std::array<char, 2> issueSubType{};
        char authenticity{' '};
        char shortSaleThresholdIndicator{' '};
        char ipoFlag{' '};
        char luldReferencePriceTier{' '};
        char etpFlag{' '};
        std::uint32_t etpLeverageFactor{0};
        char inverseIndicator{' '};
    };

    struct StockTradingAction {
        MessageType messageType{MessageType::StockTradingAction};
        std::uint16_t stockLocate{0};
        std::uint16_t trackingNumber{0};
        std::uint64_t timestamp{0};
        std::array<char,8> stock{};
        TradingState tradingState{};
        char reserved{' '};
        std::array<char, 4> reason{};
    };

    struct AddOrder {
        MessageType messageType{MessageType::AddOrder};
        std::uint16_t stockLocate{0};
        std::uint16_t trackingNumber{0};
        std::uint64_t timestamp{0};
        std::uint64_t orderReferenceNumber{0};
        BuySellIndicator buySell{};
        std::uint32_t shares{0};
        std::array<char,8> stock{};
        std::uint32_t price{0};
    };

    struct AddOrderWithMPID {
        MessageType messageType{MessageType::AddOrderWithMPID};
        std::uint16_t stockLocate{0};
        std::uint16_t trackingNumber{0};
        std::uint64_t timestamp{0};
        std::uint64_t orderReferenceNumber{0};
        BuySellIndicator buySell{};
        std::uint32_t shares{0};
        std::array<char,8> stock{};
        std::uint32_t price{0};
        std::array<char, 4> attribution{};
    };

    struct OrderExecuted {
        MessageType messageType{MessageType::OrderExecuted};
        std::uint16_t stockLocate{0};
        std::uint16_t trackingNumber{0};
        std::uint64_t timestamp{0};
        std::uint64_t orderReferenceNumber{0};
        std::uint32_t executedShares{0};
        std::uint64_t matchNumber{0};
    };

    struct OrderExecutedWithPrice {
        MessageType messageType{MessageType::OrderExecutedWithPrice};
        std::uint16_t stockLocate{0};
        std::uint16_t trackingNumber{0};
        std::uint64_t timestamp{0};
        std::uint64_t orderReferenceNumber{0};
        std::uint32_t executedShares{0};
        std::uint64_t matchNumber{0};
        char printable{' '};
        std::uint32_t executionPrice{0};
    };

    struct OrderCancel {
        MessageType messageType{MessageType::OrderCancel};
        std::uint16_t stockLocate{0};
        std::uint16_t trackingNumber{0};
        std::uint64_t timestamp{0};
        std::uint64_t orderReferenceNumber{0};
        std::uint32_t cancelledShares{0};
    };

    struct OrderDelete {
        MessageType messageType{MessageType::OrderDelete};
        std::uint16_t stockLocate{0};
        std::uint16_t trackingNumber{0};
        std::uint64_t timestamp{0};
        std::uint64_t orderReferenceNumber{0};
    };

    struct OrderReplace {
        MessageType messageType{MessageType::OrderReplace};
        std::uint16_t stockLocate{0};
        std::uint16_t trackingNumber{0};
        std::uint64_t timestamp{0};
        std::uint64_t originalOrderReferenceNumber{0};
        std::uint64_t newOrderReferenceNumber{0};
        std::uint32_t shares{0};
        std::uint32_t price{0};
    };


    using DecodedMessage = std::variant<
        std::monostate,
        SystemEvent,
        StockDirectory,
        StockTradingAction,
        AddOrder,
        AddOrderWithMPID,
        OrderExecuted,
        OrderExecutedWithPrice,
        OrderCancel,
        OrderDelete,
        OrderReplace
    >;


    [[nodiscard]] DecodeStatus decodeMessage(const RawMessage& message, DecodedMessage& output);

}