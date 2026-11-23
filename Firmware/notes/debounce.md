# Debounce: how the OP-Z's OS sets it, and the patch for double triggers

Found 2026-11-21 in `os.ldr` 1.2.45 read off the author's OP-Z (offline, with `tools/ldr.py`). Findings only: no TE code
is reproduced here.

## How it works

- **The keyboard chip (PSoC) debounces the keys, not the OS.** The OS tells it how long to wait: a one-byte value in
  a message from `command_handler_kb.cpp`, logged as "Set button debounce: %d" [code, `0x80131700`]. The function
  remembers the last value it sent and only sends a new one when the value changes.
- **The OS picks one of three values by context** [code, the four callers of `0x80131700`]:

| Site | Loads | Role |
|---|---|---|
| `0x8010d608` (file `0x082db0`) | 35 | value sent (one branch of a jump table) |
| `0x8010d614` (file `0x082dbc`) | 30 | value sent |
| `0x8010dce2` (file `0x08348a`) | 50 | value sent when the byte below is over 30 |
| `0x8010dce4` (file `0x08348c`) | 35 | value sent otherwise |
| `0x8010dcf6` (file `0x08349e`) | 30 | value sent |
| `0x8010dcde` (file `0x083486`) | 30 | **not a value**: the threshold compared with a byte of the active track's sound block (pattern offset `0x5240`, sound byte 5) to choose 50 or 35. Leave it alone |

- Each value is a 2-byte instruction `Rr = imm7` (`0x6000 | value << 3 | r`, little-endian). It holds 0…63, so a
  new value up to 63 is the same instruction with a new number; above 63 would need a longer instruction and a
  different patch.
- **The unit is not confirmed.** 30 / 35 / 50 read naturally as milliseconds, but what the keyboard chip does with the
  byte is in its own firmware, which nobody has read.

## Choosing the new values (from the key test)

Galax-z's KEY TEST measures the gap between a press and its double. If the OS already asks for 30–50 ms, the doubles
on the author's unit should show gaps **above** those values; the new value goes just over the largest double seen, with a
margin, and well under fast playing (two presses of one key are rarely closer than ~80 ms).

- Too low: doubles stay.
- Too high: fast repeated notes on one key get swallowed. Check after the patch with the key test: no doubles, and a
  fast trill still comes through.

## The patch

`../patches/debounce.json` raises every value sent, keeping their order. Its numbers are placeholders (+15: 30 → 45,
35 → 50, 50 → 63) until the key test's report gives real ones. They were run as Galax-z v1
(`../builds/galaxz-v1.json`); flashed 2026-11-21, it boots and the keys behave. `patch.py check` confirms every
address and every expected byte against the image.

Revert: write back the original `os.ldr` and `os.crc32` (Firmware/README.md), or reinstall TE's official 1.2.45.
