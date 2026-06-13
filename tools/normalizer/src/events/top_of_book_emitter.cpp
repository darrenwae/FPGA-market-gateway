#include "normalizer/events/top_of_book_emitter.hpp"

namespace normalizer::events {
    std::optional<TopOfBookEvent> TopOfBookEmitter::onBookUpdate(std::uint64_t sourceTimestamp, const book::BookUpdateResult& update) {
        if (!update.topOfBookChanged || update.status != book::BookUpdateStatus::Ok) {
            return std::nullopt;
        }

        TopOfBookEvent topOfBookUpdate{};
        topOfBookUpdate.sequenceNumber = nextSequenceNumber_++;
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

}