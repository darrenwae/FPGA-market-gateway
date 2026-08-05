#pragma once
#include "normalizer/itch/messages.hpp"
#include "normalizer/state/stock_locate_table.hpp"
#include <array>
#include <cstdint>


namespace normalizer::state {
    enum class DirectoryUpdateStatus{
        Ok,
        InvalidStockLocate
    };
    
    class SymbolDirectory {

        public:
        [[nodiscard]] bool contains(std::uint16_t stockLocate) const noexcept;
        [[nodiscard]] const std::array<char, 8>* lookup(std::uint16_t stockLocate) const noexcept;
        [[nodiscard]] DirectoryUpdateStatus update(const itch::StockDirectory& stockDirectory);

        private:
        StockLocateTable<std::array<char, 8>> symbolTable_;
    };
    
}