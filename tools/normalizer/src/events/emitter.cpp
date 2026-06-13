#include "normalizer/events/emitter.hpp"

namespace normalizer::events {
    std::optional<TopOfBookEvent> TopOfBookEmitter::onBookUpdate(std::uint64_t sourceTimestamp, const book::BookUpdateResult& update) const {
        if (!update.topOfBookChanged || update.status != book::BookUpdateStatus::Ok) {
            return std::nullopt;
        }

        TopOfBookEvent topOfBookUpdate{};
        topOfBookUpdate.sourceTimestamp = sourceTimestamp;
        topOfBookUpdate.bidShares = update.topOfBook.bidShares;
        topOfBookUpdate.askShares = update.topOfBook.askShares;
        topOfBookUpdate.bidPrice = update.topOfBook.bidPrice;
        topOfBookUpdate.askPrice = update.topOfBook.askPrice;
        topOfBookUpdate.stockLocate = update.stockLocate;
        topOfBookUpdate.bidValid = update.topOfBook.bidValid;
        topOfBookUpdate.askValid = update.topOfBook.askValid;
        return topOfBookUpdate;
    }

    SessionStatusEvent SessionStatusEmitter::onSystemEvent(const itch::SystemEvent& event) const {
        SessionStatusEvent sessionStatusUpdate{};
        sessionStatusUpdate.sourceTimestamp = event.timestamp;
        sessionStatusUpdate.eventCode = event.eventCode;
        return sessionStatusUpdate;
    }

    SymbolStatusEvent SymbolStatusEmitter::onStockTradingAction(const itch::StockTradingAction& event) const {
        SymbolStatusEvent symbolStatusUpdate{};
        symbolStatusUpdate.sourceTimestamp = event.timestamp;
        symbolStatusUpdate.stockLocate = event.stockLocate;
        symbolStatusUpdate.tradingState = event.tradingState;
        return symbolStatusUpdate;
    }


}