#include "normalizer/transport/udp_sender.hpp"
#include <cstdint>
#include <cstddef>
#include <immintrin.h>
#include <limits>
#include <ws2tcpip.h>

namespace normalizer::transport {
namespace {
    constexpr unsigned MaxTransientSendRetries{1'000'000};

    void closeSocket(SOCKET& socket) noexcept {
        if (socket != INVALID_SOCKET) {
            ::closesocket(socket);
            socket = INVALID_SOCKET;
        }
    }
    
}

    UdpSender::UdpSender(const char* localIpAddress, const char* destinationIpAddress, std::uint16_t destinationPort) noexcept {
        socket_ = ::socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if (socket_ == INVALID_SOCKET) {
            return;
        }

        u_long nonblocking{1};
        if (::ioctlsocket(socket_,static_cast<long>(FIONBIO),&nonblocking) == SOCKET_ERROR) {
            closeSocket(socket_);
            return;
        }

        sockaddr_in hostAddr {};
        hostAddr.sin_family = AF_INET;
        hostAddr.sin_port = 0;

        if (::inet_pton(AF_INET,localIpAddress,&hostAddr.sin_addr) != 1) {
            closeSocket(socket_);
            return;
        }

        if (::bind(socket_,reinterpret_cast<const sockaddr*>(&hostAddr),static_cast<int>(sizeof(hostAddr))) == SOCKET_ERROR) {
            closeSocket(socket_);
            return;
        }

        sockaddr_in destAddr{};
        destAddr.sin_family = AF_INET;
        destAddr.sin_port = ::htons(destinationPort);

        if (::inet_pton(AF_INET,destinationIpAddress,&destAddr.sin_addr) != 1) {
            closeSocket(socket_);
            return;
        }

        if (::connect(socket_,reinterpret_cast<const sockaddr*>(&destAddr),static_cast<int>(sizeof(destAddr))) == SOCKET_ERROR) {
            closeSocket(socket_);
        }
    }


    UdpSender::~UdpSender() noexcept {
        closeSocket(socket_);
    }

    bool UdpSender::isOpen() const noexcept {
        return socket_ != INVALID_SOCKET;
    }

    bool UdpSender::send(const std::uint8_t* data, std::size_t length) noexcept {
        if (!isOpen() || data == nullptr || length == 0 || length > static_cast<std::size_t>(std::numeric_limits<int>::max())) {
            return false;
        }

        unsigned transientSendRetries{0};

        while(true) {
            const int bytesSent = ::send(socket_, reinterpret_cast<const char*>(data), static_cast<int>(length), 0);

            if (bytesSent != SOCKET_ERROR) {
                return static_cast<std::size_t>(bytesSent) == length;
            }

            const int sendError = ::WSAGetLastError();
            if (sendError == WSAEINTR) {
                continue;
            }

            if ((sendError == WSAEWOULDBLOCK || sendError == WSAENOBUFS) && transientSendRetries < MaxTransientSendRetries) {
                ++transientSendRetries;
                _mm_pause();
                continue;
            }

            return false;

        }
    }

}