#pragma once
#include <cstdint>
#include <cstddef>
#include <array>
#include <vector>
#include <optional>
#include "normalizer/itch/messages.hpp"
#include "normalizer/state/stock_locate_table.hpp"
#include <boost/unordered/unordered_flat_map.hpp>



namespace normalizer::book {
    enum class BookUpdateStatus {
        Ok,
        InvalidSide,
        InvalidStockLocate,
        ZeroPrice,
        ZeroShares,
        DuplicateOrderReference,
        UnknownOrderReference,
        PriceLevelCapacityExceeded,
        PriceLevelNotFound,
        PriceLevelUnderflow,
        OrderSharesUnderflow,
        BookInconsistent
    };


    // represents the state of an active order.
    struct OrderState {
        std::uint32_t price {0};
        std::uint32_t remainingShares {0};
        std::uint16_t stockLocate {0};
        itch::BuySellIndicator side {};
    };

    // represents a single row inside an instrument's book
    struct PriceLevel {
        std::uint64_t aggregateShares {0};
        std::uint32_t price {0};
        std::uint32_t orderCount {0};
    };

    struct TopOfBook {
        std::uint64_t bidShares{0};
        std::uint64_t askShares{0};
        std::uint32_t bidPrice{0};
        std::uint32_t askPrice{0};
        bool bidValid {false};
        bool askValid {false};
        bool operator==(const TopOfBook&) const = default;
    };

    static constexpr std::size_t MaxPriceLevels = 4096; // adjust levels

    // represents the book for a single instrument
    struct InstrumentBook {
        std::array<PriceLevel, MaxPriceLevels> bids {};
        std::array<PriceLevel, MaxPriceLevels> asks {};
        std::uint32_t activeBids {0};
        std::uint32_t activeAsks {0};
        std::uint32_t bestBidIndex{0};
        std::uint32_t bestAskIndex{0};

        [[nodiscard]] BookUpdateStatus add(itch::BuySellIndicator side, std::uint32_t price, std::uint32_t shares);
        [[nodiscard]] BookUpdateStatus reduce(itch::BuySellIndicator side, std::uint32_t price, std::uint32_t shares, bool removeOrder);
        [[nodiscard]] BookUpdateStatus replace(itch::BuySellIndicator side, std::uint32_t oldPrice, std::uint32_t oldShares, std::uint32_t newPrice, std::uint32_t newShares);
        [[nodiscard]] TopOfBook topOfBook() const;  
    };

    struct BookUpdateResult {
        BookUpdateStatus status {};
        std::uint16_t stockLocate {0};
        bool topOfBookChanged {false};
        TopOfBook topOfBook {};

    };

    using OrderDirectory = boost::unordered_flat_map<std::uint64_t, OrderState>;

    class OrderBook {
        public:
        OrderBook();
        [[nodiscard]] BookUpdateResult onAddOrder(const itch::AddOrder& event);
        [[nodiscard]] BookUpdateResult onAddOrderWithMPID(const itch::AddOrderWithMPID& event);
        [[nodiscard]] BookUpdateResult onOrderExecuted(const itch::OrderExecuted& event);
        [[nodiscard]] BookUpdateResult onOrderExecutedWithPrice(const itch::OrderExecutedWithPrice& event);
        [[nodiscard]] BookUpdateResult onOrderCancel(const itch::OrderCancel& event);
        [[nodiscard]] BookUpdateResult onOrderDelete(const itch::OrderDelete& event);
        [[nodiscard]] BookUpdateResult onOrderReplace(const itch::OrderReplace& event);
        
        private:
        BookUpdateResult applyAdd(std::uint16_t stockLocate, std::uint64_t orderReferenceNumber,itch::BuySellIndicator side, std::uint32_t price, std::uint32_t shares);
        BookUpdateResult applyReduce(std::uint16_t stockLocate, std::uint64_t orderReferenceNumber, std::optional<std::uint32_t> reduceShares);
        static constexpr std::size_t expectedSymbols = 10000;
        static constexpr std::size_t expectedPeakOrders = 1000000;
        state::StockLocateTable<std::uint32_t> orderBookIndex_;
        std::vector<InstrumentBook> orderBook_;
        OrderDirectory orders_;
    
    };

}