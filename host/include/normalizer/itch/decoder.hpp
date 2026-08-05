#pragma once
#include <variant>
#include <cstdint>
#include <array>
#include "normalizer/itch/raw_message.hpp"
#include "normalizer/itch/messages.hpp"


namespace normalizer::itch {
    enum class DecodeStatus {
        Ok,
        EmptyMessage,
        LengthMismatch,
        UnsupportedMessageType,
        InvalidFieldValue
    };

    [[nodiscard]] DecodeStatus decodeMessage(const RawMessage& message, DecodedMessage& output);

}