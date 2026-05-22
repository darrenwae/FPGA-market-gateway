#pragma once
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <array>

namespace normalizer::itch {
    struct RawMessage {
        static constexpr std::size_t MaxPayload = 64;
        std::array<std::uint8_t, MaxPayload> payload{};
        std::uint16_t length{0};
    };

    enum class ReadStatus {
        Ok, 
        EndOfFile, 
        TruncatedLength, 
        TruncatedPayload,
        OversizedPayload,
        IoError
    };

    class FileReader {
        public:
        explicit FileReader(const std::filesystem::path& filePath);
        [[nodiscard]] bool isOpen() const noexcept;
        // precondition: isOpen() == true
        [[nodiscard]] ReadStatus readNextMessage(RawMessage& message);

        private:
        std::ifstream file_;
    };
}



