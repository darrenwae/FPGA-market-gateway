#pragma once
#include <vector>
#include <cstdint>
#include <optional>
#include <array>
#include <cstddef>
#include "gateway/commands.hpp"
#include "gateway/command_emitter.hpp"
#include "normalizer/events/top_of_book_event.hpp"
#include "normalizer/events/session_status_event.hpp"
#include "normalizer/events/symbol_status_event.hpp"


namespace gateway {
    struct GatewayConfig {
        std::vector<std::uint16_t> enabledSymbols {};
        std::uint32_t maxOrderQty {1000};
        std::uint32_t maxNotional {1'000'000'000};
        std::uint32_t priceBandTicks {10};
    };

    struct OrderIntentPolicy {
        std::uint32_t orderQuantity {100};
        std::uint64_t orderInterval {1000}; // N eligible TOB updates. Adjustable
    };

    class CommandSource {
        public:
        explicit CommandSource(const GatewayConfig& config, const OrderIntentPolicy& policy);
        [[nodiscard]] std::vector<commands::ConfigCommand> startupConfig (std::uint64_t timestamp);

        //policy to create OrderIntent can be changed 
        //current policy: one OrderIntent every N eligible TOB updates per enabled symbol
        [[nodiscard]] std::optional<commands::OrderIntent> maybeCreateOrderIntent(const normalizer::events::TopOfBookEvent& event);
        void observeSessionStatus(const normalizer::events::SessionStatusEvent& event);
        void observeSymbolStatus(const normalizer::events::SymbolStatusEvent& event);
        
        private:
        GatewayConfig config_;
        OrderIntentPolicy orderPolicy_;
        CommandEmitter emitter_;

        static constexpr std::size_t SymbolCapacity {65536};
        struct SymbolCommandState {
            std::uint64_t eligibleTobCount {0};
            bool enabled {false};
            bool trading {false};
            bool nextOrderIsBuy {true};
        };
        bool marketOpen_ {false};
        std::array<SymbolCommandState, SymbolCapacity> symbolStates_ {};


    };
}