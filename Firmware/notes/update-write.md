# Writing os.ldr in update mode: console command 0x11

Read 2026-11-21 in the bootloader on the author's OP-Z. Findings only: no TE code is reproduced here. The bootloader was
read off the unit's SPI flash with the read-only command `0x17` (20 fixed frames of 16 KiB from offset 0). The main
stream starts at SPI `0x10000` and is 257,644 bytes long. The console overlay sits at `0x11a00180` (block 7), at the
same addresses as op-free's research/update-console.md. The dumps are in `Firmware/dumps/bootloader/` (git-ignored).

## The frame

`C0 01 11 <len u32 BE> <size u32 BE> <name> 00 <data>`, with every byte after `C0` escaped (`C0`/`7D` → `7D`,
byte XOR `0x20`, the data included).

| Step | What the bootloader does | Where |
|---|---|---|
| Header | type `0x11` → collect a u32 into `+0x94` (size), set the byte counter `+0x98` to 4 | parser `0x11a025b0`, states 15–18 |
| Name | collect bytes into `+0x10` up to the zero byte; the zero byte hands over to the handler. No length check: keep names short | state 19 |
| Open | mount once per session; `snprintf("%s%s", "/yaffs2/", name)`; `mkdir` every `/` after `/yaffs2/` (none for `os.ldr`); `fopen(path, "w+b")`, so **the old file is emptied here**; counter += name length + 1 | handler `0x11a02932`, `0x11a02ad6`–`0x11a02bcc` |
| Data | each byte into a 2,048-byte buffer, counter += 1. A full buffer → `fwrite`, then an **empty type-`0x12` frame**, then the LED progress bar | `0x11a029b4`–`0x11a02a2a` |
| End | when the counter equals `<len>`: `fwrite` the rest, `fclose`, sync `/yaffs2` (`0x8280e3be`), reply **type `0x13`, payload `01 00`** | `0x11a02a38`–`0x11a02aaa` |

So `<len>` = 4 + name + 1 + data: the whole payload. The size field is stored but not used. Return values of
`fopen` and `fwrite` are not checked, so the read-back (`0x19`) is the only proof of a write.

Two Blackfin+ instruction forms that binutils calls ILLEGAL show up throughout. Both were decoded from context:
`00 DE hi lo` is an absolute call (e.g. `CALL 0x8280e3be`, op-free's yaffs sync), and `00 D8 hi lo 0r xx` is an
8-byte load or store of register r at an absolute address (`0x11804000` holds the open file).

## What flash.py does with it

It sends the header up to the zero byte, waits 0.3 s, then sends one 2,048-byte piece at a time and waits for its
`0x12` (`0x13` after the last). If an answer doesn't come, the upload is still open on the OP-Z and any further byte
would become file data, so the tool stops sending anything (`Stalled`). Way back: switch off, then on holding
SCREEN, then flash again.

## On the unit (2026-11-21)

| Write | Result |
|---|---|
| Original `os.crc32` then `os.ldr` over themselves (protocol step 6) | 1 + 405 pieces, every answer received, both read back identical; normal boot |
| Galax-z v1 (debounce +15) | the same; **boots and plays**: the first changed OS proven on a unit; key test fine |

## os.crc32

Neither the bootloader nor the 1.2.45 OS contains the string `os.crc32`, so most likely nothing reads it at boot
(op-free Q-48: evidence, not proof). The patched OS booted with a matching one. flash.py keeps writing a matching
`os.crc32` (protocol step 4); it costs one 10-byte write.
