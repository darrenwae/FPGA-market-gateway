#pragma once
#include <cstdint>
#include <cstddef>


namespace normalizer::transport {
    class UdpSender {
        public:
        UdpSender(const char* destIP, std::uint16_t destPort) noexcept;
        ~UdpSender() noexcept;

        UdpSender(const UdpSender&) = delete; //no copy construct
        UdpSender& operator=(const UdpSender&) = delete; // no copy assign

        [[nodiscard]] bool send(const std::uint8_t* data, std::size_t length) noexcept;
        [[nodiscard]] bool isOpen() const noexcept;
        private:
        int socketFd_ {-1};
    };
}