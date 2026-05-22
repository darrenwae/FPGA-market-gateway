#include "normalizer/itch/itch_file_reader.hpp"
#include "normalizer/util/endian.hpp"
#include <cassert>


namespace normalizer::itch {
    FileReader::FileReader(const std::filesystem::path& filePath) {
        file_.open(filePath, std::ios::binary);
    }

    bool FileReader::isOpen() const noexcept {
        return file_.is_open();
    }

    ReadStatus FileReader::readNextMessage(RawMessage& message) {
        assert(isOpen());
        message.length = 0;
        std::array<std::uint8_t,2> buffer{};
        file_.read(reinterpret_cast<char*>(buffer.data()), 2);
        auto count = file_.gcount();

        if (file_.bad()) { return ReadStatus::IoError; }
        if (count == 0) { return ReadStatus::EndOfFile; }
        if (count == 1) { return ReadStatus::TruncatedLength; }

        // framing length is big-endian
        const auto length = util::readBE16(buffer.data());
        if (length > RawMessage::MaxPayload) {
            message.length = 0;
            return ReadStatus::OversizedPayload;
        }

        file_.read(reinterpret_cast<char*>(message.payload.data()), length);
        count = file_.gcount();
        if (file_.bad()) { return ReadStatus::IoError; }
        if (count != static_cast<std::streamsize>(length)) {
            return ReadStatus::TruncatedPayload;
        }
        message.length = length;
        return ReadStatus::Ok;
    }
    
}