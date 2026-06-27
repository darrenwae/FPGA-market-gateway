#include "gateway/command_source.hpp"


namespace gateway {
    CommandSource::CommandSource(const GatewayConfig& config, const OrderIntentPolicy& policy) : config_(config), orderPolicy_(policy) {
        for (const auto symbolId:config_.enabledSymbols) {
            symbolStates_[symbolId].enabled = true;
        }

        if (orderPolicy_.orderInterval == 0) {
            orderPolicy_.orderInterval = 1;
        }
    }

    std::vector<commands::ConfigCommand> CommandSource::startupConfig (std::uint64_t timestamp) {
        std::vector<commands::ConfigCommand> startupConfigCommands {};
        startupConfigCommands.reserve(1 + 4*config_.enabledSymbols.size());

        startupConfigCommands.emplace_back(emitter_.makeConfigCommand(timestamp, 0, commands::ConfigOpcode::ResetAll, 0, 0));

        for (const auto symbolId:config_.enabledSymbols) {
            startupConfigCommands.emplace_back(emitter_.makeConfigCommand(timestamp, symbolId, commands::ConfigOpcode::SetSymbolEnabled, 1, 0));
            startupConfigCommands.emplace_back(emitter_.makeConfigCommand(timestamp, symbolId, commands::ConfigOpcode::SetMaxOrderQty, config_.maxOrderQty, 0));
            startupConfigCommands.emplace_back(emitter_.makeConfigCommand(timestamp, symbolId, commands::ConfigOpcode::SetMaxNotional, config_.maxNotional, 0));
            startupConfigCommands.emplace_back(emitter_.makeConfigCommand(timestamp, symbolId, commands::ConfigOpcode::SetPriceBandTicks, config_.priceBandTicks, 0));
        }

        return startupConfigCommands;
    }

    void CommandSource::observeSessionStatus(const normalizer::events::SessionStatusEvent& event) {
        switch (event.eventCode) {
            case normalizer::itch::EventCode::StartOfMarketHours:
                marketOpen_ = true;
                break;
            case normalizer::itch::EventCode::EndOfMarketHours:
                marketOpen_ = false;
                break;
            default:
                break;
        }
    }

    void CommandSource::observeSymbolStatus(const normalizer::events::SymbolStatusEvent& event) {
        switch (event.tradingState) {
            case normalizer::itch::TradingState::Trading:
                symbolStates_[event.stockLocate].trading = true;
                break;
            default:
                symbolStates_[event.stockLocate].trading = false;
                break;
        }
    }

    std::optional<commands::OrderIntent> CommandSource::maybeCreateOrderIntent(const normalizer::events::TopOfBookEvent& event) {
        auto& state = symbolStates_[event.stockLocate];

        if (!marketOpen_ || !state.trading || !state.enabled) {
            return std::nullopt;
        }

        if (!event.bidValid || !event.askValid || event.bidPrice >= event.askPrice) {
            return std::nullopt;
        }

        if (++state.eligibleTobCount < orderPolicy_.orderInterval) {
            return std::nullopt;
        }

        const auto isBuy = state.nextOrderIsBuy;
        state.nextOrderIsBuy = !state.nextOrderIsBuy;
        state.eligibleTobCount = 0;

        return emitter_.makeOrderIntent(event.sourceTimestamp, event.stockLocate, isBuy ? event.askPrice : event.bidPrice, orderPolicy_.orderQuantity, isBuy ? commands::OrderSide::Buy : commands::OrderSide::Sell);
    }

}