# Galax-z OS firmware

Changes to the OP-Z's own OS (`os.ldr`, TE's 1.2.45): patch records, our own Blackfin code, the tools that build and write them, and what
was found out on the way. Built on [OP-FREE](https://github.com/mutlisensor/op-free)'s research.

**Before you write anything to an OP-Z: [DISCLAIMER.md](../DISCLAIMER.md) and [SAFETY.md](../docs/SAFETY.md).** What is confirmed on the unit
and what is not: [STATUS.md](../docs/STATUS.md). What to build next, and what not to: [WORTH-DOING.md](../docs/WORTH-DOING.md).

**Start with [`notes/device-guide.md`](notes/device-guide.md)**: how the OP-Z runs (chips, timing, the LED pipeline and its budget, hooks,
memory, writing Blackfin code, flashing, the app's link) and what makes things run well on it.

## What is where

| Folder | What | In |
|---|---|---|
| `patches/` | The records: addresses, the bytes expected, our bytes, the evidence, the risk, how to revert | |
| `builds/` | Which records make a version. A version's records are frozen once it is out | |
| `galaxy/` | The boot animation player and its frames | v2 |
| `ab/` | A/B bars | v3 |
| `pages/` | The tumbler, EUCLID and GROOVE (v4's tumbler alone: git `dda0da9`) | v4, v5, v11, v13 |
| `usbhost/` | Older USB keyboards, HOST / INSTRUMENT | v6 |
| `keys/` | Sustain pedal, modulation wheel | v7 |
| `meter/` | Load meter | v8 |
| `voices/` | More live voices | v9 |
| `tell/` | Tells the app about the pages | v10, v11, v13 |
| `chime/` | The Quindar tones at power-on | v11, v12 |
| `walker/` | The LED walker, our first code on the unit; a test build | |
| `engines/` | The piano and OTT: plugs, installed without flashing | |
| `tools/` | `ldr.py` reads an image, `patch.py` builds, `flash.py` writes, `*_build.py` compile, `test_*.py` test | |
| `notes/` | The device guide; LEDs; debounce; update mode | |
| `dumps/` | Yours, git-ignored: TE's `os.ldr` as read off your unit, and what every run saved | |

## Flashing

**The Galax-z app's hub does the same on the Mac** (`./run-mac.sh -hub`): same images, same refusals. `Firmware/flash` opens a local page (it makes `Firmware/.venv` with pyserial the first time). Put the OP-Z in update
mode (hold SCREEN while switching on), press **Check device**, then **Flash** on an image and type its label.
`original` is the way back. From the terminal: `Firmware/flash images | check | flash LABEL [--dry-run]`.

A build is a list of patch records in `builds/` (`galaxz-v1.json`); a record marked DRAFT keeps its build from being
flashed. Every run saves what was installed, and a log, to `Firmware/dumps/flash-<time>/`. How the write command
works: `notes/update-write.md`.

## What is never in this repository

TE's code. `os.ldr`, dumps, decrypted firmware and keys stay in `Firmware/dumps/` (git-ignored) or outside the repository. What is committed:
tools, patch records (addresses and bytes, never images), notes. [What of TE's is in here](../DISCLAIMER.md#what-of-tes-is-in-here) says it exactly.

## The single-unit protocol

There was one OP-Z and no spare (2026-11-21), so every step is as small and as reversible as it can be. Keep to it even if you have two.

1. **Back up everything first.**
   - Settings: OP-FREE's `opz.py backup`, or the app's BACK UP NOW.
   - Projects, samples, config: content mode (hold TRACK while switching on), copy the whole disk to the computer.
   - The OS: `os.ldr` and `os.crc32` read off the unit (`opz_os_read.py`, read-only).
   - TE's official update `z_firmware_1_2_45.zfw`, checked against SHA-256
     `ae76c1f3d7a3eb666dc7c29bdfee6dfa49150175929cfff28a57ca9c6f209fd5`.
2. **Only two files are ever written:** `/yaffs2/os.ldr` and `/yaffs2/os.crc32`. Never the bootloader or anything in
   SPI flash, never the keyboard or Bluetooth chips' firmware. Those are what could make the unit unrecoverable.
3. **Only through a strict console tool**, built like `opz_os_read.py`: every frame it can send is fixed at import,
   everything else is refused, and it is tested against a fake console before it meets the OP-Z
   (`tools/flash.py`, `tools/fake_console.py`, `tools/test_flash.py`). Never typed by hand into the console. Never these types: `0x10`/`0x14` (write or format SPI flash), `0x15` (formats the whole
   NAND on its header alone), `0x23` (upgrade), `0x29` (delete), `0x31` (run code), `0x3b` (unknown).
4. **Every image it writes is either the original or the patcher's output**, checked by SHA-256, with `os.crc32`
   always written to match (the decimal CRC-32 of `os.ldr`, as TE's update writes it). If the bootloader checks
   the CRC (op-free Q-48), a matching one passes; if it doesn't, nothing is lost.
5. **Read back after every write** (`0x19`) and compare byte for byte before restarting.
6. **First write changes nothing:** the original `os.ldr` written back. It proves the write route with no change
   to what runs.
7. **Then one small change at a time,** smallest and most visible first: an LED colour (data only), then the
   debounce, then shortcuts. The owner of the OP-Z confirms each write. (The LED colours weren't found yet, so the debounce
   went first, as Galax-z v1.)

## If it goes wrong

| What happens | Way back |
|---|---|
| The changed OS crashes or freezes | Switch off (if it doesn't, wait: a hang stops when the battery runs out), then on holding SCREEN: update mode is the bootloader's, not the OS's. Write the original `os.ldr` and `os.crc32` back with the same tool |
| That route fails | TE's own procedure: copy the official `.zfw` onto "OP-Z Boot", eject, don't switch off until it restarts (manual p.63) |
| Still broken | Factory reset in update mode (SCREEN + STOP): it removes custom content, which is why step 1 backs it all up |

Whether these work from an OS that does not start has never been tried: [STATUS.md](../docs/STATUS.md#going-back).

## How it came to be

| | What | |
|---|---|---|
| 1 | The OS read off the unit, identical to 1.2.45; `ldr.py`, `patch.py` | 2026-11-21 |
| 2 | The debounce found; LEDs and DMX mapped | 2026-11-21 |
| 3 | The write command decoded in the unit's own bootloader (read off SPI flash with read-only `0x17`); `flash.py`, the fake console | 2026-11-21 |
| 4 | The original written over itself, read back identical, boots; then Galax-z v1: the first changed OS on a unit | 2026-11-21 |
| 5 | The LED walker: our own code runs from `0x80C00000` | 2026-11-21 |
| 6 | Boot animations (v2), A/B bars (v3), tumbler (v4), EUCLID (v5), USB keyboards (v6), pedal and presets (v7), load meter (v8), live voices (v9); the piano and OTT | 2026-11-21 and 22 |
| 7 | v10 tells the app | 2026-11-22 |
| 8 | The red page, GROOVE, and the tones (v11); the tones in place of TE's start sound (v12); GROOVE in light green (v13); each with a *quiet* twin | 2026-11-22 |
