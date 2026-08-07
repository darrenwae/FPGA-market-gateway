# Market Data

This repository does not redistribute NASDAQ market-data files. Full-day TotalView-ITCH datasets are several gigabytes and will remain outside version control.

## Obtaining a Dataset
NASDAQ publishes public TotalView-ITCH 5.0 sample datasets in its official EMI directory:

https://emi.nasdaq.com/ITCH/Nasdaq%20ITCH/

1. Choose a file ending in `.NASDAQ_ITCH50.gz`
2. Download its corresponding `.md5sum`

If NASDAQ provides a matching checksum file, verify the compressed download before decompression. Checksum verification is recommended but not required to run the host replay.


After downloading:
1. Verify the downloaded checksum.
2. Decompress the `.gz` file.
3. Place the decompressed file under `data/raw/`.

For example:

```text
data/raw/01302019.NASDAQ_ITCH50
```

The host executable will receive the dataset path as a command-line argument; it does not require a particular trading date.


## Replay Profiles

All replay profiles use the same full-day dataset:

- `full`: replay the complete feed at original timestamp spacing.
- `open`: warm up state, then replay the opening window at original timestamp spacing.
- `close`: warm up state, then replay the closing window at original timestamp spacing.

Partial profiles do not use separately cut ITCH files because later messages may depend on orders and state established earlier in the day.

## Test Fixtures

Small synthetic test inputs belong under:

```text
tests/host/fixtures/
```

They are separate from real NASDAQ market data.