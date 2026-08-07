#include "normalizer/transport/udp_receiver.hpp"

#include <arpa/inet.h>
#include <cerrno>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

namespace normalizer::transport {
namespace {

	void closeSocket(int& socketFd) noexcept {
        if (socketFd >= 0) {
            ::close(socketFd);
			socketFd = -1;
		}
	}

}
    
    UdpReceiver::UdpReceiver(const char* localIpAddress,std::uint16_t localPort,const char* peerIpAddress,std::uint16_t peerPort) noexcept {
        socketFd_ = ::socket(AF_INET,SOCK_DGRAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);

        if (socketFd_ < 0) {
            return;
        }

        sockaddr_in localAddress{};
        localAddress.sin_family = AF_INET;
        localAddress.sin_port = htons(localPort);

        if (::inet_pton(AF_INET, localIpAddress, &localAddress.sin_addr) != 1) {
            closeSocket(socketFd_);
            return;
        }

        if (::bind(socketFd_, reinterpret_cast<const sockaddr*>(&localAddress), sizeof(localAddress)) != 0) {
            closeSocket(socketFd_);
            return;
        }

        sockaddr_in peerAddress{};
        peerAddress.sin_family = AF_INET;
        peerAddress.sin_port = htons(peerPort);

        if (::inet_pton(AF_INET, peerIpAddress, &peerAddress.sin_addr) != 1) {
            closeSocket(socketFd_);
            return;
        }

        if (::connect(socketFd_, reinterpret_cast<const sockaddr*>(&peerAddress), sizeof(peerAddress)) != 0) {
            closeSocket(socketFd_);
        }
    }

    UdpReceiver::~UdpReceiver() noexcept {
        closeSocket(socketFd_);
    }

    bool UdpReceiver::isOpen() const noexcept {
        return socketFd_ >= 0;
    }

    UdpReceiveResult UdpReceiver::receive(std::uint8_t* buffer, std::size_t capacity) noexcept {
        if (!isOpen() || buffer == nullptr || capacity == 0) {
            return {UdpReceiveStatus::SocketError, 0};
        }

        while (true) {
            const ssize_t receivedBytes = ::recv(socketFd_, buffer, capacity, MSG_TRUNC);

            if (receivedBytes >= 0) {
                const auto payloadLength = static_cast<std::size_t>(receivedBytes);

                if (payloadLength > capacity) {
                    return {UdpReceiveStatus::PacketTooLarge,payloadLength};
                }

                return {UdpReceiveStatus::PacketReceived,payloadLength};
            }

            if (errno == EINTR) {
                continue;
            }

            if (errno == EAGAIN) {
                return {UdpReceiveStatus::NoPacketAvailable, 0};
            }

            return {UdpReceiveStatus::SocketError, 0};
        }
    }

}