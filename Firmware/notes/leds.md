# LEDs and DMX: how the OP-Z's OS lights its keys

Mapped 2026-11-21 in `os.ldr` 1.2.45 read off the author's OP-Z (offline, `tools/ldr.py`). Findings only: no TE code is
reproduced here. Labels: **[code]** read in the disassembly; **[inferred]** follows from it but isn't proven on the
unit; **[unit]** needs a test on the OP-Z.

## The chain

```
UI frame (0x8010a904)
  ├─ current context draws its LEDs ............ setLedPalette / setLed calls in the contexts (0x8011d…–0x80126…)
  ├─ lights-track bridge (0x8003a9d4) .......... on track 15 (lights): the 16 step LEDs take the light colours
  ├─ meters / overlays (0x8003c6c8, 0x8010a986)
  └─ ledTick (0x8003d620 → 0x801313f4) ......... blink phase, frame builder, send
        └─ frame builder (0x8003d1e0) ........... changed LEDs → message 0x10 → keyboard chip (PSoC 5LP)
                                                   └─ the PSoC drives the LEDs (its own firmware)
```

**The Blackfin never touches an LED pin.** The keyboard chip (Cypress PSoC 5LP, op-free OPZ_FIRMWARE_MAP) drives
them; the OS keeps a colour per LED in RAM and sends the keyboard chip what changed [code]. `[led control]` in the
OS is only the name of a boot stage.

## The LED state in RAM [code]

| Address | What |
|---|---|
| `0x0802d3a4` | **LED records**: 5 bytes per LED, `R G B W blink`. Cleared as 265 bytes (53 records); the builder sends 51 (indices 0–50) |
| `0x0802d4b0` | what was last sent, same layout (the builder sends only differences) |
| `0x0802d5bc` | the message being built |
| `0x0802d3f4` | records 16–39: cleared as one block of 24 by `0x8003d600` (see "Which LED is which") |

`blink` non-zero: the LED is sent dark for half of a 60-tick cycle (`0x801313f4` counts 0–59; lit while < 30).

## The LED functions [code]

| Address | Does | Called from |
|---|---|---|
| `0x8003d3be` | **setLed(i, R, G, B, W)**, blink off | lights bridge, `0x8003cfca`, `0x8003d178…d1ac`, `0x8011d6da`, `0x80123d9a` |
| `0x8003d352` | setLed from the palette: colour byte, bits 4–6 = palette entry | 21 sites in the UI contexts (`0x80042866`, `0x8011d…`–`0x801261d0`) |
| `0x8003d56e` | setLed from a gradient: position 0–255 blends palette entries (table `0x81016014`) for R, G, B; W from the palette | boot/power animations, meters, the lights bridge's track LED |
| `0x8003d3f0` | blend a colour into an LED by an amount (255 − a) | meters `0x8003c7b0` |
| `0x8003d5e0` | clear all records | |
| `0x8003d600` | clear records 16–39 | `0x8003c8a8` |
| `0x8003d50c` | clear all, and send message `0x88` (keyboard chip: LEDs reset) | `0x8002cfdc`, `0x8002d490` |
| `0x8003d620` | the tick: `0x801313f4(kb port 0x0801fb90, records)` | UI frame `0x8010a9de`, animations |
| `0x8003d1e0` | the frame builder | `0x8013143e` only |

**Palette** at `0x81015fec`: 16 entries of 4 bytes, `R G B W`. Entries 0–4 are pure red, green, blue, a
red-green mix (`3a f0 00 00`) and pure white (`00 00 00 ff`), which is how the channel order is known. Entries 10–14
repeat 0–4 [code]. What each entry means in the UI (track colours etc.) comes from its callers [unit].

## The message to the keyboard chip [code]

The OS sends serial messages to the PSoC through `0x11a01d24` (port, type, payload, length; the same routine sends
the debounce, type `0x14`).

| Type | Payload | What |
|---|---|---|
| `0x10` | `00 <led> R G B W`, repeated, up to ~160 bytes per message (more next tick) | set LEDs |
| `0x88` | none | LEDs reset |
| `0x10` (6-byte form, `0x8013151c`, called from `0x8002cbea`) | template from `0x815c94f0` + 5 arguments | not read yet |

So an LED is set to a full 8-bit RGBW colour: nothing in the protocol limits colours to the palette. The palette is
the UI's choice, not the hardware's.

## Which LED is which [inferred, unit]

- **0–15: the 16 step keys.** The lights bridge writes exactly LEDs 0–15 with the colours of the lights track's
  16 steps.
- **16–39: 24 LEDs cleared as a block** (`0x8003d600`). Most likely one group of keys, but which one is not proven.
- **40–50:** the rest (track, function and transport keys). Meters step through LEDs from 40 (`0x8003c742`).

A full index → key map needs one test on the unit: a build that walks one white LED across indices 0–52, slowly,
while somebody notes which key lights. That needs the hook below, so it comes first.

## DMX [code]

- `DmxController.cpp`, code `0x8003aa00`–`0x8003c07e`: loads `config/dmx.json` (fixtures and their modes;
  `readme/how_to_dmx.txt` on the content disk), turns the lights track into DMX channel values, and writes them out
  in 56-byte pieces (`0x8000b55c`; "Failed to write dmx data" at `0x8003aee8`).
- **The lights-track bridge `0x8003a9d4`** runs every UI frame after the context has drawn. If the current track
  (`[ui + 0x30]`, `0x80107b90`) is 14 (track 15, lights), it sets LEDs 0–15 to the lights track's per-step R, G, B
  (bytes at `obj + 0x40`, `+ 0x50`, `+ 0x60`), each scaled by a brightness (`obj + 0x8a`), with W 0. Then it lights
  the lights track's own key from the gradient table `0x81015a30`.

So the OS already shows DMX colours on its own keys, but only on the lights track and only on the 16 step keys.

## What this makes possible (Galax-z)

| Idea | How | Size |
|---|---|---|
| Own colour language | change palette entries at `0x81015fec` (data only, no code) | a record like debounce.json |
| Lights track on its keys everywhere | let the bridge run on every track: its `== 14` test at `0x8003a9f4` | a 2–4-byte patch; but it then hides the step LEDs on other tracks, so a toggle is better |
| Animations across the keys, dot-matrix | our own code, called once per frame in place of `0x8003d620` at `0x8010a9de`: draw into the records (any RGBW), then jump on to `0x8003d620` | a new LDR block with Blackfin code (`bfin-elf-as`) + one 4-byte call retarget |

The third is the general mechanism: a "Galax-z layer" that runs after TE's UI and before the LEDs are sent, so it
can paint over anything, read the lights track, react to keys and keep its own animation clock. What it needs
first: a free, unused piece of RAM for the code and its state, and the LED walker above to learn the layout.

## The LED walker (built 2026-11-21; **runs on the unit**, same day)

`walker/led_walker.S`, 184 bytes, loaded at `0x80C00000` by its own LDR block; the UI frame's `CALL 0x8003d620` at
`0x8010a9de` becomes `CALL 0x80C00000` (`57 e3 11 ab`, same size), and the walker jumps on to `0x8003d620`. Every
frame it clears the records, then: step 0 all LEDs dim red (a new round), step n LED n−1 alone (white; green when
n−1 is a multiple of 10), 120 frames per step. Only R0–R3, P0–P2 and CC, no stack, no hardware loops.

The loader side was checked in the bootloader: `nand_boot` hands the boot ROM's kernel (`0x04000008`) a read
callback over the open file, so the stream is never buffered in RAM where the new block could overwrite it; the
bootloader itself runs from `0x82800000` up.

**On the unit (2026-11-21):** flashed over Galax-z v1 with `flash.py` (405 pieces, read back identical); it boots and
walks as written: the red round, then one LED at a time. So our own code runs from `0x80C00000`, the hook at
`0x8010a9de` holds, and nothing in a normal start overwrites that memory [unit]. The map itself: next.

## The galaxy boot (2026-11-21)

`galaxy/` (build `galaxz-v2`): 64 frames computed on the Mac from `galaxy/layout.json` (51 LEDs placed from a top view
of the OP-Z and the code above) by the animation library (`OPZFirmware/Animations.swift`, rendered by
`swift run galaxz-frames galaxy Firmware/galaxy/frames.bin`), played by `galaxy_boot.S`. Since the player is the same
for every animation, the app's hub swaps the frames as data and flashes any animation of the library.

- **First try: during boot**, replacing the boot progress `0x8002cbf0` (16 calls between the boot stages). Flashed;
  the OP-Z booted normally but **nothing showed on the keys** [unit]: the keyboard chip's own start-up lights appear
  to hold the keys until the OS takes them (the old progress dots were likely never visible either) [inferred].
- **Now: right after boot**, through the UI frame's LED send (the walker's proven hook): the first 128 UI frames
  paint galaxy frame n/2 over the UI, then it only passes on to `0x8003d620`. Boot time is TE's again.

- **Played on the unit (2026-11-21):** the centre-out spiral showed right after start-up. Then, as asked: the wave
  rolls **left to right**, and every animation ends in a **twinkle-out** (each LED sparkles white at its own moment,
  then goes dark).

- **Then, seen on the unit:** choppy, the right side and the dial LEDs lagging (a red tail along the top), no
  twinkle: one LED message carries ~26 LEDs and the builder starts from LED 0, so the high LEDs starved. The player
  now sends twice per UI frame while it plays. Still no twinkle: one frame per UI frame was faster than 60 a second,
  so the player now takes the frame from the OS's millisecond clock (`0x80028294`, CYCLES / cycles per ms).
- **Works on the unit (2026-11-21):** 4 s, the wave crosses left to right, every LED follows, the twinkle-out shows.
- **The library** (`OPZFirmware/Animations.swift`) is modular: 16 **patterns** (what moves: lit 0-1 and where in the palette, no
  colour of their own) and a **style** (three colours, black and white, an opacity for the top row and encoders, one for the
  two white rows). Lit is full or off with a short ramp; the last 0.7 s is an even fade; 240 frames. The hub swaps the frames
  into the same player as data, and its editor makes your own (kept on that device).

## Open

- Which key each LED index 16–50 is [unit].
- The 6-byte `0x10` form (`0x8013151c`): maybe fades or effects inside the keyboard chip.
- What drives the keyboard chip's own brightness, if anything (PSoC firmware, not read).
- A free RAM region for Galax-z code: the heap starts at `0x8014206C` (op-free memory-map.md); a block placed below
  it must not collide with anything the OS loads.
