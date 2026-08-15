#include "normalizer/transport/udp_receiver.hpp"
#include <ws2tcpip.h>

namespace normalizer::transport {
namespace {

	void closeSocket(SOCKET& socket) noexcept {
        if (socket != INVALID_SOCKET) {
            ::closesocket(socket);
            socket = INVALID_SOCKET;
        }
	}

}
    
    UdpReceiver::UdpReceiver(const char* localIpAddress,std::uint16_t localPort,const char* peerIpAddress,std::uint16_t peerPort) noexcept {
        socket_ = ::socket(AF_INET,SOCK_DGRAM, IPPROTO_UDP);

        if (socket_ == INVALID_SOCKET) {
            return;
        }

        u_long nonblocking{1};
        if (::ioctlsocket(socket_,static_cast<long>(FIONBIO),&nonblocking) == SOCKET_ERROR) {
            closeSocket(socket_);
            return;
        }

        sockaddr_in localAddress{};
        localAddress.sin_family = AF_INET;
        localAddress.sin_port = ::htons(localPort);

        if (::inet_pton(AF_INET,localIpAddress,&localAddress.sin_addr) != 1) {
            closeSocket(socket_);
            return;
        }

        if (::bind(socket_, reinterpret_cast<const sockaddr*>(&localAddress), static_cast<int>(sizeof(localAddress))) == SOCKET_ERROR) {
            closeSocket(socket_);
            return;
        }

        sockaddr_in peerAddress{};
        peerAddress.sin_family = AF_INET;
        peerAddress.sin_port = ::htons(peerPort);

        if (::inet_pton(AF_INET,peerIpAddress,&peerAddress.sin_addr) != 1) {
            closeSocket(socket_);
            return;
        }

        if (::connect(socket_,reinterpret_cast<const sockaddr*>(&peerAddress),static_cast<int>(sizeof(peerAddress))) == SOCKET_ERROR) {
            closeSocket(socket_);
        }
    }

    UdpReceiver::~UdpReceiver() noexcept {
        closeSocket(socket_);
    }

    bool UdpReceiver::isOpen() const noexcept {
        return socket_ != INVALID_SOCKET;
    }

    UdpReceiveResult UdpReceiver::receive(std::uint8_t* buffer, std::size_t capacity) noexcept {
        if (!isOpen() || buffer == nullptr || capacity == 0) {
            return {UdpReceiveStatus::SocketError, 0};
        }

        while (true) {
            const int receivedBytes = ::recv(socket_,reinterpret_cast<char*>(buffer),static_cast<int>(capacity),0);

            if (receivedBytes != SOCKET_ERROR) {
                return {UdpReceiveStatus::PacketReceived,static_cast<std::size_t>(receivedBytes)};
            }

            const int receiveError = ::WSAGetLastError();
            if (receiveError == WSAEINTR) {
                continue;
            }
            
            if (receiveError == WSAEWOULDBLOCK) {
                return {UdpReceiveStatus::NoPacketAvailable, 0};
            }

            if (receiveError == WSAEMSGSIZE) {
                return {UdpReceiveStatus::PacketTooLarge, 0};
            }

            return {UdpReceiveStatus::SocketError, 0};
        }
    }

}