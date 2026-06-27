#include "gateway/command_emitter.hpp"


namespace gateway {
    using OrderIntent = gateway::commands::OrderIntent;
    using ConfigCommand = gateway::commands::ConfigCommand;


    OrderIntent CommandEmitter::makeOrderIntent(std::uint64_t timestamp, std::uint16_t symbolId, std::uint32_t price, std::uint32_t quantity, commands::OrderSide side) {
        OrderIntent orderIntent{};
        orderIntent.timestamp = timestamp;
        orderIntent.symbolId = symbolId;
        orderIntent.price = price;
        orderIntent.quantity = quantity;
        orderIntent.side = side;
        orderIntent.intentId = nextIntentId_++;
        return orderIntent;
    }
    
    ConfigCommand CommandEmitter::makeConfigCommand(std::uint64_t timestamp, std::uint16_t symbolId, commands::ConfigOpcode opcode, std::uint32_t value0, std::uint32_t value1) {
        ConfigCommand configCmd{};
        configCmd.timestamp = timestamp;
        configCmd.symbolId = symbolId;
        configCmd.opcode = opcode;
        configCmd.value0 = value0;
        configCmd.value1 = value1;
        configCmd.configId = nextConfigId_++;
        return configCmd;
    }

}