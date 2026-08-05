#pragma once
#include "normalizer/itch/messages.hpp"
#include "normalizer/state/stock_locate_table.hpp"
#include <cstdint>


namespace normalizer::state {
    enum class TradingStatusUpdateStatus{
        Ok,
        InvalidStockLocate
    };
    
    class TradingStatusTable {

        public:
        [[nodiscard]] bool contains(std::uint16_t stockLocate) const noexcept;
        [[nodiscard]] const itch::TradingState* lookup(std::uint16_t stockLocate) const noexcept;
        [[nodiscard]] TradingStatusUpdateStatus update(const itch::StockTradingAction& stockTradingAction);

        private:
        StockLocateTable<itch::TradingState> statusTable_;
    };
    
}