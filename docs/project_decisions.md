# Project Decisions

## Decision 001: Project Scope

This project implements a deterministic FPGA market-gateway slice.

The FPGA will consume normalized market-data messages derived from historical NASDAQ ITCH data, maintain top-of-book state, perform pre-trade risk checks on order intents, and output accept/reject decisions with cycle-level latency measurements.

The project is not meant to be a full trading bot, a full exchange simulator, or a full raw ITCH feed handler in v0.

## Decision 002: Host-Normalized Market Data

In v0, the PC performs raw historical data parsing and converts relevant market-data events into a fixed-format internal protocol.

The FPGA receives the normalized protocol, not raw NASDAQ ITCH messages.

Reason being:
1. Raw ITCH order-book reconstruction is a larger memory-architecture problem.
2. Normalized messages let the FPGA project focus first on deterministic packet processing, state update, risk checking, and latency measurement.
3. The design can later be extended by replacing the host normalizer with an FPGA raw-ITCH parser.

## Decision 003: Instrument Representation

The FPGA datapath will use a numeric exchange-style instrument identifier, named `stock_locate`.

Human-readable ticker strings such as AAPL or MSFT will remain in host-side metadata, logs, and documentation.

Reason:
1. Fixed-width numeric IDs are suitable for FPGA comparison and table indexing.
2. String matching does not belong in the critical datapath.
3. NASDAQ ITCH-style feeds already use compact identifiers such as stock locate codes.

## Decision 004: Data Representation

Prices will be represented as integer ticks, not floating-point values.

Example:
If one tick is one cent, then $100.25 is represented as 10025.

Reason:
- Integer arithmetic is deterministic and (much) cheaper in FPGA logic.

## Decision 005: Latency Measurement

Latency will be measured primarily in FPGA clock cycles.

Nanosecond values may be reported only when the clock frequency and measurement boundary are explicitly stated.

Example:
A 17-cycle path at 100 MHz corresponds to 170 ns.

The project will distinguish internal FPGA datapath latency from external PC-to-FPGA-to-PC wall-clock latency. Internal latency is the main metric for v0.