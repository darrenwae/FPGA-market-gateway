#pragma once
#include <cstdint>
#include <cstddef>
#include <array>



struct RawMessage {
        static constexpr std::size_t MaxPayload = 64;
        std::array<std::uint8_t, MaxPayload> payload{};
        std::uint16_t length{0};
    };