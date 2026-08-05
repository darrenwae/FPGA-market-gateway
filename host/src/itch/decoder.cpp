#include "normalizer/itch/decoder.hpp"
#include "normalizer/util/endian.hpp"
#include <cstring>


namespace normalizer::itch {
namespace{
    bool isValidEventCode(std::uint8_t code){
        switch (code) {
            case 'O':
            case 'S':
            case 'Q':
            case 'M':
            case 'E':
            case 'C':
                return true;
            default:
                return false;
            }
        }
    
    bool isValidTradingState(std::uint8_t state) {
        switch (state) {
            case 'H':
            case 'P':
            case 'Q':
            case 'T':
                return true;
            default:
                return false;
        }
    }

    bool isValidBuySellIndicator(std::uint8_t indicator) {
        switch (indicator) {
            case 'B':
            case 'S':
                return true;
            default:
                return false;
        }
    }

    bool isValidPrintable(std::uint8_t printable) {
        switch (printable) {
            case 'Y':
            case 'N':
                return true;
            default:
                return false;
        }
            
    }

}

    DecodeStatus decodeMessage(const RawMessage& message, DecodedMessage& output) {
        output = std::monostate{}; // clear previous state
        if (message.length == 0) {return DecodeStatus::EmptyMessage; }

        const std::uint8_t* payload = message.payload.data();
        const MessageType messageType = static_cast<MessageType>(static_cast<char>(payload[0]));

        auto readCommonHeader = [&](auto& event) {
            event.messageType = messageType;
            event.stockLocate = util::readBE16(payload + 1);
            event.trackingNumber = util::readBE16(payload + 3);
            event.timestamp = util::readBE48(payload + 5);
        };

        switch (messageType) {
            case MessageType::SystemEvent: {
                if (message.length != 12) { return DecodeStatus::LengthMismatch; }
                SystemEvent event;
                readCommonHeader(event);
                if (!isValidEventCode(payload[11])) { return DecodeStatus::InvalidFieldValue; }
                event.eventCode = static_cast<EventCode>(static_cast<char>(payload[11]));
                output = event;
                return DecodeStatus::Ok;
            }
            case MessageType::StockDirectory: {
                if (message.length != 39) { return DecodeStatus::LengthMismatch; }
                StockDirectory event;
                readCommonHeader(event);
                std::memcpy(event.stock.data(), payload + 11, event.stock.size());
                event.marketCategory = static_cast<char>(payload[19]);
                event.financialStatusIndicator = static_cast<char>(payload[20]);
                event.roundLotSize = util::readBE32(payload + 21);
                event.roundLotsOnly = static_cast<char>(payload[25]);
                event.issueClassification = static_cast<char>(payload[26]);
                std::memcpy(event.issueSubType.data(), payload + 27, event.issueSubType.size());
                event.authenticity = static_cast<char>(payload[29]);
                event.shortSaleThresholdIndicator = static_cast<char>(payload[30]);
                event.ipoFlag = static_cast<char>(payload[31]);
                event.luldReferencePriceTier = static_cast<char>(payload[32]);
                event.etpFlag = static_cast<char>(payload[33]);
                event.etpLeverageFactor = util::readBE32(payload + 34);
                event.inverseIndicator = static_cast<char>(payload[38]);
                output = event;
                return DecodeStatus::Ok;
            }
            case MessageType::StockTradingAction: {
                if (message.length != 25) { return DecodeStatus::LengthMismatch; }
                StockTradingAction event;
                readCommonHeader(event);
                std::memcpy(event.stock.data(), payload + 11, event.stock.size());
                if (!isValidTradingState(payload[19])) { return DecodeStatus::InvalidFieldValue; }
                event.tradingState = static_cast<TradingState>(static_cast<char>(payload[19]));
                event.reserved = static_cast<char>(payload[20]);
                std::memcpy(event.reason.data(), payload + 21, event.reason.size());
                output = event;
                return DecodeStatus::Ok;
            }
            case MessageType::AddOrder: {
                if (message.length != 36) { return DecodeStatus::LengthMismatch; }
                AddOrder event;
                readCommonHeader(event);
                event.orderReferenceNumber = util::readBE64(payload + 11);
                if (!isValidBuySellIndicator(payload[19])) { return DecodeStatus::InvalidFieldValue; }
                event.buySell = static_cast<BuySellIndicator>(static_cast<char>(payload[19]));
                event.shares = util::readBE32(payload + 20);
                std::memcpy(event.stock.data(), payload + 24, event.stock.size());
                event.price = util::readBE32(payload + 32);
                output = event;
                return DecodeStatus::Ok;
            }
            case MessageType::AddOrderWithMPID: {
                if (message.length != 40) { return DecodeStatus::LengthMismatch; }
                AddOrderWithMPID event;
                readCommonHeader(event);
                event.orderReferenceNumber = util::readBE64(payload + 11);
                if (!isValidBuySellIndicator(payload[19])) { return DecodeStatus::InvalidFieldValue; }
                event.buySell = static_cast<BuySellIndicator>(static_cast<char>(payload[19]));
                event.shares = util::readBE32(payload + 20);
                std::memcpy(event.stock.data(), payload + 24, event.stock.size());
                event.price = util::readBE32(payload + 32);
                std::memcpy(event.attribution.data(), payload + 36, event.attribution.size());
                output = event;
                return DecodeStatus::Ok;
            }
            case MessageType::OrderExecuted: {
                if (message.length != 31) { return DecodeStatus::LengthMismatch; }
                OrderExecuted event;
                readCommonHeader(event);
                event.orderReferenceNumber = util::readBE64(payload + 11);
                event.executedShares = util::readBE32(payload + 19);
                event.matchNumber = util::readBE64(payload + 23);
                output = event;
                return DecodeStatus::Ok;            
            }
            case MessageType::OrderExecutedWithPrice: {
                if (message.length != 36) { return DecodeStatus::LengthMismatch; }
                OrderExecutedWithPrice event;
                readCommonHeader(event);
                event.orderReferenceNumber = util::readBE64(payload + 11);
                event.executedShares = util::readBE32(payload + 19);
                event.matchNumber = util::readBE64(payload + 23);
                if (!isValidPrintable(payload[31])) { return DecodeStatus::InvalidFieldValue; }
                event.printable = static_cast<char>(payload[31]);
                event.executionPrice = util::readBE32(payload + 32);
                output = event;
                return DecodeStatus::Ok;
            }
            case MessageType::OrderCancel: {
                if (message.length != 23) { return DecodeStatus::LengthMismatch; }
                OrderCancel event;
                readCommonHeader(event);
                event.orderReferenceNumber = util::readBE64(payload + 11);
                event.cancelledShares = util::readBE32(payload + 19);
                output = event;
                return DecodeStatus::Ok;
            }
            case MessageType::OrderDelete: {
                if (message.length != 19) { return DecodeStatus::LengthMismatch; }
                OrderDelete event;
                readCommonHeader(event);
                event.orderReferenceNumber = util::readBE64(payload + 11);
                output = event;
                return DecodeStatus::Ok;
            }
            case MessageType::OrderReplace: {
                if (message.length != 35) { return DecodeStatus::LengthMismatch; }
                OrderReplace event;
                readCommonHeader(event);
                event.originalOrderReferenceNumber = util::readBE64(payload + 11);
                event.newOrderReferenceNumber = util::readBE64(payload + 19);
                event.shares = util::readBE32(payload + 27);
                event.price = util::readBE32(payload + 31);
                output = event;
                return DecodeStatus::Ok;
            }
            default:
                return DecodeStatus::UnsupportedMessageType;
        }
    }
}