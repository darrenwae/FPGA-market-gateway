#pragma once
#include <cstdint>
#include "normalizer/itch/messages.hpp"


namespace normalizer::events {
    struct SymbolStatusEvent {
        std::uint64_t sourceTimestamp{0};
        std::uint16_t stockLocate{0};
        itch::TradingState tradingState{};
    };
}