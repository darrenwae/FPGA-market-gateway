#include "normalizer/state/trading_status_table.hpp"


namespace normalizer::state {
        bool TradingStatusTable::contains(std::uint16_t stockLocate) const noexcept {
        return statusTable_.contains(stockLocate);
    }

    const itch::TradingState* TradingStatusTable::lookup(std::uint16_t stockLocate) const noexcept {
        return statusTable_.lookup(stockLocate);
    }

    TradingStatusUpdateStatus TradingStatusTable::update(const itch::StockTradingAction& stockTradingAction) {
        if (stockTradingAction.stockLocate == 0) { return TradingStatusUpdateStatus::InvalidStockLocate; }
        statusTable_.set(stockTradingAction.stockLocate, stockTradingAction.tradingState);
        return TradingStatusUpdateStatus::Ok;
    }
}
