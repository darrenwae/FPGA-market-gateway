#include "normalizer/book/OrderBook.hpp"
#include <cassert>


namespace normalizer::book {
namespace{

    [[nodiscard]] inline std::uint32_t findIndex(const std::array<PriceLevel, MaxPriceLevels>& levels, std::uint32_t active, std::uint32_t bestIndex, std::uint32_t price) noexcept {
        if (active > 0 && levels[bestIndex].price == price) { 
            return bestIndex; 
        }
        for (std::uint32_t i = 0; i < active; ++i) {
            if (levels[i].price == price) { 
                return i; 
            }
        }
        return active;
    }


    template<bool IsBid>
    [[nodiscard]] inline BookUpdateStatus addToSide(std::array<PriceLevel, MaxPriceLevels>& levels, std::uint32_t& active, std::uint32_t& bestIndex, std::uint32_t price, std::uint32_t shares) noexcept {
        if (active == 0) {
            levels[0] = PriceLevel{.aggregateShares = shares, .price = price, .orderCount = 1};
            bestIndex = 0;
            active = 1;
            return BookUpdateStatus::Ok;
        }

        PriceLevel& best = levels[bestIndex];
        if (price == best.price) {
            best.aggregateShares += shares;
            best.orderCount += 1;
            return BookUpdateStatus::Ok;
        }

        if constexpr (IsBid) {
            if (price > best.price) {
                if (active == MaxPriceLevels) { return BookUpdateStatus::PriceLevelCapacityExceeded; }
                bestIndex = active;
                levels[active++] = PriceLevel{.aggregateShares = shares, .price = price, .orderCount = 1};
                return BookUpdateStatus::Ok;
            }
        } 
        else if (price < best.price) {
                if (active == MaxPriceLevels) { return BookUpdateStatus::PriceLevelCapacityExceeded; }
                bestIndex = active;
                levels[active++] = PriceLevel{.aggregateShares = shares, .price = price, .orderCount = 1};
                return BookUpdateStatus::Ok;
        }
        
        for (std::uint32_t i = 0; i < active; ++i) {
            if (levels[i].price == price) {
                levels[i].aggregateShares += shares;
                levels[i].orderCount += 1;
                return BookUpdateStatus::Ok;
            }
        }

        if (active == MaxPriceLevels) { return BookUpdateStatus::PriceLevelCapacityExceeded; }
        levels[active++] = PriceLevel{.aggregateShares = shares, .price = price, .orderCount = 1};
        return BookUpdateStatus::Ok;
    }


    template<bool IsBid>
    [[nodiscard]] inline BookUpdateStatus reduceFromSide(std::array<PriceLevel, MaxPriceLevels>& levels, std::uint32_t& active, std::uint32_t& bestIndex, std::uint32_t price, std::uint32_t shares, bool removeOrder) noexcept {
        const std::uint32_t index = findIndex(levels, active, bestIndex, price);
        if (index == active) { return BookUpdateStatus::PriceLevelNotFound; }

        PriceLevel& level = levels[index];
        if (shares > level.aggregateShares) { return BookUpdateStatus::PriceLevelUnderflow;}
        if (shares == level.aggregateShares) {
            if (!removeOrder) { return BookUpdateStatus::PriceLevelUnderflow; }
            if (level.orderCount != 1) { return BookUpdateStatus::PriceLevelUnderflow; }
        }

        if (removeOrder) {
            if (level.orderCount == 0) { return BookUpdateStatus::PriceLevelUnderflow; }
            if (level.orderCount == 1 && shares != level.aggregateShares) { return BookUpdateStatus::PriceLevelUnderflow; }
            level.orderCount -= 1;
        }

        level.aggregateShares -= shares;
        if (level.aggregateShares == 0) {
            assert(level.orderCount == 0);
            const bool erasedBest = (index == bestIndex);
            const std::uint32_t last = active - 1;

            if (index != last) {
              levels[index] = levels[last];
                if (!erasedBest && bestIndex == last) {
                    bestIndex = index;
                }
            }
            active--;

            if (erasedBest && active > 0) {
                //recompute bestIndex
                bestIndex = 0;
                for (std::uint32_t i = 1; i < active; ++i) {
                    if constexpr (IsBid) {
                        if (levels[i].price > levels[bestIndex].price) { bestIndex = i; }
                    } 
                    else {
                        if (levels[i].price < levels[bestIndex].price) { bestIndex = i; }
                    }
                }
            }
        }
        return BookUpdateStatus::Ok;
    }


    template<bool IsBid>
    [[nodiscard]] inline BookUpdateStatus replaceOnSide(std::array<PriceLevel, MaxPriceLevels>& levels, std::uint32_t& active, std::uint32_t& bestIndex, std::uint32_t oldPrice, std::uint32_t oldShares, std::uint32_t newPrice, std::uint32_t newShares) noexcept {

        // precheck if remove or add will fail
        if (newPrice == 0)  { return BookUpdateStatus::ZeroPrice; }
        if (newShares == 0) { return BookUpdateStatus::ZeroShares; }

        const std::uint32_t oldIndex = findIndex(levels, active, bestIndex, oldPrice);
        if (oldIndex == active) { return BookUpdateStatus::PriceLevelNotFound; }

        const PriceLevel& oldLevel = levels[oldIndex];
        if (oldLevel.orderCount == 0) { return BookUpdateStatus::PriceLevelUnderflow; }
        if (oldShares > oldLevel.aggregateShares) { return BookUpdateStatus::PriceLevelUnderflow; }
        if (oldShares == oldLevel.aggregateShares && oldLevel.orderCount != 1) {
            return BookUpdateStatus::PriceLevelUnderflow;
        }

        const bool oldSlotFreed = (oldLevel.orderCount == 1 && oldShares == oldLevel.aggregateShares);
        const bool newLevelExist = (findIndex(levels, active, bestIndex, newPrice) != active);
        if (!newLevelExist && !oldSlotFreed && active == MaxPriceLevels) {
            return BookUpdateStatus::PriceLevelCapacityExceeded;
        }

        // replace after validation
        const BookUpdateStatus reduceStatus = reduceFromSide<IsBid>(levels, active, bestIndex, oldPrice, oldShares, true);
        if (reduceStatus != BookUpdateStatus::Ok) {
            return BookUpdateStatus::BookInconsistent;
        }
        const BookUpdateStatus addStatus = addToSide<IsBid>(levels, active, bestIndex, newPrice, newShares);
        if (addStatus != BookUpdateStatus::Ok) {
            return BookUpdateStatus::BookInconsistent;
        }
        return BookUpdateStatus::Ok;
    }
        
}


    [[nodiscard]] BookUpdateStatus InstrumentBook::add(itch::BuySellIndicator side, std::uint32_t price, std::uint32_t shares) {
        if (price == 0)  return BookUpdateStatus::ZeroPrice;
        if (shares == 0) return BookUpdateStatus::ZeroShares;
        switch (side) {
            case itch::BuySellIndicator::Buy:
                return addToSide<true> (bids, activeBids, bestBidIndex, price, shares);
            case itch::BuySellIndicator::Sell: 
                return addToSide<false>(asks, activeAsks, bestAskIndex, price, shares);
            default:
                return BookUpdateStatus::InvalidSide;
        }
    }

    [[nodiscard]] BookUpdateStatus InstrumentBook::reduce(itch::BuySellIndicator side, std::uint32_t price, std::uint32_t shares, bool removeOrder) {
        if (price == 0)  return BookUpdateStatus::ZeroPrice;
        if (shares == 0) return BookUpdateStatus::ZeroShares;
        switch (side) {
            case itch::BuySellIndicator::Buy:
                return reduceFromSide<true>(bids, activeBids, bestBidIndex, price, shares, removeOrder);
            case itch::BuySellIndicator::Sell:
                return reduceFromSide<false>(asks, activeAsks, bestAskIndex, price, shares, removeOrder);
            default: 
                return BookUpdateStatus::InvalidSide;
        }
    }

    [[nodiscard]] BookUpdateStatus InstrumentBook::replace(itch::BuySellIndicator side, std::uint32_t oldPrice, std::uint32_t oldShares, std::uint32_t newPrice, std::uint32_t newShares) {
        switch (side) {
            case itch::BuySellIndicator::Buy:
                return replaceOnSide<true>(bids, activeBids, bestBidIndex, oldPrice, oldShares, newPrice, newShares);
            case itch::BuySellIndicator::Sell:
                return replaceOnSide<false>(asks, activeAsks, bestAskIndex, oldPrice, oldShares, newPrice, newShares);
            default:
                return BookUpdateStatus::InvalidSide;
        }
    }

    [[nodiscard]] TopOfBook InstrumentBook::topOfBook() const {
        TopOfBook result{};

        if (activeBids > 0) {
            const PriceLevel& bestBid = bids[bestBidIndex];
            result.bidValid = true;
            result.bidPrice = bestBid.price;
            result.bidShares = bestBid.aggregateShares;
        }
        if (activeAsks > 0) {
            const PriceLevel& bestAsk = asks[bestAskIndex];
            result.askValid = true;
            result.askPrice = bestAsk.price;
            result.askShares = bestAsk.aggregateShares;
        }

        return result;
    }

    BookUpdateResult OrderBook::applyAdd(std::uint16_t stockLocate, std::uint64_t orderReferenceNumber,itch::BuySellIndicator side, std::uint32_t price, std::uint32_t shares) {
        BookUpdateResult result;
        if (stockLocate == 0) {
        result.status = BookUpdateStatus::InvalidStockLocate;
        return result;
        }
        if (orders_.contains(orderReferenceNumber)) {
            result.status = BookUpdateStatus::DuplicateOrderReference;
            return result;
        }

        result.stockLocate = stockLocate;

        InstrumentBook* book = nullptr;
        const auto* bookIndex = orderBookIndex_.lookup(stockLocate);
        if (bookIndex != nullptr) {
            book = &orderBook_[*bookIndex];
        } 
        else {
            const auto newIndex = static_cast<std::uint32_t>(orderBook_.size());
            orderBook_.emplace_back();
            orderBookIndex_.set(stockLocate, newIndex);
            book = &orderBook_[newIndex];
        }

        const TopOfBook before = book->topOfBook();
        const BookUpdateStatus status = book->add(side, price, shares);
        if (status != BookUpdateStatus::Ok) {
            result.status = status;
            return result;
        }

        orders_.emplace(orderReferenceNumber,OrderState{.price = price, .remainingShares = shares, .stockLocate = stockLocate, .side = side});
        const TopOfBook after = book->topOfBook();
        result.topOfBookChanged = (before != after);
        result.topOfBook = after;
        result.status = BookUpdateStatus::Ok;
        return result;
    }



    BookUpdateResult OrderBook::applyReduce(std::uint16_t stockLocate, std::uint64_t orderReferenceNumber, std::optional<std::uint32_t> reduceShares) {
        BookUpdateResult result;
        if (stockLocate == 0) {
            result.status = BookUpdateStatus::InvalidStockLocate;
            return result;
        }

        auto orderIt = orders_.find(orderReferenceNumber);
        if (orderIt == orders_.end()) {
            result.status = BookUpdateStatus::UnknownOrderReference;
            return result;
        }

        OrderState& order = orderIt->second;
        assert(order.stockLocate == stockLocate);
        result.stockLocate = stockLocate;

        const std::uint32_t shares = reduceShares.value_or(order.remainingShares);
        if (reduceShares.has_value() && shares > order.remainingShares) {
            result.status = BookUpdateStatus::OrderSharesUnderflow;
            return result;
        }

        const auto* bookIndex = orderBookIndex_.lookup(order.stockLocate);
        if (bookIndex == nullptr) {
            result.status = BookUpdateStatus::BookInconsistent;
            return result;
        }
        InstrumentBook* book = &orderBook_[*bookIndex];

        const TopOfBook before = book->topOfBook();
        const bool removeOrder = (shares == order.remainingShares);
        const BookUpdateStatus status = book->reduce(order.side, order.price, shares, removeOrder);
        if (status != BookUpdateStatus::Ok) {
            result.status = status;
            return result;
        }

        if (removeOrder) {
            orders_.erase(orderReferenceNumber);
        } 
        else {
            order.remainingShares -= shares;
        }

        const TopOfBook after = book->topOfBook();
        result.topOfBookChanged = (before != after);
        result.topOfBook = after;
        result.status = BookUpdateStatus::Ok;
        return result;
    }


    [[nodiscard]] BookUpdateResult OrderBook::onAddOrder(const itch::AddOrder& event) {
        return applyAdd(event.stockLocate, event.orderReferenceNumber, event.buySell, event.price, event.shares);
    }

    [[nodiscard]] BookUpdateResult OrderBook::onAddOrderWithMPID(const itch::AddOrderWithMPID& event) {
        return applyAdd(event.stockLocate, event.orderReferenceNumber, event.buySell, event.price, event.shares);
    }

    [[nodiscard]] BookUpdateResult OrderBook::onOrderExecuted(const itch::OrderExecuted& event) {
        return applyReduce(event.stockLocate, event.orderReferenceNumber, event.executedShares);
    }

    [[nodiscard]] BookUpdateResult OrderBook::onOrderExecutedWithPrice(const itch::OrderExecutedWithPrice& event) {
        return applyReduce(event.stockLocate, event.orderReferenceNumber, event.executedShares);
    }

    [[nodiscard]] BookUpdateResult OrderBook::onOrderCancel(const itch::OrderCancel& event) {
        return applyReduce(event.stockLocate, event.orderReferenceNumber, event.cancelledShares);
    }

    [[nodiscard]] BookUpdateResult OrderBook::onOrderDelete(const itch::OrderDelete& event) {
        return applyReduce(event.stockLocate, event.orderReferenceNumber, std::nullopt);
    }

    [[nodiscard]] BookUpdateResult OrderBook::onOrderReplace(const itch::OrderReplace& event) {
        BookUpdateResult result;
        if (event.stockLocate == 0) {
            result.status = BookUpdateStatus::InvalidStockLocate;
            return result;
        }

        auto orderIt = orders_.find(event.originalOrderReferenceNumber);
        if (orderIt == orders_.end()) {
            result.status = BookUpdateStatus::UnknownOrderReference;
            return result;
        }
        if (orders_.contains(event.newOrderReferenceNumber)) {
            result.status = BookUpdateStatus::DuplicateOrderReference;
            return result;
        }

        OrderState& originalOrder = orderIt->second;
        assert(originalOrder.stockLocate == event.stockLocate);
        result.stockLocate = event.stockLocate;

        const std::uint16_t stockLocate = originalOrder.stockLocate;
        const itch::BuySellIndicator side = originalOrder.side;
        const std::uint32_t oldPrice = originalOrder.price;
        const std::uint32_t oldShares = originalOrder.remainingShares;

        const auto* bookIndex = orderBookIndex_.lookup(stockLocate);
        if (bookIndex == nullptr) {
            result.status = BookUpdateStatus::BookInconsistent;
            return result;
        }
        InstrumentBook* book = &orderBook_[*bookIndex];
        const TopOfBook before = book->topOfBook();

        const BookUpdateStatus status = book->replace(side, oldPrice, oldShares, event.price, event.shares);
        if (status != BookUpdateStatus::Ok) {
            result.status = status;
            return result;
        }

        orders_.erase(event.originalOrderReferenceNumber);
        orders_.emplace(event.newOrderReferenceNumber, OrderState{.price = event.price, .remainingShares = event.shares, .stockLocate = stockLocate, .side = side});

        const TopOfBook after = book->topOfBook();
        result.topOfBookChanged = (before != after);
        result.topOfBook = after;
        result.status = BookUpdateStatus::Ok;
        return result;
    }

    OrderBook::OrderBook() {
        orderBook_.reserve(expectedSymbols);
        orders_.reserve(expectedPeakOrders);
    }

}