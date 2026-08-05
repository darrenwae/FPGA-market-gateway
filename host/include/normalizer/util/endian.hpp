#pragma once
#include <cstdint>


namespace normalizer::util {
    inline std::uint16_t readBE16(const std::uint8_t* p) noexcept {
        return (static_cast<std::uint16_t>(p[0] << 8) | static_cast<std::uint16_t> (p[1]));
    }

    inline std::uint32_t readBE32(const std::uint8_t* p) noexcept {
        return (static_cast<std::uint32_t>(p[0]) << 24) | 
                (static_cast<std::uint32_t>(p[1]) << 16) |
                (static_cast<std::uint32_t>(p[2]) <<  8) |
                static_cast<std::uint32_t>(p[3]);
    }

    inline std::uint64_t readBE48(const std::uint8_t* p) noexcept {
        return (static_cast<std::uint64_t>(p[0]) << 40) | 
                (static_cast<std::uint64_t>(p[1]) << 32) |
                (static_cast<std::uint64_t>(p[2]) << 24) |
                (static_cast<std::uint64_t>(p[3]) << 16) |
                (static_cast<std::uint64_t>(p[4]) <<  8) |
                static_cast<std::uint64_t>(p[5]);
    }

    inline std::uint64_t readBE64(const std::uint8_t* p) noexcept {
        return (static_cast<std::uint64_t>(p[0]) << 56) | 
                (static_cast<std::uint64_t>(p[1]) << 48) | 
                (static_cast<std::uint64_t>(p[2]) << 40) |
                (static_cast<std::uint64_t>(p[3]) << 32) |
                (static_cast<std::uint64_t>(p[4]) << 24) |
                (static_cast<std::uint64_t>(p[5]) << 16) |
                (static_cast<std::uint64_t>(p[6]) <<  8) |
                static_cast<std::uint64_t>(p[7]);
    }

    inline void writeBE16(std::uint8_t* p, std::uint16_t value) noexcept {
        p[0] = static_cast<std::uint8_t>(value >> 8);
        p[1] = static_cast<std::uint8_t>(value);
    }

    inline void writeBE32(std::uint8_t* p, std::uint32_t value) noexcept {
        p[0] = static_cast<std::uint8_t>(value >> 24);
        p[1] = static_cast<std::uint8_t>(value >> 16);
        p[2] = static_cast<std::uint8_t>(value >>  8);
        p[3] = static_cast<std::uint8_t>(value);
    }

    inline void writeBE48(std::uint8_t* p, std::uint64_t value) noexcept {
        p[0] = static_cast<std::uint8_t>(value >> 40);
        p[1] = static_cast<std::uint8_t>(value >> 32); 
        p[2] = static_cast<std::uint8_t>(value >> 24);
        p[3] = static_cast<std::uint8_t>(value >> 16);
        p[4] = static_cast<std::uint8_t>(value >>  8);
        p[5] = static_cast<std::uint8_t>(value);
    }

    inline void writeBE64(std::uint8_t* p, std::uint64_t value) noexcept {
        p[0] = static_cast<std::uint8_t>(value >> 56);
        p[1] = static_cast<std::uint8_t>(value >> 48);
        p[2] = static_cast<std::uint8_t>(value >> 40);
        p[3] = static_cast<std::uint8_t>(value >> 32);
        p[4] = static_cast<std::uint8_t>(value >> 24);
        p[5] = static_cast<std::uint8_t>(value >> 16);
        p[6] = static_cast<std::uint8_t>(value >>  8);
        p[7] = static_cast<std::uint8_t>(value);
    }


}