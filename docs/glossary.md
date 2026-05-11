# Glossary

## Ticker / Symbol

A human-readable identifier for a traded instrument, such as AAPL, MSFT, or NVDA.

## Stock Locate

A compact numeric identifier used to represent an instrument in the FPGA datapath.

In this project, `stock_locate` is the primary instrument identifier inside the FPGA.

## Tick

The smallest price unit used by the project.

Example: if one tick is one cent, then $100.25 is represented as 10025 ticks.

## Bid

The highest visible price someone is currently willing to buy at.

## Ask

The lowest visible price someone is currently willing to sell at.

## Top of Book

The current best bid and best ask for an instrument.

## Market Data

Messages that describe changes in the market state.

In v0, the FPGA receives normalized top-of-book updates derived from historical data.

## Order Intent

A proposed order before it is allowed to leave the system.

Example:
Buy 50 shares of AAPL at 10025 ticks.

## Risk Gate

A hardware block that checks whether an order intent is allowed to be fulfilled.

It can reject an order because of quantity limits, price limits, invalid instrument ID, stale market data, or position limits.

## Latency

The number of FPGA clock cycles between a defined input event and a defined output event.

In this project, latency must always specify the measurement boundary.

Example:
20 cycles from first payload byte accepted to `decision_valid`.