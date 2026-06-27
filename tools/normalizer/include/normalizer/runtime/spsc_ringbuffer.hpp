#pragma once
#include <cstddef>
#include <cstdint>
#include <array>
#include <atomic>
#include <utility>


namespace normalizer::runtime {
    template <typename T, std::size_t Capacity>
    class SpscRingBuffer {
        static constexpr std::size_t Mask = Capacity - 1;
        static_assert (Capacity >= 2, "capacity must be >= 2");
        static_assert((Capacity & Mask) == 0, "capacity must be a power of 2");
        static_assert(std::is_nothrow_copy_assignable_v<T>);
        static_assert(std::is_nothrow_move_assignable_v<T>);
        
        public:
        [[nodiscard]] bool tryPush(const T& item) noexcept {
            const std::size_t currentWrite = writeIndex_.load(std::memory_order_relaxed);
            if ((currentWrite - cachedReadIndex_) >= Capacity) {
                cachedReadIndex_ = readIndex_.load(std::memory_order_acquire);
                if ((currentWrite - cachedReadIndex_) >= Capacity) {
                    return false;
                }
            }
            ringBuffer_[currentWrite & Mask] = item;
            writeIndex_.store(currentWrite + 1, std::memory_order_release);
            return true;
        }

        [[nodiscard]] bool tryPush(T&& item) noexcept {
            const std::size_t currentWrite = writeIndex_.load(std::memory_order_relaxed);
            if ((currentWrite - cachedReadIndex_) >= Capacity) {
                cachedReadIndex_ = readIndex_.load(std::memory_order_acquire);
                if ((currentWrite - cachedReadIndex_) >= Capacity) {
                    return false;
                }
            }
            ringBuffer_[currentWrite & Mask] = std::move(item);
            writeIndex_.store(currentWrite + 1, std::memory_order_release);
            return true;
        }

        [[nodiscard]] bool tryPop(T& item) noexcept {
            const std::size_t currentRead = readIndex_.load(std::memory_order_relaxed);
            if (currentRead == cachedWriteIndex_) {
                cachedWriteIndex_ = writeIndex_.load(std::memory_order_acquire);
                if (currentRead == cachedWriteIndex_) {
                    return false;
                }
            }
            item = std::move(ringBuffer_[currentRead & Mask]);
            readIndex_.store(currentRead + 1, std::memory_order_release);
            return true;
        }

        [[nodiscard]] bool empty() const noexcept {
            const auto read = readIndex_.load(std::memory_order_relaxed);
            const auto write = writeIndex_.load(std::memory_order_relaxed);
            return read == write;
        }

        [[nodiscard]] bool full() const noexcept {
            const auto read = readIndex_.load(std::memory_order_relaxed);
            const auto write = writeIndex_.load(std::memory_order_relaxed);
            return (write - read) >= Capacity;
        }

        [[nodiscard]] std::size_t size() const noexcept {
            const auto read = readIndex_.load(std::memory_order_relaxed);
            const auto write = writeIndex_.load(std::memory_order_relaxed);
            return write - read;
        }

        private:
        std::array<T, Capacity> ringBuffer_ {};
        alignas(64) std::atomic<std::size_t> writeIndex_ {0};
        std::size_t cachedReadIndex_{0};
        
        alignas(64) std::atomic<std::size_t> readIndex_ {0};
        std::size_t cachedWriteIndex_{0};
    };

}