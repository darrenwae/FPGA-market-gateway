# Internal Protocol v0
This document defines the fixed-width internal protocol used between the host PC and the FPGA market-gateway slice.
In v0, the host PC runs a replay and normalization program. It reads historical NASDAQ ITCH data, parses the raw ITCH order-level messages, and maintains enough software book state to derive the current top-of-book for each enabled instrument. The FPGA does not receive raw ITCH messages and does not reconstruct the full order book in v0.

The host sends normalized fixed-format messages to the FPGA over Ethernet using IPv4/UDP. Each UDP payload contains one or more 32-byte internal protocol messages.

The FPGA parses Ethernet/IP/UDP enough to extract the UDP payload, decodes the internal protocol messages, maintains the latest top-of-book state, performs pre-trade risk checks on order intents, and returns accept/reject decisions.

## Design Summary
- Message size: 32 bytes fixed length.
- Endianness: big-endian for all multi-byte integer fields.
- Field offsets: fixed by byte position.
- Price representation: unsigned integer `Price(4)` format, with 4 implied decimal places.
- Quantity representation: unsigned integer share quantity.
- Downstream direction: host to FPGA.
- Upstream direction: FPGA to host.
- Downstream sequence numbers increment globally across all host-to-FPGA message types.
- The FPGA uses fail-closed behavior for order intents. It rejects an order intent unless the required symbol state, market state, top-of-book state, and risk-limit configuration are valid.

## Common 32-Byte Message Layout
All protocol messages use the same 32-byte container.
```text
[[message_type][flags][reserved][sequence_number][symbol_id][timestamp][payload_0][payload_1][payload_2][payload_3]]
```

| Byte | Field | Size| Description |
|:--|---|---|---|
| 0 | `message_type` | 1 byte | Selects message interpretation. |
| 1 | `flags` | 1 byte | Message-type-specific bitmap. Set to 0 when unused. |
| 2-3 | `reserved` | 2 bytes | Reserved for alignment and future use. Set to 0 in v0. |
| 4-7 | `sequence_number` | 4 bytes | Stream sequence number. Meaning depends on direction. |
| 8-9 | `symbol_id` | 2 bytes | Instrument identifier. In v0, this follows NASDAQ `stock_locate` where applicable. |
| 10-15 | `timestamp` | 6 bytes | Message timestamp for downstream messages. Reserved and set to 0 for upstream `ORDER_DECISION`. |
| 16-19 | `payload_0` | 4 bytes | Message-specific payload word. |
| 20-23 | `payload_1` | 4 bytes | Message-specific payload word. |
| 24-27 | `payload_2` | 4 bytes | Message-specific payload word. |
| 28-31 | `payload_3` | 4 bytes | Message-specific payload word. |

Reserved bytes and reserved bits shall be set to 0 by the sender. In v0, the receiver treats nonzero reserved fields as a protocol error unless the specific message type defines otherwise.

## Message Type Enum

### Downstream: PC to FPGA

| Value | Name | Description |
|---|---|---|
| `0x01` | `SESSION_STATUS` | Global session/system status update derived from ITCH System Event messages. |
| `0x02` | `TOB_UPDATE` | Full top-of-book update for one symbol. |
| `0x03` | `SYMBOL_STATUS` | Per-symbol trading status update derived from ITCH Stock Trading Action messages. |
| `0x04` | `ORDER_INTENT` | Proposed order to be checked by the FPGA risk gate. |
| `0x05` | `CONFIG_CONTROL` | Configuration/control command for FPGA state and risk limits. |

### Upstream: FPGA to PC

| Value | Name | Description |
|---:|---|---|
| `0x81` | `ORDER_DECISION` | FPGA accept/reject response to a decoded `ORDER_INTENT`. |

Values not listed above are reserved.

## UDP Payload Framing
Each UDP payload contains one or more consecutive 32-byte protocol messages.

```text
UDP payload:
[[message_0][message_1][message_2] ... [message_N-1]]
```

Rules:
- Since each internal message is exactly 32 bytes, the UDP payload length shall be a positive multiple of 32.
- For standard Ethernet MTU 1500 using IPv4 and UDP, maximum UDP payload is `1500 - 20(IP header) - 8(UDP header) = 1472` bytes.
- Therefore, the maximum number of internal messages per UDP payload is `1472 / 32 = 46`.
- Messages are parsed in payload order.
- There is no additional internal packet header in v0.

## Downstream Message: SESSION_STATUS
```text
SESSION_STATUS message format:
[[message_type][flags][reserved][sequence_number][symbol_id][timestamp][session_state][payload_1][payload_2][payload_3]]
```

Total size: 32 bytes.

| Field | Value / Meaning |
|---|---|
| `message_type` | `0x01 = SESSION_STATUS` |
| `flags` | Unused. Shall be 0. |
| `reserved` | Shall be 0. |
| `sequence_number` | Monotonically increasing downstream stream sequence number assigned by the host. |
| `symbol_id` | Not symbol-specific. Shall be 0. |
| `timestamp` | Source timestamp copied from the ITCH System Event message, in nanoseconds since midnight. |
| `session_state` |Normalized session status enum. |
| `payload_1` | Unused. Shall be 0. |
| `payload_2` | Unused. Shall be 0. |
| `payload_3` | Unused. Shall be 0. |

`session_state` encodings:

| Value | Meaning | ITCH event code |
|:-:|---|:-|
| `0x00000000` | `INVALID` | N/A |
| `0x00000001` | `START_OF_MESSAGES` | `O` |
| `0x00000002` | `START_OF_SYSTEM_HOURS` | `S` |
| `0x00000003` | `START_OF_MARKET_HOURS` | `Q` |
| `0x00000004` | `END_OF_MARKET_HOURS` | `M` |
| `0x00000005` | `END_OF_SYSTEM_HOURS` | `E` |
| `0x00000006` | `END_OF_MESSAGES` | `C` |
| `0x00000007-0xFFFFFFFF` | Reserved | N/A |

## Downstream Message: TOB_UPDATE
```text
TOB_UPDATE message format:
[[message_type][flags][reserved][sequence_number][symbol_id][timestamp][bid_price][bid_qty][ask_price][ask_qty]]
```

Total size: 32 bytes.

| Field | Value / Meaning |
|---|---|
| `message_type` | `0x02 = TOB_UPDATE` |
| `flags` | Validity bitmap for the top-of-book snapshot. |
| `reserved` | Shall be 0. |
| `sequence_number` | Monotonically increasing downstream stream sequence number assigned by the host. |
| `symbol_id` | Instrument identifier for the current replay session. In v0, this follows NASDAQ `stock_locate`. |
| `timestamp` | Source event timestamp copied from the ITCH-derived event that caused this internal update, in nanoseconds since midnight. |
|`bid_price` | Current best bid price in `Price(4)` format. If `bid_valid = 0`, this field shall be 0. |
| `bid_qty` | Aggregate visible quantity available at the current best bid price. If `bid_valid = 0`, this field shall be 0. |
| `ask_price` | Current best ask price in `Price(4)` format. If `ask_valid = 0`, this field shall be 0. |
| `ask_qty` | Aggregate visible quantity available at the current best ask price. If `ask_valid = 0`, this field shall be 0. |

`flags` bit layout:

| Bit | Name | Meaning |
|:-:|---|---|
| 0 | `bid_valid` | `1`: `bid_price` and `bid_qty` contain a valid current best bid. `0`: no current bid exists; `bid_price` and `bid_qty` shall be 0. |
| 1 | `ask_valid` | `1`: `ask_price` and `ask_qty` contain a valid current best ask. `0`: no current ask exists; `ask_price` and `ask_qty` shall be 0. |
| 2-7 | Reserved | Shall be 0. |

Note: `TOB_UPDATE` carries a full top-of-book snapshot for the symbol. The FPGA does not decide whether the bid/ask is best. That decision is performed by the host-side software before this message is transmitted.

## Downstream Message: SYMBOL_STATUS
```text
SYMBOL_STATUS message format:
[[message_type][flags][reserved][sequence_number][symbol_id][timestamp][symbol_status][payload_1][payload_2][payload_3]]
```

Total size: 32 bytes.

| Field | Value / Meaning |
|:--|---|
| `message_type` | `0x03 = SYMBOL_STATUS` |
| `flags` | Unused. Shall be 0. |
| `reserved` | Shall be 0. |
| `sequence_number` | Monotonically increasing downstream stream sequence number assigned by the host. |
| `symbol_id` | Instrument identifier for the affected instrument. In v0, this follows NASDAQ `stock_locate`. |
| `timestamp` | Source event timestamp copied from the ITCH Stock Trading Action message, in nanoseconds since midnight. |
| `symbol_status` | Normalized instrument trading status enum. |
| `payload_1` | Unused. Shall be 0. |
| `payload_2` | Unused. Shall be 0. |
| `payload_3` | Unused. Shall be 0. |

`symbol_status` encodings:

| Value | Meaning | ITCH trading state |
|:-:|---|---|
| `0x00000000` | `INVALID` | N/A |
| `0x00000001` | `HALTED` | `H` |
| `0x00000002` | `PAUSED` | `P` |
| `0x00000003` | `QUOTATION_ONLY` | `Q` |
| `0x00000004` | `TRADING` | `T` |
| `0x00000005-0xFFFFFFFF` | Reserved | N/A |

Note: In v0, only `TRADING` is treated as tradable by the risk checker. `HALTED`, `PAUSED`, `QUOTATION_ONLY`, and `INVALID` causes a `ORDER_INTENT` rejection.

## Downstream Message: ORDER_INTENT
```text
ORDER_INTENT message format:
[[message_type][flags][reserved][sequence_number][symbol_id][timestamp][order_side][order_price][order_qty][intent_id]]
```

Total size: 32 bytes.

| Field | Value / Meaning |
|---|---|
| `message_type` | `0x04 = ORDER_INTENT` |
| `flags` | Unused in v0. Shall be 0. |
| `reserved` | Shall be 0. |
| `sequence_number` | Monotonically increasing downstream stream sequence number assigned by the host. |
| `symbol_id` | Instrument identifier for the order intent. In v0, this follows NASDAQ `stock_locate`. |
| `timestamp` | Source event timestamp, in nanoseconds since midnight. |
| `order_side` | BUY/SELL side of the order intent. |
| `order_price` | Proposed order price in `Price(4)` format. |
| `order_qty` | Proposed order quantity. |
| `intent_id` | Host-assigned logical order-intent identifier. Used to correlate the FPGA decision with the original order intent. |

`order_side` encodings:

| Value | Meaning |
|:-:|---|
| `0x00000000` | `UNKNOWN_INVALID` |
| `0x00000001` | `BUY` |
| `0x00000002` | `SELL` |
| `0x00000003-0xFFFFFFFF` | Reserved |

The FPGA emits one `ORDER_DECISION` only for messages it can classify as `ORDER_INTENT`. Any unknown `message_type` values are parser/protocol errors and do not generate `ORDER_DECISION` messages.

## Downstream Message: CONFIG_CONTROL
```text
CONFIG_CONTROL message format:
[[message_type][flags][reserved][sequence_number][symbol_id][timestamp][config_opcode][config_value_0][config_value_1][config_id]]
```

Total size: 32 bytes.

| Field | Value / Meaning |
|---|---|
| `message_type` | `0x05 = CONFIG_CONTROL` |
| `flags` | Unused in v0. Shall be 0. |
| `reserved` | Shall be 0. |
| `sequence_number` | Monotonically increasing downstream stream sequence number assigned by the PC. |
| `symbol_id` | Instrument affected by this command. `0` means global command; nonzero means instrument-specific command. |
| `timestamp` | Replay timestamp, in nanoseconds since midnight. |
| `config_opcode` | Config/control command enum. |
| `config_value_0` | First command argument. Meaning depends on `config_opcode`. |
| `config_value_1` | Second command argument. Meaning depends on `config_opcode`. Shall be 0 if unused. |
| `config_id` | Host-assigned config command identifier, for correlation with any future config ACK/error/status output. |

`config_opcode` encodings:

| Value | Name |
|:-:|---|
| `0x00000000` | `NOP` |
| `0x00000001` | `RESET_ALL` |
| `0x00000002` | `RESET_SYMBOL` |
| `0x00000003` | `SET_SYMBOL_ENABLED` |
| `0x00000004` | `SET_MAX_ORDER_QTY` |
| `0x00000005` | `SET_MAX_NOTIONAL` |
| `0x00000006` | `SET_PRICE_BAND_TICKS` |
| `0x00000007` | `CLEAR_COUNTERS` |
| `0x00000008-0xFFFFFFFF` | Reserved |

### CONFIG_CONTROL Opcode Arguments

#### `0x00000000 = NOP`

| Field | Required value |
|---|---|
| `symbol_id` | 0 |
| `config_value_0` | 0 |
| `config_value_1` | 0 |

Effect: no state change. The FPGA shall ignore this message.

#### `0x00000001 = RESET_ALL`

| Field | Required value |
|---|---|
| `symbol_id` | 0 |
| `config_value_0` | `reset_mask` |
| `config_value_1` | 0 |

`reset_mask`:

| Value / bit | Meaning |
|---|---|
| `0x00000000` | Full reset. |
| bit 0 | Reset top-of-book state for all symbols. |
| bit 1 | Reset all symbol status state. |
| bit 2 | Reset all symbol enable state. |
| bit 3 | Reset risk limits. |
| bit 4 | Reset counters. |
| bits 5-31 | Reserved. |

Effect: resets global FPGA state according to `reset_mask`. A full reset returns to fail-closed defaults.

#### `0x00000002 = RESET_SYMBOL`

| Field | Required value |
|---|---|
| `symbol_id` | Target symbol ID. |
| `config_value_0` | `reset_mask` |
| `config_value_1` | 0 |

`reset_mask`:

| Value / bit | Meaning |
|---|---|
| `0x00000000` | Full reset for this symbol. |
| bit 0 | Reset top-of-book state for this symbol. |
| bit 1 | Reset symbol status for this symbol. |
| bit 2 | Reset symbol enable state for this symbol. |
| bit 3 | Reset risk limits for this symbol. |
| bit 4 | Reset counters for this symbol. |
| bits 5-31 | Reserved. |

Effect: resets only the selected symbol's FPGA state according to `reset_mask`.

#### `0x00000003 = SET_SYMBOL_ENABLED`

| Field | Required value |
|---|---|
| `symbol_id` | Target symbol ID. |
| `config_value_0` | `0x00000000 = disabled`, `0x00000001 = enabled` |
| `config_value_1` | 0 |

Effect: sets whether the FPGA is allowed to accept order intents for this symbol. If disabled, `ORDER_INTENT` for this symbol shall be rejected even if market status is `TRADING`.

#### `0x00000004 = SET_MAX_ORDER_QTY`

| Field | Required value |
|---|---|
| `symbol_id` | Target symbol ID. |
| `config_value_0` | Maximum allowed order quantity. |
| `config_value_1` | 0 |

Effect: FPGA rejects an `ORDER_INTENT` if `order_qty > max_order_qty`.

#### `0x00000005 = SET_MAX_NOTIONAL`

| Field | Required value |
|---|---|
| `symbol_id` | Target symbol ID. |
| `config_value_0` | `max_notional[63:32]` |
| `config_value_1` | `max_notional[31:0]` |

Effect: sets maximum allowed order notional for this symbol.
```text
max_notional = (config_value_0 << 32) | config_value_1
order_notional = order_price * order_qty
```
FPGA rejects an `ORDER_INTENT` if `order_notional > max_notional`.

#### `0x00000006 = SET_PRICE_BAND_TICKS`

| Field | Required value |
|---|---|
| `symbol_id` | Target symbol ID. |
| `config_value_0` | Maximum allowed price distance from top-of-book reference, in `Price(4)` ticks. |
| `config_value_1` | 0 |

For a BUY order intent:
```text
reference = current ask_price
reject if ask_valid = 0
reject if order_price > ask_price + max_price_band_ticks
```

For a SELL order intent:
```text
reference = current bid_price
reject if bid_valid = 0
reject if order_price < bid_price - max_price_band_ticks
```

#### `0x00000007 = CLEAR_COUNTERS`

| Field | Required value |
|---|---|
| `symbol_id` | 0 for global counters; target symbol ID for symbol-specific counters, if implemented. |
| `config_value_0` | `counter_mask` |
| `config_value_1` | 0 |

`counter_mask`:

| Value / bit | Meaning |
|---|---|
| `0x00000000` | Clear all counters. |
| bit 0 | Clear decision counters. |
| bit 1 | Clear parser/error counters. |
| bits 2-31 | Reserved. |

Effect: clears selected FPGA debug counters. Does not modify top-of-book state, symbol status, symbol enable state, or risk limits.

## Upstream Message: ORDER_DECISION
```text
ORDER_DECISION message format:
[[message_type][flags][reserved][sequence_number][symbol_id][reserved_0][decision][reject_reason][reserved_1][intent_id]]
```

Total size: 32 bytes.

| Field | Value / Meaning |
|---|---|
| `message_type` | `0x81 = ORDER_DECISION` |
| `flags` | Unused in v0. Shall be 0. |
| `reserved` | Shall be 0. |
| `sequence_number` | Echoes the `sequence_number` of the `ORDER_INTENT` message being answered. |
| `symbol_id` | Echoes the `symbol_id` from the `ORDER_INTENT` message. |
| `reserved_0` | Shall be 0. |
| `decision` | FPGA decision enum. |
| `reject_reason` | Rejection reason enum. |
| `reserved_1` | Shall be 0. |
| `intent_id` | Echoes the `intent_id` from the `ORDER_INTENT` message. |

`decision` encodings:
| Value | Meaning |
|:-:|---|
| `0x00000000` | `UNKNOWN_INVALID` |
| `0x00000001` | `ACCEPT` |
| `0x00000002` | `REJECT` |
| `0x00000003-0xFFFFFFFF` | Reserved |

`reject_reason` encodings:

| Value | Meaning |
|:-:|---|
| `0x00000000` | `NONE` |
| `0x00000001` | `STREAM_FAULT` |
| `0x00000002` | `ORDER_INTENT_PROTOCOL_VIOLATION` |
| `0x00000003` | `UNKNOWN_SYMBOL` |
| `0x00000004` | `SYMBOL_DISABLED` |
| `0x00000005` | `SYMBOL_NOT_TRADING` |
| `0x00000006` | `REQUIRED_TOB_SIDE_INVALID` |
| `0x00000007` | `INVALID_ORDER_SIDE` |
| `0x00000008` | `ZERO_ORDER_QTY` |
| `0x00000009` | `MAX_ORDER_QTY_EXCEEDED` |
| `0x0000000A` | `ZERO_ORDER_PRICE` |
| `0x0000000B` | `PRICE_BAND_VIOLATION` |
| `0x0000000C` | `MAX_NOTIONAL_EXCEEDED` |
| `0x0000000D-0xFFFFFFFF` | Reserved |

Rules:

- If `decision = ACCEPT`, then `reject_reason` shall be `NONE`.
- If `decision = REJECT`, then `reject_reason` shall be one of the nonzero reject codes.


Reject reason priority:

1. `STREAM_FAULT`
2. `ORDER_INTENT_PROTOCOL_VIOLATION`
3. `UNKNOWN_SYMBOL`
4. `SYMBOL_DISABLED`
5. `SYMBOL_NOT_TRADING`
6. `INVALID_ORDER_SIDE`
7. `ZERO_ORDER_QTY`
8. `ZERO_ORDER_PRICE`
9. `REQUIRED_TOB_SIDE_INVALID`
10. `MAX_ORDER_QTY_EXCEEDED`
11. `PRICE_BAND_VIOLATION`
12. `MAX_NOTIONAL_EXCEEDED`

All reject predicates should be computed in a fixed-latency datapath. The priority encoder selects one deterministic `reject_reason` when multiple conditions are true.

## Fail-Closed Behavior

### General parser errors

- If UDP payload length is 0, ignore the packet.
- If UDP payload length is not divisible by 32, treat the packet as a protocol error.
- If `message_type` is unknown or reserved, treat the message as a protocol error.
- If reserved bytes or bits are nonzero, treat the message as a protocol error unless the specific message type defines otherwise.
- If a UDP payload contains more than one `ORDER_INTENT`, treat the packet as an `ORDER_INTENT_PROTOCOL_VIOLATION`.
- If any message follows an `ORDER_INTENT` in the same UDP payload, treat the packet as an `ORDER_INTENT_PROTOCOL_VIOLATION`.
- Protocol errors increment `parser_error_counter`.

### Late frame-integrity failure

The FPGA may process messages and begin transmitting an `ORDER_DECISION` before the source Ethernet frame's FCS has been validated.

If the source frame later fails integrity validation:

- any speculative `ORDER_DECISION` associated with that frame shall be transmitted with an intentionally incorrect Ethernet FCS;
- the response shall therefore not be externally valid;
- the FPGA shall enter `STREAM_FAULT`;
- all trading state shall be treated as untrusted; and
- recovery shall require `RESET_ALL` followed by host replay of configuration and market state.

### Sequence errors

- Downstream `sequence_number` increments globally across all PC-to-FPGA message types.
- If `sequence_number` is not the expected next value, raise `sequence_error` and enter `STREAM_FAULT` state.
- In `STREAM_FAULT` state, the FPGA shall reject all subsequently decoded `ORDER_INTENT` messages with `STREAM_FAULT`.
- `STREAM_FAULT` is cleared only by `RESET_ALL`.

### ORDER_INTENT rejection rules

Reject the order intent if any of the following is true:

- FPGA is in `STREAM_FAULT`.
- `flags` is nonzero.
- `reserved` field is nonzero.
- `symbol_id` is unknown or not configured.
- symbol is disabled.
- `symbol_status` is not `TRADING`.
- required top-of-book side is invalid.
- `order_side` is not `BUY` or `SELL`.
- `order_qty` is 0.
- `order_price` is 0.
- `order_qty > max_order_qty`.
- `order_price` violates configured price band.
- `order_notional > max_notional`.

### CONFIG_CONTROL error rules

- Unknown `config_opcode`: ignore command and increment `config_error_counter`.
- Invalid `symbol_id` for a symbol-specific command: ignore command and increment `config_error_counter`.
- Invalid config value: ignore command and increment `config_error_counter`.

### Default reset state

After reset:

- `STREAM_FAULT` cleared.
- all symbols disabled.
- all symbol statuses set to `UNKNOWN_INVALID`.
- all top-of-book valid bits cleared.
- all top-of-book prices and quantities set to 0.
- all risk limits cleared.
- counters cleared.

This default state is fail-closed: order intents are rejected until the host explicitly configures the symbol and the required risk limits.

