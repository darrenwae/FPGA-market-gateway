#pragma once
#include <cstdint>
#include <cstddef>
#include <winsock2.h>


namespace normalizer::transport {

	enum class UdpReceiveStatus : std::uint8_t {
		PacketReceived,
		NoPacketAvailable,
		PacketTooLarge,
		SocketError
	};

	struct UdpReceiveResult {
		UdpReceiveStatus status{UdpReceiveStatus::SocketError};
		std::size_t payloadLength{0};
	};

	class UdpReceiver {
	public:
		UdpReceiver(const char* localIpAddress, std::uint16_t localPort, const char* peerIpAddress, std::uint16_t peerPort) noexcept;
		~UdpReceiver() noexcept;

		UdpReceiver(const UdpReceiver&) = delete;
		UdpReceiver& operator=(const UdpReceiver&) = delete;

		[[nodiscard]] UdpReceiveResult receive(std::uint8_t* buffer,std::size_t capacity) noexcept;
		[[nodiscard]] bool isOpen() const noexcept;

	private:
		SOCKET socket_{INVALID_SOCKET};
	};

}