#include <cstdint>
#include <limits>
#include "normalizer/internal_protocol/generator.hpp"
#include "normalizer/util/endian.hpp"


namespace normalizer::internal_protocol {
namespace {
    constexpr std::uint64_t MaxTimeStamp48Bit = 0xFFFFFFFFFFFFULL;
    bool validTimestamp (std::uint64_t timestamp) {
        return timestamp <= MaxTimeStamp48Bit;
    }
}

    using OrderSide = gateway::commands::OrderSide;
    using ConfigOpcode = gateway::commands::ConfigOpcode;
    using ConfigCommand = gateway::commands::ConfigCommand;
    using OrderIntent = gateway::commands::OrderIntent;



    GenerateResult Generator::generateSessionStatus(const events::SessionStatusEvent& event) const {
        GenerateResult result{};
        if (!validTimestamp(event.sourceTimestamp)) {
            result.status = GenerateStatus::TimestampOutOfRange;
            return result;
        }

        SessionState state;
        switch (event.eventCode) {
            case itch::EventCode::StartOfMessages:
                state = SessionState::StartOfMessages;
                break;
            case itch::EventCode::StartOfSystemHours:
                state = SessionState::StartOfSystemHours;
                break;
            case itch::EventCode::StartOfMarketHours:
                state = SessionState::StartOfMarketHours;
                break;
            case itch::EventCode::EndOfMarketHours:
                state = SessionState::EndOfMarketHours;
                break;
            case itch::EventCode::EndOfSystemHours:
                state = SessionState::EndOfSystemHours;
                break;
            case itch::EventCode::EndOfMessages:
                state = SessionState::EndOfMessages;
                break;
            default:
                result.status = GenerateStatus::InvalidSessionState;
                return result;
        }

        InternalProtocolObject object{};
        object[MessageTypeOffset] = static_cast<std::uint8_t>(MessageType::SessionStatus);
        object[FlagsOffset] = 0;
        util::writeBE48(object.data() + TimestampOffset, event.sourceTimestamp);
        util::writeBE32(object.data() + Payload0Offset, static_cast<std::uint32_t>(state));
        
        result.object = object;
        result.status = GenerateStatus::Ok;
        return result;
    }

    GenerateResult Generator::generateTopOfBookUpdate(const events::TopOfBookEvent& event) const {
        GenerateResult result{};
        if (!validTimestamp(event.sourceTimestamp)) {
            result.status = GenerateStatus::TimestampOutOfRange;
            return result;
        }
        

        InternalProtocolObject object{};
        object[MessageTypeOffset] = static_cast<std::uint8_t>(MessageType::TopOfBookUpdate);
        object[FlagsOffset] = static_cast<std::uint8_t>(event.bidValid) | (static_cast<std::uint8_t>(event.askValid) << 1);
        util::writeBE16(object.data() + SymbolIdOffset, event.stockLocate);
        util::writeBE48(object.data() + TimestampOffset, event.sourceTimestamp);
        if (event.bidValid) {
            if (event.bidShares > std::numeric_limits<std::uint32_t>::max()) {
                result.status = GenerateStatus::PayloadValueOverflow;
                return result;
            }
            util::writeBE32(object.data() + Payload0Offset, event.bidPrice);
            util::writeBE32(object.data() + Payload1Offset, static_cast<std::uint32_t>(event.bidShares));
        }
        if (event.askValid) {
            if (event.askShares > std::numeric_limits<std::uint32_t>::max()) {
                result.status = GenerateStatus::PayloadValueOverflow;
                return result;
            }
            util::writeBE32(object.data() + Payload2Offset, event.askPrice);
            util::writeBE32(object.data() + Payload3Offset, static_cast<std::uint32_t>(event.askShares));
        }

        result.object = object;
        result.status = GenerateStatus::Ok;
        return result;
    }

    GenerateResult Generator::generateSymbolStatus(const events::SymbolStatusEvent& event) const {
        GenerateResult result{};
        if (!validTimestamp(event.sourceTimestamp)) {
            result.status = GenerateStatus::TimestampOutOfRange;
            return result;
        }

        SymbolStatus status;
        switch (event.tradingState) {
            case itch::TradingState::Halted:
                status = SymbolStatus::Halted;
                break;
            case itch::TradingState::Paused:
                status = SymbolStatus::Paused;
                break;
            case itch::TradingState::QuotationOnly:
                status = SymbolStatus::QuotationOnly;
                break;
            case itch::TradingState::Trading:
                status = SymbolStatus::Trading;
                break;
            default:
                result.status = GenerateStatus::InvalidSymbolStatus;
                return result;
        }

        InternalProtocolObject object{};
        object[MessageTypeOffset] = static_cast<std::uint8_t>(MessageType::SymbolStatus);
        util::writeBE16(object.data() + SymbolIdOffset, event.stockLocate);
        util::writeBE48(object.data() + TimestampOffset, event.sourceTimestamp);
        util::writeBE32(object.data() + Payload0Offset, static_cast<std::uint32_t>(status));      
        
        result.object = object;
        result.status = GenerateStatus::Ok;
        return result;
    }

    GenerateResult Generator::generateOrderIntent(const OrderIntent& orderIntent) const {
        GenerateResult result{};
        if (!validTimestamp(orderIntent.timestamp)) {
            result.status = GenerateStatus::TimestampOutOfRange;
            return result;
        }
        if (orderIntent.side != OrderSide::Buy && orderIntent.side != OrderSide::Sell) {
            result.status = GenerateStatus::InvalidOrderSide;
            return result;
        }
        
        InternalProtocolObject object{};
        object[MessageTypeOffset] = static_cast<std::uint8_t>(MessageType::OrderIntent);
        util::writeBE16(object.data() + SymbolIdOffset, orderIntent.symbolId);
        util::writeBE48(object.data() + TimestampOffset, orderIntent.timestamp);
        util::writeBE32(object.data() + Payload0Offset, static_cast<std::uint32_t>(orderIntent.side));
        util::writeBE32(object.data() + Payload1Offset, orderIntent.price);
        util::writeBE32(object.data() + Payload2Offset, orderIntent.quantity);
        util::writeBE32(object.data() + Payload3Offset, orderIntent.intentId);

        result.object = object;
        result.status = GenerateStatus::Ok;
        return result;
    }

    GenerateResult Generator::generateConfigCommand(const ConfigCommand& configCmd) const {
        GenerateResult result{};
        if (!validTimestamp(configCmd.timestamp)) {
            result.status = GenerateStatus::TimestampOutOfRange;
            return result;
        }
        switch (configCmd.opcode) {
            case ConfigOpcode::Nop:
            case ConfigOpcode::ResetAll:
            case ConfigOpcode::ResetSymbol:
            case ConfigOpcode::SetSymbolEnabled:
            case ConfigOpcode::SetMaxOrderQty:
            case ConfigOpcode::SetMaxNotional:
            case ConfigOpcode::SetPriceBandTicks:
            case ConfigOpcode::ClearCounters:
                break;

            default:
                result.status = GenerateStatus::InvalidConfigOpcode;
                return result;
        }

        InternalProtocolObject object{};
        object[MessageTypeOffset] = static_cast<std::uint8_t>(MessageType::ConfigControl);
        util::writeBE16(object.data() + SymbolIdOffset, configCmd.symbolId);
        util::writeBE48(object.data() + TimestampOffset, configCmd.timestamp);
        util::writeBE32(object.data() + Payload0Offset, static_cast<std::uint32_t>(configCmd.opcode));
        util::writeBE32(object.data() + Payload1Offset, configCmd.value0);
        util::writeBE32(object.data() + Payload2Offset, configCmd.value1);
        util::writeBE32(object.data() + Payload3Offset, configCmd.configId);

        result.status = GenerateStatus::Ok;
        result.object = object;
        return result;
    }

}