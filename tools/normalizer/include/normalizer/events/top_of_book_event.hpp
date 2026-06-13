#pragma once
#include <cstdint>


namespace normalizer::events {
    struct TopOfBookEvent {
        std::uint64_t sourceTimestamp{0};
        std::uint64_t bidShares{0};
        std::uint64_t askShares{0};
        std::uint32_t bidPrice{0};
        std::uint32_t askPrice{0};
        std::uint16_t stockLocate{0};
        bool bidValid{false};
        bool askValid{false};
    };
}