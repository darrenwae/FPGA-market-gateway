#pragma once 
#include <cstdint>
#include "gateway/commands.hpp"


namespace gateway {
    class CommandEmitter {
        public:
        [[nodiscard]] commands::OrderIntent makeOrderIntent(std::uint64_t timestamp, std::uint16_t symbolId, std::uint32_t price, std::uint32_t quantity, commands::OrderSide side);
        [[nodiscard]] commands::ConfigCommand makeConfigCommand(std::uint64_t timestamp, std::uint16_t symbolId, commands::ConfigOpcode opcode, std::uint32_t value0, std::uint32_t value1);
        
        private:
        std::uint32_t nextIntentId_{1};
        std::uint32_t nextConfigId_{1};
    };

}