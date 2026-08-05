#include "normalizer/book/OrderBook.hpp"
#include <utility>

namespace normalizer::book {
    namespace {

        template <bool IsBid>
        [[nodiscard]] constexpr bool betterPrice(std::uint32_t lhs, std::uint32_t rhs) noexcept {
            if constexpr (IsBid) {
                return lhs > rhs;
            }
            return lhs < rhs;
        }

        void swapLevels(BookSide& side, std::uint32_t lhs, std::uint32_t rhs) noexcept {
            if (lhs == rhs) {
                return;
            }

            std::swap(side.levels[lhs], side.levels[rhs]);
            *side.levelIndexByPrice.find(side.levels[lhs].price) = lhs;
            *side.levelIndexByPrice.find(side.levels[rhs].price) = rhs;
        }

        template <bool IsBid>
        void siftUp(BookSide& side, std::uint32_t index) noexcept {
            while (index > 0) {
                const std::uint32_t parent = (index - 1) / 2;
                if (!betterPrice<IsBid>(side.levels[index].price, side.levels[parent].price)) {
                    break;
                }

                swapLevels(side, index, parent);
                index = parent;
            }
        }

        template <bool IsBid>
        void siftDown(BookSide& side, std::uint32_t index) noexcept {
            const auto levelCount = static_cast<std::uint32_t>(side.levelIndexByPrice.size());
            while (true) {
                const std::uint32_t left = index * 2 + 1;

                if (left >= levelCount) {
                    return;
                }

                const std::uint32_t right = left + 1;
                std::uint32_t betterChild = left;

                if (right < levelCount &&
                    betterPrice<IsBid>(side.levels[right].price, side.levels[left].price)) {
                    betterChild = right;
                }
                if (!betterPrice<IsBid>(side.levels[betterChild].price, side.levels[index].price)) {
                    return;
                }

                swapLevels(side, index, betterChild);
                index = betterChild;
            }
        }

        template <bool IsBid>
        [[nodiscard]] BookUpdateStatus addToSide(BookSide& side, std::uint32_t price, std::uint32_t shares) noexcept {
            if (const auto* existingIndex = side.levelIndexByPrice.find(price)) {
                PriceLevel& level = side.levels[*existingIndex];
                level.aggregateShares += shares;
                ++level.orderCount;
                return BookUpdateStatus::Ok;
            }

            if (side.levelIndexByPrice.full()) {
                return BookUpdateStatus::PriceLevelCapacityExceeded;
            }

            const auto newIndex = static_cast<std::uint32_t>(side.levelIndexByPrice.size());
            side.levels[newIndex] = PriceLevel{.aggregateShares = shares, .price = price, .orderCount = 1};
            side.levelIndexByPrice.insert(price, newIndex);

            siftUp<IsBid>(side, newIndex);
            return BookUpdateStatus::Ok;
        }

        template <bool IsBid>
        [[nodiscard]] BookUpdateStatus reduceFromSide(BookSide& side, std::uint32_t price, std::uint32_t shares, bool removeOrder) noexcept {
            const auto* foundIndex = side.levelIndexByPrice.find(price);
            if (foundIndex == nullptr) {
                return BookUpdateStatus::PriceLevelNotFound;
            }

            const std::uint32_t index = *foundIndex;
            PriceLevel& level = side.levels[index];
            if (shares > level.aggregateShares || level.orderCount == 0) {
                return BookUpdateStatus::PriceLevelUnderflow;
            }
            if (shares == level.aggregateShares && (!removeOrder || level.orderCount != 1)) {
                return BookUpdateStatus::PriceLevelUnderflow;
            }
            if (removeOrder && level.orderCount == 1 && shares != level.aggregateShares) {
                return BookUpdateStatus::PriceLevelUnderflow;
            }

            level.aggregateShares -= shares;
            if (removeOrder) {
                --level.orderCount;
            }

            if (level.aggregateShares != 0) {
                return BookUpdateStatus::Ok;
            }

            const auto lastIndex = static_cast<std::uint32_t>(side.levelIndexByPrice.size() - 1);
            side.levelIndexByPrice.erase(price);

            if (index == lastIndex) {
                return BookUpdateStatus::Ok;
            }

            side.levels[index] = side.levels[lastIndex];
            *side.levelIndexByPrice.find(side.levels[index].price) = index;

            if (index > 0) {
                const std::uint32_t parent = (index - 1) / 2;
                if (betterPrice<IsBid>(side.levels[index].price, side.levels[parent].price)) {
                    siftUp<IsBid>(side, index);
                    return BookUpdateStatus::Ok;
                }
            }

            siftDown<IsBid>(side, index);
            return BookUpdateStatus::Ok;
        }

        template <bool IsBid>
        [[nodiscard]] BookUpdateStatus replaceOnSide(BookSide& side, std::uint32_t oldPrice, std::uint32_t oldShares, std::uint32_t newPrice, std::uint32_t newShares) noexcept {
            if (newPrice == 0) {
                return BookUpdateStatus::ZeroPrice;
            }
            if (newShares == 0) {
                return BookUpdateStatus::ZeroShares;
            }

            const auto* oldIndex = side.levelIndexByPrice.find(oldPrice);
            if (oldIndex == nullptr) {
                return BookUpdateStatus::PriceLevelNotFound;
            }

            PriceLevel& oldLevel = side.levels[*oldIndex];
            if (oldLevel.orderCount == 0 || oldShares > oldLevel.aggregateShares || (oldLevel.orderCount == 1 && oldShares != oldLevel.aggregateShares) || (oldShares == oldLevel.aggregateShares && oldLevel.orderCount != 1)) {
                return BookUpdateStatus::PriceLevelUnderflow;
            }

            if (newPrice == oldPrice) {
                oldLevel.aggregateShares = oldLevel.aggregateShares - oldShares + newShares;
                return BookUpdateStatus::Ok;
            }

            const bool oldLevelRemoved = oldLevel.orderCount == 1 && oldShares == oldLevel.aggregateShares;
            const bool newLevelExists = side.levelIndexByPrice.contains(newPrice);
            if (!oldLevelRemoved && !newLevelExists && side.levelIndexByPrice.full()) {
                return BookUpdateStatus::PriceLevelCapacityExceeded;
            }

            static_cast<void>(
                reduceFromSide<IsBid>(side, oldPrice, oldShares, true));
            static_cast<void>(addToSide<IsBid>(side, newPrice, newShares));
            return BookUpdateStatus::Ok;
        }

    } // namespace

    [[nodiscard]] BookUpdateStatus InstrumentBook::add(itch::BuySellIndicator side, std::uint32_t price, std::uint32_t shares) {
        if (price == 0)
            return BookUpdateStatus::ZeroPrice;
        if (shares == 0)
            return BookUpdateStatus::ZeroShares;
        switch (side) {
        case itch::BuySellIndicator::Buy:
            return addToSide<true>(bids, price, shares);
        case itch::BuySellIndicator::Sell:
            return addToSide<false>(asks, price, shares);
        default:
            return BookUpdateStatus::InvalidSide;
        }
    }

    [[nodiscard]] BookUpdateStatus InstrumentBook::reduce(itch::BuySellIndicator side, std::uint32_t price, std::uint32_t shares, bool removeOrder) {
        if (price == 0)
            return BookUpdateStatus::ZeroPrice;
        if (shares == 0)
            return BookUpdateStatus::ZeroShares;
        switch (side) {
        case itch::BuySellIndicator::Buy:
            return reduceFromSide<true>(bids, price, shares, removeOrder);
        case itch::BuySellIndicator::Sell:
            return reduceFromSide<false>(asks, price, shares, removeOrder);
        default:
            return BookUpdateStatus::InvalidSide;
        }
    }

    [[nodiscard]] BookUpdateStatus InstrumentBook::replace(itch::BuySellIndicator side, std::uint32_t oldPrice, std::uint32_t oldShares, std::uint32_t newPrice, std::uint32_t newShares) {
        switch (side) {
        case itch::BuySellIndicator::Buy:
            return replaceOnSide<true>(bids, oldPrice, oldShares, newPrice, newShares);
        case itch::BuySellIndicator::Sell:
            return replaceOnSide<false>(asks, oldPrice, oldShares, newPrice, newShares);
        default:
            return BookUpdateStatus::InvalidSide;
        }
    }

    [[nodiscard]] TopOfBook InstrumentBook::topOfBook() const {
        TopOfBook result{};

        if (bids.levelIndexByPrice.size() != 0) {
            const PriceLevel& bestBid = bids.levels[0];
            result.bidValid = true;
            result.bidPrice = bestBid.price;
            result.bidShares = bestBid.aggregateShares;
        }

        if (asks.levelIndexByPrice.size() != 0) {
            const PriceLevel& bestAsk = asks.levels[0];
            result.askValid = true;
            result.askPrice = bestAsk.price;
            result.askShares = bestAsk.aggregateShares;
        }

        return result;
    }

    BookUpdateResult OrderBook::applyAdd(std::uint16_t stockLocate, std::uint64_t orderReferenceNumber, itch::BuySellIndicator side, std::uint32_t price, std::uint32_t shares) {
        BookUpdateResult result{};

        if (stockLocate == 0) {
            result.status = BookUpdateStatus::InvalidStockLocate;
            return result;
        }

        result.stockLocate = stockLocate;
        const auto* bookIndex = orderBookIndex_.lookup(stockLocate);
        if (bookIndex == nullptr) {
            result.status = BookUpdateStatus::SymbolNotTracked;
            return result;
        }

        if (orders_.contains(orderReferenceNumber)) {
            result.status = BookUpdateStatus::DuplicateOrderReference;
            return result;
        }

        if (orders_.full()) {
            result.status = BookUpdateStatus::OrderCapacityExceeded;
            return result;
        }

        InstrumentBook& book = orderBook_[*bookIndex];
        const TopOfBook before = book.topOfBook();
        const BookUpdateStatus status = book.add(side, price, shares);

        if (status != BookUpdateStatus::Ok) {
            result.status = status;
            return result;
        }

        orders_.insert(orderReferenceNumber, OrderState{.price = price, .remainingShares = shares, .side = side});

        const TopOfBook after = book.topOfBook();
        result.topOfBookChanged = before != after;
        result.topOfBook = after;
        result.status = BookUpdateStatus::Ok;
        return result;
    }

    BookUpdateResult OrderBook::applyReduce(std::uint16_t stockLocate, std::uint64_t orderReferenceNumber, std::optional<std::uint32_t> reduceShares) {
        BookUpdateResult result{};

        if (stockLocate == 0) {
            result.status = BookUpdateStatus::InvalidStockLocate;
            return result;
        }

        const auto* bookIndex = orderBookIndex_.lookup(stockLocate);
        if (bookIndex == nullptr) {
            result.status = BookUpdateStatus::SymbolNotTracked;
            return result;
        }

        OrderState* order = orders_.find(orderReferenceNumber);
        if (order == nullptr) {
            result.status = BookUpdateStatus::UnknownOrderReference;
            return result;
        }

        result.stockLocate = stockLocate;
        const std::uint32_t shares = reduceShares.value_or(order->remainingShares);
        if (reduceShares.has_value() && shares > order->remainingShares) {
            result.status = BookUpdateStatus::OrderSharesUnderflow;
            return result;
        }

        InstrumentBook& book = orderBook_[*bookIndex];
        const TopOfBook before = book.topOfBook();
        const bool removeOrder = shares == order->remainingShares;
        const BookUpdateStatus status = book.reduce(order->side, order->price, shares, removeOrder);

        if (status != BookUpdateStatus::Ok) {
            result.status = status;
            return result;
        }

        if (removeOrder) {
            orders_.erase(orderReferenceNumber);
        }
        else {
            order->remainingShares -= shares;
        }

        const TopOfBook after = book.topOfBook();
        result.topOfBookChanged = before != after;
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

    BookUpdateResult OrderBook::onOrderReplace(const itch::OrderReplace& event) {
        BookUpdateResult result{};
        if (event.stockLocate == 0) {
            result.status = BookUpdateStatus::InvalidStockLocate;
            return result;
        }

        const auto* bookIndex = orderBookIndex_.lookup(event.stockLocate);
        if (bookIndex == nullptr) {
            result.status = BookUpdateStatus::SymbolNotTracked;
            return result;
        }

        OrderState* originalOrder = orders_.find(event.originalOrderReferenceNumber);
        if (originalOrder == nullptr) {
            result.status = BookUpdateStatus::UnknownOrderReference;
            return result;
        }
        if (orders_.contains(event.newOrderReferenceNumber)) {
            result.status = BookUpdateStatus::DuplicateOrderReference;
            return result;
        }

        result.stockLocate = event.stockLocate;
        const itch::BuySellIndicator side = originalOrder->side;
        const std::uint32_t oldPrice = originalOrder->price;
        const std::uint32_t oldShares = originalOrder->remainingShares;
        InstrumentBook& book = orderBook_[*bookIndex];
        const TopOfBook before = book.topOfBook();

        const BookUpdateStatus status = book.replace(side, oldPrice, oldShares, event.price, event.shares);
        if (status != BookUpdateStatus::Ok) {
            result.status = status;
            return result;
        }

        orders_.erase(event.originalOrderReferenceNumber);
        orders_.insert(event.newOrderReferenceNumber, OrderState{.price = event.price, .remainingShares = event.shares, .side = side});

        const TopOfBook after = book.topOfBook();
        result.topOfBookChanged = before != after;
        result.topOfBook = after;
        result.status = BookUpdateStatus::Ok;
        return result;
    }

    OrderBook::OrderBook(std::span<const std::uint16_t> enabledSymbols) : orderBook_(enabledSymbols.size()) {
        for (std::size_t index = 0; index < enabledSymbols.size(); ++index) {
            orderBookIndex_.set(enabledSymbols[index], static_cast<std::uint32_t>(index));
        }
    }

} // namespace normalizer::book
