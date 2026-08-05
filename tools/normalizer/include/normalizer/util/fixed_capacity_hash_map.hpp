#pragma once
#include <bit>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <type_traits>
#include <vector>

namespace normalizer::util {

    template <typename Key, typename Value, std::size_t MaximumEntries>
    class FixedCapacityHashMap {
        static_assert(std::is_integral_v<Key> && std::is_unsigned_v<Key>);
        static_assert(MaximumEntries > 0);
        static_assert(MaximumEntries < std::numeric_limits<std::uint32_t>::max());

      public:
        FixedCapacityHashMap() : buckets_(BucketCount, InvalidIndex), nodes_(MaximumEntries), freeHead_(0) {
            for (std::uint32_t index = 0; index < MaximumEntries - 1; ++index) {
                nodes_[index].nextIndex = index + 1;
            }
            nodes_.back().nextIndex = InvalidIndex;
        }

        [[nodiscard]] Value* find(Key key) noexcept {
            std::uint32_t index = buckets_[bucketFor(key)];
            while (index != InvalidIndex) {
                Node& node = nodes_[index];

                if (node.key == key) {
                    return &node.value;
                }
                index = node.nextIndex;
            }

            return nullptr;
        }

        [[nodiscard]] const Value* find(Key key) const noexcept {
            std::uint32_t index = buckets_[bucketFor(key)];

            while (index != InvalidIndex) {
                const Node& node = nodes_[index];

                if (node.key == key) {
                    return &node.value;
                }

                index = node.nextIndex;
            }

            return nullptr;
        }

        [[nodiscard]] bool contains(Key key) const noexcept {
            return find(key) != nullptr;
        }

        // Key must be absent and the map must not be full
        void insert(Key key, const Value& value) noexcept {
            const std::size_t bucket = bucketFor(key);
            const std::uint32_t newIndex = freeHead_;
            Node& newNode = nodes_[newIndex];

            freeHead_ = newNode.nextIndex;
            newNode.key = key;
            newNode.value = value;
            newNode.nextIndex = buckets_[bucket];
            buckets_[bucket] = newIndex;
            ++size_;
        }

        void erase(Key key) noexcept {
            const std::size_t bucket = bucketFor(key);
            std::uint32_t* link = &buckets_[bucket];

            while (*link != InvalidIndex) {
                const std::uint32_t index = *link;
                Node& node = nodes_[index];

                if (node.key == key) {
                    *link = node.nextIndex;
                    node.nextIndex = freeHead_;
                    freeHead_ = index;
                    --size_;
                    return;
                }

                link = &node.nextIndex;
            }
        }

        [[nodiscard]] std::size_t size() const noexcept {
            return size_;
        }

        [[nodiscard]] bool full() const noexcept {
            return size_ == MaximumEntries;
        }

      private:
        static constexpr std::uint32_t InvalidIndex = std::numeric_limits<std::uint32_t>::max();
        static constexpr std::size_t BucketCount = std::bit_ceil(MaximumEntries * 2);

        struct Node {
            Key key{};
            Value value{};
            std::uint32_t nextIndex{InvalidIndex};
        };

        [[nodiscard]] static std::uint64_t mix(std::uint64_t value) noexcept {
            value += 0x9E3779B97F4A7C15ULL;
            value = (value ^ (value >> 30)) * 0xBF58476D1CE4E5B9ULL;
            value = (value ^ (value >> 27)) * 0x94D049BB133111EBULL;
            return value ^ (value >> 31);
        }

        [[nodiscard]] static std::size_t bucketFor(Key key) noexcept {
            return static_cast<std::size_t>(mix(static_cast<std::uint64_t>(key))) & (BucketCount - 1);
        }

        std::vector<std::uint32_t> buckets_;
        std::vector<Node> nodes_;
        std::uint32_t freeHead_{InvalidIndex};
        std::size_t size_{0};
    };

} // namespace normalizer::util
