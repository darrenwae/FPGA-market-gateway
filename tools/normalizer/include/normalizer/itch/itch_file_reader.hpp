#pragma once
#include "normalizer/itch/raw_message.hpp"
#include <filesystem>
#include <fstream>


namespace normalizer::itch {
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



