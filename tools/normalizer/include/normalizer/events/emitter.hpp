#pragma once
#include <cstdint>
#include <optional>
#include "normalizer/book/OrderBook.hpp"
#include "normalizer/events/top_of_book_event.hpp"
#include "normalizer/events/symbol_status_event.hpp"
#include "normalizer/events/session_status_event.hpp"
#include "normalizer/itch/messages.hpp"


namespace normalizer::events {
    class TopOfBookEmitter {
        public:
        [[nodiscard]] std::optional<TopOfBookEvent> onBookUpdate(std::uint64_t sourceTimestamp, const book::BookUpdateResult& update) const;
    };

    class SessionStatusEmitter {
        public:
        [[nodiscard]] SessionStatusEvent onSystemEvent(const itch::SystemEvent& event) const;
    };

    class SymbolStatusEmitter {
        public:
        [[nodiscard]] SymbolStatusEvent onStockTradingAction(const itch::StockTradingAction& event) const;
    };
    
}