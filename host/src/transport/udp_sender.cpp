#include "normalizer/transport/udp_sender.hpp"
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
#include <cstdint>
#include <cstddef>
#include <cerrno>
#include <immintrin.h>

namespace normalizer::transport {
namespace {
    void closeSocket(int& socketFd) noexcept {
        if (socketFd >= 0) {
            ::close(socketFd);
            socketFd = -1;
        }
    }

    constexpr unsigned MaxTransientSendRetries{1'000'000};
}

    UdpSender::UdpSender(const char* destIP, std::uint16_t destPort) noexcept {
        socketFd_ = ::socket(AF_INET,SOCK_DGRAM | SOCK_NONBLOCK | SOCK_CLOEXEC,0);
        if (socketFd_ < 0) {
            return;
        }

        sockaddr_in destAddr {};
        destAddr.sin_family = AF_INET;
        destAddr.sin_port = htons(destPort);

        const int parseResult = ::inet_pton(AF_INET, destIP, &destAddr.sin_addr);
        if (parseResult != 1) {
            closeSocket(socketFd_);
            return;
        }

        const int connectResult = ::connect(socketFd_, reinterpret_cast<const sockaddr*>(&destAddr), static_cast<socklen_t>(sizeof(destAddr)));
        if (connectResult != 0) {
            closeSocket(socketFd_);
            return;
        } 

    }

    UdpSender::~UdpSender() noexcept {
        closeSocket(socketFd_);
    }

    bool UdpSender::isOpen() const noexcept {
        return socketFd_ >= 0;
    }

    bool UdpSender::send(const std::uint8_t* data, std::size_t length) noexcept {
        if (!isOpen() || data == nullptr || length == 0) {
            return false;
        }

        unsigned transientSendRetries{0};

        while(true) {
            const ssize_t bytesSent = ::send(socketFd_, data, length, 0);

            if (bytesSent < 0) {
                const int sendError{errno};

                if (sendError == EINTR) {
                    continue;
                }

                if ((sendError == EAGAIN || sendError == ENOBUFS) && transientSendRetries < MaxTransientSendRetries) {
                    ++transientSendRetries;
                    _mm_pause();
                    continue;
                }
                return false;
            }

            return static_cast<std::size_t>(bytesSent) == length;

        }
    }

}