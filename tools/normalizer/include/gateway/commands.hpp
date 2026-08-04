#pragma once
#include <cstdint>



namespace gateway::commands {
    enum class OrderSide : std::uint32_t {
        UnknownInvalid = 0,
        Buy = 1,
        Sell = 2,
    };

    enum class ConfigOpcode : std::uint32_t {
        Nop = 0,
        ResetAll = 1,
        ResetSymbol = 2,
        SetSymbolEnabled = 3,
        SetMaxOrderQty = 4,
        SetMaxNotional = 5,
        SetPriceBandTicks = 6,
    };

    struct OrderIntent {
        std::uint64_t timestamp{0};
        std::uint32_t intentId{0};
        OrderSide side{OrderSide::UnknownInvalid};
        std::uint32_t price{0};
        std::uint32_t quantity{0};
        std::uint16_t symbolId{0};
    };

    struct ConfigCommand {
        std::uint64_t timestamp{0};
        std::uint32_t configId{0};
        ConfigOpcode opcode{ConfigOpcode::Nop};
        std::uint32_t value0{0};
        std::uint32_t value1{0};
        std::uint16_t symbolId{0};
    };
}
