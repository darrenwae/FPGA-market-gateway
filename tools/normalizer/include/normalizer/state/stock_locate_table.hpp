#pragma once
#include <cstddef>
#include <cstdint>
#include <array>
#include <bitset>


namespace normalizer::state {
    template <typename T>
    class StockLocateTable {
        public:
        [[nodiscard]] bool contains(std::uint16_t stockLocate) const noexcept {
            return valid_[stockLocate];
        }

        [[nodiscard]] const T* lookup(std::uint16_t stockLocate) const noexcept {
            return valid_[stockLocate] ? &values_[stockLocate] : nullptr;
        }

        void set(std::uint16_t stockLocate, const T& value) noexcept {
            values_[stockLocate] = value;
            valid_[stockLocate] = true;
        }

        void clear() noexcept {
            valid_.reset();
        }

        private:
        static constexpr std::size_t MaxStockLocateCount = 65536;
        std::array<T, MaxStockLocateCount> values_ {};
        std::bitset<MaxStockLocateCount> valid_ {};
    };
}
