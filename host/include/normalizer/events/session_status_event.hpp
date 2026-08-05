#pragma once
#include <cstdint>
#include "normalizer/itch/messages.hpp"


namespace normalizer::events {
    struct SessionStatusEvent {
        std::uint64_t sourceTimestamp{0};
        itch::EventCode eventCode{};
    };
}