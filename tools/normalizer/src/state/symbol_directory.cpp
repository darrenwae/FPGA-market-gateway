#include "normalizer/state/symbol_directory.hpp"

namespace normalizer::state {
    bool SymbolDirectory::contains(std::uint16_t stockLocate) const noexcept {
        return symbolTable_.contains(stockLocate);
    }

    const std::array<char, 8>* SymbolDirectory::lookup(std::uint16_t stockLocate) const noexcept {
        return symbolTable_.lookup(stockLocate);
    }

    DirectoryUpdateStatus SymbolDirectory::update(const itch::StockDirectory& stockDirectory) {
        if (stockDirectory.stockLocate == 0) { return DirectoryUpdateStatus::InvalidStockLocate; }
        symbolTable_.set(stockDirectory.stockLocate, stockDirectory.stock);
        return DirectoryUpdateStatus::Ok;
    }

}