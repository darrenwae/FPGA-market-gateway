#pragma once
#include "normalizer/events/session_status_event.hpp"
#include "normalizer/events/top_of_book_event.hpp"
#include "normalizer/events/symbol_status_event.hpp"
#include "normalizer/internal_protocol/types.hpp"
#include "gateway/commands.hpp"



namespace normalizer::internal_protocol {
    enum class GenerateStatus : std::uint8_t {
        Ok,
        TimestampOutOfRange,
        InvalidSessionState,
        InvalidSymbolStatus,
        InvalidOrderSide,
        InvalidConfigOpcode,
        PayloadValueOverflow
    };

    struct GenerateResult {
        InternalProtocolObject object {0};
        GenerateStatus status {};
    };

    class Generator {
        public:
        [[nodiscard]] GenerateResult generateSessionStatus(const events::SessionStatusEvent& event) const;
        [[nodiscard]] GenerateResult generateTopOfBookUpdate(const events::TopOfBookEvent& event) const;
        [[nodiscard]] GenerateResult generateSymbolStatus(const events::SymbolStatusEvent& event) const;
        [[nodiscard]] GenerateResult generateOrderIntent(const gateway::commands::OrderIntent& orderIntent) const;
        [[nodiscard]] GenerateResult generateConfigCommand(const gateway::commands::ConfigCommand& configCmd) const;
    };

}