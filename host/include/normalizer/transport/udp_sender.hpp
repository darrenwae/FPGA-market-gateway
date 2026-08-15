#pragma once
#include <cstdint>
#include <cstddef>
#include <winsock2.h>


namespace normalizer::transport {
    class UdpSender {
        public:
        UdpSender(const char* localIpAddress, const char* destinationIpAddress, std::uint16_t destinationPort) noexcept;
        ~UdpSender() noexcept;

        UdpSender(const UdpSender&) = delete; //no copy construct
        UdpSender& operator=(const UdpSender&) = delete; // no copy assign

        [[nodiscard]] bool send(const std::uint8_t* data, std::size_t length) noexcept;
        [[nodiscard]] bool isOpen() const noexcept;

        private:
        SOCKET socket_ {INVALID_SOCKET};
    };
}
