# CDC-Safe Asynchronous FIFO Specification

## Overview

This project implements a parameterized asynchronous FIFO in SystemVerilog for transferring data between independent write and read clock domains.

The main goal is to demonstrate a CDC-safe FIFO structure using:

- Local binary write/read pointers
- Gray-coded pointer transfer across clock domains
- Two-flop synchronizers
- Full and empty flag generation using synchronized remote pointers

## Parameters

| Parameter | Description | Default |
|---|---|---:|
| `DATA_WIDTH` | Width of each FIFO data word | `32` |
| `DEPTH` | Number of FIFO entries | `16` |
| `ADDR_WIDTH` | Address width derived from FIFO depth | `$clog2(DEPTH)` |

`DEPTH` must be a power of two.

Valid examples:

```text
2, 4, 8, 16, 32, 64, ...
```

Invalid examples:

```text
3, 5, 6, 10, 12, ...
```

## Interface

### Write Clock Domain

| Signal | Direction | Description |
|---|---|---|
| `wr_clk` | input | Write clock |
| `wr_rst_n` | input | Active-low write-domain reset |
| `wr_en` | input | Write request |
| `wr_data` | input | Write data |
| `full` | output | FIFO full flag |
| `almost_full` | output | FIFO almost-full flag |
| `overflow` | output | Set when write is attempted while FIFO is full |

### Read Clock Domain

| Signal | Direction | Description |
|---|---|---|
| `rd_clk` | input | Read clock |
| `rd_rst_n` | input | Active-low read-domain reset |
| `rd_en` | input | Read request |
| `rd_data` | output | Read data |
| `empty` | output | FIFO empty flag |
| `almost_empty` | output | FIFO almost-empty flag |
| `underflow` | output | Set when read is attempted while FIFO is empty |

## Pointer Strategy

The FIFO uses two types of pointers:

1. Binary pointers
2. Gray-coded pointers

Binary pointers are used locally inside their own clock domains.

```text
wr_bin: write-domain binary pointer
rd_bin: read-domain binary pointer
```

Gray-coded pointers are used for clock domain crossing.

```text
wr_gray: write pointer sent to read clock domain
rd_gray: read pointer sent to write clock domain
```

## Why Gray Code?

Binary counters can change multiple bits in a single transition.

Example:

```text
Binary 7 -> 8
0111 -> 1000
```

Four bits change at once. If this pointer crosses into another clock domain, the receiving domain may sample an invalid intermediate value.

Gray code changes only one bit between consecutive values.

Example:

```text
Gray 7 -> 8
0100 -> 1100
```

Only one bit changes. This makes pointer synchronization safer for CDC use.

## Extra Pointer Bit

The FIFO address width is:

```systemverilog
ADDR_WIDTH = $clog2(DEPTH)
```

For example, if:

```text
DEPTH = 8
ADDR_WIDTH = 3
```

Then memory addresses use 3 bits:

```text
0 to 7
```

However, FIFO pointers use one extra bit:

```systemverilog
logic [ADDR_WIDTH:0] wr_bin;
logic [ADDR_WIDTH:0] rd_bin;
```

For `DEPTH = 8`, this gives 4-bit pointers.

The extra bit helps distinguish empty from full after pointer wrap-around.

Example:

```text
Empty:
wr_bin = 0000
rd_bin = 0000

Full after 8 writes:
wr_bin = 1000
rd_bin = 0000
```

The lower address bits are the same, but the extra bit is different.

## Write Behavior

A write is accepted only when:

```systemverilog
wr_en && !full
```

If `wr_en` is asserted while `full` is high:

- the write pointer does not advance
- memory is not written
- `overflow` is set

## Read Behavior

A read is accepted only when:

```systemverilog
rd_en && !empty
```

If `rd_en` is asserted while `empty` is high:

- the read pointer does not advance
- no valid data is consumed
- `underflow` is set

## Full Detection

Full detection is performed in the write clock domain.

The FIFO becomes full when the next write Gray pointer equals the synchronized read Gray pointer with its top two bits inverted.

```systemverilog
full_next =
  (wr_gray_next == {~rd_gray_sync_wr[ADDR_WIDTH:ADDR_WIDTH-1],
                     rd_gray_sync_wr[ADDR_WIDTH-2:0]});
```

This detects the condition where the write pointer has advanced exactly `DEPTH` entries ahead of the read pointer.

## Empty Detection

Empty detection is performed in the read clock domain.

The FIFO becomes empty when the next read Gray pointer equals the synchronized write Gray pointer.

```systemverilog
empty_next = (rd_gray_next == wr_gray_sync_rd);
```

## Verification Scope

The current testbench checks:

| Test | Description |
|---|---|
| Reset behavior | Checks initial flag values |
| Basic write/read | Verifies FIFO ordering |
| Empty flag | Checks empty after draining |
| Full flag | Checks full after `DEPTH` writes |
| Overflow | Checks write attempt while full |
| Underflow | Checks read attempt while empty |
| Independent clocks | Uses different write and read clock periods |

## Known Limitations

- RTL simulation does not fully model metastability.
- Static CDC signoff is not included.
- The current FIFO memory model uses asynchronous read behavior.
- Almost-full and almost-empty thresholds are fixed in this version.
- Formal verification is not included yet.