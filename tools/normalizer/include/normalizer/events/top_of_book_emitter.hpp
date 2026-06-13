#pragma once
#include <cstdint>
#include <optional>
#include "normalizer/book/OrderBook.hpp"
#include "normalizer/events/top_of_book_event.hpp"

namespace normalizer::events {
    class TopOfBookEmitter {
    public:
        [[nodiscard]] std::optional<TopOfBookEvent> onBookUpdate(std::uint64_t sourceTimestamp, const book::BookUpdateResult& update);

    private:
        std::uint64_t nextSequenceNumber_{1};
    };

    
}