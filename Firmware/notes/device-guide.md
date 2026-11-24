# The OP-Z for Galax-z: how it runs, and how to make things run well on it

A working guide to OS 1.2.45 on the OP-Z, for writing Galax-z firmware and app features. It sums up what was read in
the code and proven on the author's unit (2026-11-21); the details are in the other notes, linked per section. Labels:
**[code]** read in the disassembly, **[unit]** seen on the OP-Z, **[inferred]** follows but not proven.

## 1. The chips

| Chip | Runs | Owns | How we reach it |
|---|---|---|---|
| Blackfin+ (BF70x) | TE's OS (`os.ldr`, LDR stream from NAND) and, before it, the bootloader (SPI flash) | sound, sequencer, UI logic, USB, MIDI | **our code goes here**: patch records, code blocks (§5) |
| Cypress PSoC 5LP ("keyboard chip") | its own firmware | key scan, **the key LEDs**, power, charging, USB-PD | serial messages from the OS (§3); never flashed by us |
| Nordic (BLE) | its own firmware | Bluetooth MIDI | — |

The OS keeps a colour per LED and tells the keyboard chip what changed; it never drives a key LED itself
[code, leds.md]. **LED 51** is the exception: two LEDs on Blackfin GPIO pins, switched from LED 51's red and green
bytes by the LED tick (`0x801313f4`, which calls `0x8002b3b6` / `0x8002b388`) [code]; that those two switch GPIO pins
on and off is [inferred] (not read). The LED builder never sends 51 [code].

## 2. Time: the OS has no fixed frame rate

- **The UI task** (`0x80112840`, created at `0x80112bba`) loops: input, contexts, the UI frame (`0x8010a818`, which
  ends in the LED send), the keyboard-chip service (`0x801318b0`), then **sleeps 1 ms** (`delay(0, 1)`) and goes
  round again [code]. So the UI frame has no fixed rate; it probably runs well over 60 times a second when little is
  happening [inferred: the rate was never measured].
- **So: never count frames for timing.** An animation paced by UI frames ran too fast to show its ending on the unit
  [unit]. Use the OS's millisecond clock: **`0x80028294`** returns milliseconds since start (64-bit, R1:R0; it reads
  CYCLES/CYCLES2 with interrupts off for two instructions and divides by the cycles-per-ms at `0x810030a4`). The
  boot log calls it, and so does code at `0x801286f0` (file manager, by its address: [inferred]); our galaxy player calls
  it every UI frame while it plays and the OP-Z runs fine [unit]. That the unit is milliseconds is [inferred] from the log text
  and the animation's length looking right.
- **Delays**: `0x8012e488(seconds, ms)` sleeps (it converts to µs for the L1 routine `0x11a00244`). Fine at boot
  and in tasks; **never in the UI frame hook** (it would stall the UI task) [code].

## 3. LEDs: the pipeline and its budget

```
contexts draw ─► records 0x0802d3a4 (53 × R G B W blink) ─► LED send 0x8003d620 ─► builder 0x8003d1e0
                                                                                     │ only LEDs that differ from
                                                                                     │ the last sent (0x0802d4b0)
                                                                                     ▼
                                                    message 0x10 to the keyboard chip: 00 <led> R G B W, repeated
```

- **One send carries at most ~26 LEDs** (160 bytes of 6-byte entries), and the builder **always starts from LED 0**
  [code]. When more than 26 LEDs change between sends, the high LEDs (right half of the keyboard, the dial LEDs
  40–43, the function keys 44–50) wait, and a short flash on them may never be sent at all. Seen on the unit as
  choppy motion and a "tail of red in the top bar" [unit]. Two sends per changed frame came together with
  longer, brighter frames, so how much the sends alone helped is not known; colour on white-only LEDs (below) was
  probably part of it [inferred].
- **Budget that works [unit]:** while an animation plays, **two sends per changed frame** (all 51 LEDs), at
  **60 changes a second**. Between frame changes the builder finds nothing new and sends nothing, so a fast UI loop
  costs nothing extra.
- **Keep effects within the budget:** change at most ~26 LEDs per send, or send twice per changed frame (as the
  galaxy player does, for a few seconds), or pace at ≤ 60 changes a second. Constant full-field animation for a
  long time is untested: if the keyboard-chip link can't keep up, the OS logs "Serial message queue full" and drops
  messages (no crash) [code].
- **Only some LEDs have colour** [unit, 2026-11-21]: the top row (TRACK and the 16 steps) and the four encoder LEDs.
  The two lower rows are white only: give them W (TE's code lights the keyboard with W, palette entry 4) [code]; RGB
  without W hardly shows there. The library does this for every animation (`LEDAnimation.shown`). In TE's code LEDs 44, 48
  and 50 get colours and 45, 46, 47, 49 only white [code, constant calls]; which of 44-50 is TRACK is not known (the
  library's **Key check** animation settles it; 44 is the guess).
- **Colours are 8-bit RGBW** in the message; the palette at `0x81015fec` is only the UI's choice [code].
  On the unit, a gamma of ~1.6 looks right for computed colours (2.0 looked dim) [unit].
- **Direct LED write**: `0x8013151c(keyboard object 0x0801fb90, led, R, G, B, W)` (led, R in R1, R2; G, B, W on
  the stack) sends one LED at once (a 6-byte `0x10`
  message from the template at `0x815c94f0`), bypassing the records; the next normal send will overwrite it if the
  records disagree [code].
- **During boot the keys belong to the keyboard chip's own start-up lights**: the OS's boot progress (`0x8002cbf0`)
  sends LEDs, but our player there showed nothing [unit]. Why is [inferred]: whether it ran at all was not checked. At the end of boot the OS clears all LEDs and sends `0x88` (LEDs reset,
  `0x8003d50c`) [code]; from the first UI frame on, its LEDs show. **Boot visuals = the first seconds of the UI.**

Which index is which key, from a top view and the code [code + inferred] (`galaxy/layout.json`):

| LEDs | What | Evidence |
|---|---|---|
| 0–15 | the 16 step keys, top row, left to right | the lights bridge and boot progress use exactly these [code] |
| 16–29 | white keys, F to E, left to right | the OS's 24-key table `0x8111312c`; `0x81059ea4` [code] |
| 30–39 | black keys 1…9, 0, left to right | the same table; `0x81059edc` = 39, 30…38 by digit 0…9 [code] |
| 40–43 | the 4 dial LEDs, left to right | the contexts and meters use exactly these four [code] |
| 44–50 | the seven function keys | 48 is RECORD (red when armed, blinking while recording) [code]; the others not known |
| 51 | two GPIO LEDs on the Blackfin (red and green bytes, on/off) | [inferred] from the tick's use of its bytes; where they are: not checked |

The **Key check** animation (hub, Boot animations) settles the function keys' order on the unit; the hub's LED MAP, which
went with the LED walker, is gone (2026-11-21): nobody needed it.

## 4. Where our code hooks in

| Hook | What it is | Used by | Notes |
|---|---|---|---|
| `0x8010a9de` `CALL 0x8003d620` | the UI frame's one LED send (every path of the frame ends there) | LED walker, galaxy | proven [unit]; our code runs, then `JUMP` to `0x8003d620` (keeps the frame's RETS) |
| `0x8002cbf0` | the boot progress (16 calls between boot stages) | first galaxy try | booted, nothing showed (§3); whether it ran is not known |
| `0x80131700` | set button debounce (keyboard chip message `0x14`) | — | the debounce patch changes its callers' values, not this |

A hook replaces a 4-byte `CALL`/first instruction with a 4-byte `CALL`/`JUMP.L` (pc-relative, ±16 MB): our code must
sit within 16 MB of the hook, which is why it lives at `0x80C0xxxx` and not higher.

## 5. Memory for our code

| Range | Status | Ours |
|---|---|---|
| `0x80C00000`–`0x80FFFFFF` (4 MB) | nothing in the OS refers to it (op-free memory-map.md) [code, absence]; **only the ranges on the right have been used on the unit** (they survived start-up and play), the rest of the 4 MB is untested | walker `0x80C00000` (184 B); galaxy player + frames `0x80C10000` (~51 KB) |
| `0x81AEF034`–`0x81AFFFFF` (68 KB) | no reference [code]; out of `CALL` range of most hooks | — |
| `0x81C09000`–… | engine slots 90–255 | not ours |

Rules (enforced by `tools/patch.py`): blocks only in the free list, 4-byte aligned, no overlaps, inserted before the
FINAL block, the stream header's length raised to match. Give each feature its own range (next: `0x80C20000`).

## 6. Writing Blackfin code for the OP-Z

- **Registers**: R0–R3, P0–P2, CC, ASTAT are call-clobbered; R4–R7, P3–P5, FP must survive. A routine that calls OS
  functions saves RETS (`[--SP] = RETS; SP += -12; CALL (P1); SP += 12; RETS = [SP++];`), the 12 bytes being the
  outgoing argument area the ABI requires [unit: galaxy player].
- **Avoid hardware loops** (LC0/LC1) in hooks: plain compare-and-branch loops are cheap enough and leave the OS's
  loop registers alone.
- **Blackfin+ instructions** the stock binutils can't decode (`00 DE hi lo` absolute CALL, `0r DA hi lo` 32-bit
  load, `00 D8 …` absolute load/store) appear in TE's code; our code uses plain Blackfin (assembled by
  `~/opt/bfin-elf`, `tools/asm.py`, which keeps a record's bytes equal to its source).
- **The assembler** rejects `.equ` expressions in some operands (address halves, `* `): write the numbers, comment
  the meaning.
- **Data instead of code** wherever possible: the galaxy player is ~150 bytes; every animation is data swapped into
  the same player (the hub does it). New effects need no new code on the OP-Z.

## 7. Flashing and recovery (the single-unit protocol, in practice)

- Update mode: switch off, on holding SCREEN; the Mac sees "OP_Z Boot" (`/dev/cu.usbmodem*`) a few seconds later.
- `Firmware/flash flash <label>` or the hub: backs up what is installed, writes `os.crc32` then `os.ldr` (one
  2 KB piece per answer), reads both back; well under a minute [unit].
- **An unknown OS on the unit only takes `original`.** The hub also accepts Galax-z v2 playing frames it does not have: our
  player's code byte for byte and, with it and v2's edits taken out, TE's 1.2.45 by SHA-256. `flash.py` does not: after
  the frames or a record changed, write `original` first, then the build, in the same update-mode session [unit].
- Bad build: update mode again, flash `galaxz-v1` or `original`. Nothing written so far has needed it: every build
  booted [unit].

## 8. The app's link (MIDI) and what makes it feel fast

| Link | Good for | Avoid |
|---|---|---|
| USB cable | everything; the backup of ten projects (3.4 MB) takes seconds | — |
| Bluetooth MIDI | the pattern screen, edits, sounds | bulk transfers: 3.4 MB of SysEx takes minutes and holds every pattern refresh behind it [unit] |

- **Edits**: the OP-Z sends `$02` on every edit; until `$02` is decoded the app fetches the bank again once edits
  pause (0.15–0.6 s; ~4 KB compressed). The `$02`s and the bank changes they stand for are logged (Documents/
  Diagnostics) to decode them: then edits apply at once, with no bank traffic.
- **One client per OP-Z**: two Galax-z (iPad and Mac) or TE's app at once break each other; over Bluetooth the OP-Z
  takes one link. The Mac build is cable-only for that reason.
- **Pairing**: a first Bluetooth link may need the system pairing list (PAIR BY HAND); afterwards it links by itself
  [unit].

## 9. Open questions worth the time

1. `$02` format → instant edits (capture: edit on the OP-Z with Galax-z connected; the log does the rest).
2. Which of LEDs 44-50 is TRACK (the Key check animation).
3. The keyboard-chip UART speed: the real ceiling for LED traffic (the UART registers are not loaded as constants;
   look for the UART driver's base pointer).
4. Where LED 51's two GPIO LEDs are on the case.
5. A boot animation *during* boot: possible only if the keyboard chip can be told to release the keys earlier (its
   `0x88` reset is what the OS sends at the end of boot).

## 10. The step screen, and the A/B bars (`ab/`, build `galaxz-v3`; seen on the unit)

- **The sequencer** is at `[0x81059d1c]`: `+0x44` the pattern being played (project x 16 + pattern; the getters at `0x80107b3c`
  multiply it by `0x5390`, a pattern's size), `+0x30` the track, `+0x1c` / `+0x1f` / `+0x22` flags the step screen reads, `+0x40`
  ticks (below 18 of 24 the playhead is lit), `+0x345d3a + track` that track's position (step in bits 4-7) [code].
- **The screen on now**: `[+0x3463bc]`; the normal step screen is the object at `+0x346260` (the lights bridge makes the same
  test) [code]. Its drawing is at `0x8011d72c`. Every UI frame clears all LED records first (`0x8003d5e0`), so whatever is there
  after the screens drew is this frame's [code].
- **Colours on the steps** [code]: trigger red (palette 0), note tail cyan (`0x6f`), micro timing purple (`0x7f`), components
  green (`0x1f`), **playhead white (`0x4f`, W only)**, or `0x5f` in another state (seen in the code, not on the unit).
- **A/B bars** (`0x80c20000`, 172 bytes, from `0x8010a97a`): on that screen, step LEDs that are pure white stay so on odd
  patterns (nothing is written) and become purple on even ones. Tested on fake memory (`tools/test_ab.py`, an interpreter for the assembled bytes).
- **32 steps** are two patterns in a chain: a pattern holds 16 and the length multiplier only makes them longer (op-free
  manual-notes.md 5). Chain them odd then even (1 and 2, 3 and 4 ...) for white then purple.

## 11. Parameter pages, and the pages (`pages/`; the tumbler, build `galaxz-v4`; on the unit 2026-11-22: the page and recording work [unit])

- **The page on now** is one word, sequencer `+0x345e2c` (0-based). Tapping SHIFT adds 1 modulo the track's page count
  (`0x81112f5c`, a word a track; `0x8011ebb0`); choosing a track goes back to 0 [code]. What a page is: the kind at
  `0x811131cc` (6 bytes a track, -1 = none): 0 synth, 1 envelope, 2 LFO, 3 sends/pan/level, 4 arp, 5 drum, 7 tape. A kind's
  LED colour is at `0x811130cc`, its four parameters at `0x81112f3c` [code].
- **A dial's turn** arrives at `DefaultContext::onCC` (`0x8011ead0`): CC 1-4, value = the turn. CC 15 record, 16 play, 17 stop,
  38/39 -/+, 40 shift; value -1 = press [code; which is press is inferred from what the handlers do].
- **The dial LEDs** (40-43) are drawn by `0x8011d498`; the flash on a page turn is overlay 2 (`0x8003c768`). Both only take the
  eight palette colours, so a new colour is written with setLed.
- **Notes**: every key and MIDI note goes through `Sequencer::noteOn` (`0x8010dd0c`) and ends in `playNote` (`0x8010c894`: sequencer,
  track, key, note, note, velocity, length in 1/96 beats x 256 or -1 = held, layer, ...). At most 50 notes sound (`+0x68c`) [code].
- **The UI frame's rate**: the task calls `0x80110550` once per sequencer tick (96 a beat, running while stopped), and that makes the
  UI frame: 192 a second at 120 BPM, 64 at 40 [code]. This is the "no fixed rate" of section 2.
- **The app's state message has 2 bits for the page** (`0x801088f2`): the fifth page reads as the first over there [code].
- **The tumbler** (`0x80c30000`): page 5 of tracks 1-8, pink. Physics: TO-2's `Tombola`, fixed point, 256 steps a second, beside
  TO-2's own in `tools/test_pages.py`. Version 2 records: with REC on (`+0x1f`, or held `+0x1d`) and playing, the selected
  track's bounces go in through the OS's own `0x8010af78` (step and micro timing nearest the playhead) and `0x8011cd5c` (add
  a note to a step), each once the playhead is a tick past it, so it is not played twice [unit]. Hooks and tables: `patches/pages.json` (v4's, frozen: `patches/tumbler.json`).
- **EUCLID** (build `galaxz-v5`, page 6, teal; works on the unit, 2026-11-22 [unit]): runs on the UI frame's calls, one a tick (96 a beat, stopped
  too) [code]. Its grid starts at the first step's tick 0 after play (`+0x40` = tick, `+0x38` = step, `+0x3c` = length).
- **SHIFT alone**: `+0x14` is on while it is down on the normal screen; `+0x39c123` is 1 from its press until any other control
  (then letting go does not turn the page). MORE counts 2 s of that, and clears it. Keys do not clear it, so `noteOn`'s start
  (`0x8010dd0c`) is hooked too [code].
- **Recorded dials** live at `0x80c40000`-`0x80c7c000` (245,760 bytes: pattern, track, dial, step), memory nothing refers to [code,
  absence; in use on the unit since 2026-11-22], each dial's 16 filled before its first use; which are recorded is in the block. Lost at power-off.

## 12. USB host, and the MIDI switch (`usbhost/`, build `galaxz-v6`; works on the unit with a Motif 6, 2026-11-22 [unit])

- **Role**: the cable decides (the keyboard chip's USB-C controller reports it; `0x800279d8`: 0x22 host, 0x21 device). Nothing in the OS
  changes it from a key [code].
- **The host** is smxUSBH. A driver is found at `0x8000a3e0` (device, interface) by walking the list `0x080198ac`; the audio/MIDI one
  (ids at `0x119053e0`: class 1/1, 1/3; probe `0x80003ab8`) takes only class-1 interfaces. A device: `+0x64` vendor, `+0x66` product,
  `+0x74` configuration; interfaces 0x18 each (`+0` settings, `+8` how many, `+0x10` driver); a setting 0x18 (`+5` class, `+0xc`
  endpoints, `+0x10`/`+0x14` what follows it and its length); an endpoint 0x10 [code].
- **What older keyboards lack**: class 1 (the Motif says 0xFF; Linux has it as 0499:1005 with QUIRK_MIDI_YAMAHA: jacks named, ordinary
  packets), and the class-specific endpoint descriptor: the OS reads its port count at `0x80003a66` through a pointer it does not
  check, and copies descriptors by their own length into fixed buffers (`0x80003514`, `0x80003544`) [code].
- **Packets** are read at `0x8011ab60`; an event of another port than 1 ends the packet, an empty one is logged [code].
- **MIDI settings**: a byte at `0x819c2bb4`, midi.json's switches: 1 channel_one_to_active, 2 incoming, 4 outgoing, 8 clock in, 16 clock
  out, 32 alt program change, 64 echo, 128 program change. Everything the OS sends passes `0x80041a90`, which looks at it [code].
- **Keys**: CC 5 PROJECT (`+0x21`), 6 MIXER (`+0x26`), 7 TRACK (`+0x20`), 40 SHIFT (`+0x22`), 48 SCREEN (`+0x27`), 49 TEMPO (`+0x25`).
  Watching SCREEN's flag once a UI frame for two presses did not work on the unit [unit; why is not known];
  presses are now taken where the OS takes them, `0x8010b770` (sequencer, control, value: -1 = press), called from `0x8010ffd2` [code]. SCREEN + TEMPO twice keeps the MIDI settings open [code].
- **What the port wrote down** (`struct Report`): SHIFT + MIXER in HOST sends it as notes, `tools/usb_report.py` reads it. The Motif 6:
  0499:1005, class ff/00/ff, full speed, two bulk endpoints (out 01, in 81), jacks named, no class-specific endpoint descriptors; it
  sends on port 1, channel 1, with active sensing [unit, read on the Mac]. Its first connection worked only after events of every
  port were taken (v6's third build); whether that or the cable was what had failed before is not known.

## 13. MIDI in, and presets at start (`keys/`, `patches/keep-presets.json`, build `galaxz-v7`; works on the unit, 2026-11-22 [unit])

- **MIDI is taken** at `0x80110ef4` (sequencer task): note on calls `0x8010dd0c` at `0x80111090`, note off `0x8010e55c` at `0x801110ac` / `0x801110d8`
  (sequencer, channel, note, source, flags, 0), control change `0x8010fd48` at `0x8011103c`, pitch wheel `0x80107f68` at `0x80110f9c`. CC 120, 121
  and 123 end all notes there. CC 64 is nothing to the OS; CC 1 is P1 [code].
- **Pitch bend** goes to `0x801180dc` (synth `[0x11900000]`, track, Q31, 0); +-1 is +-200 cents (op-free param-paths) [code].
- **Channel 1 to the selected track** is looked at again when a key is let go: select another track meanwhile and the first one's note
  goes on [code]. keys/ remembers.
- **Presets**: the plug manager's boot reads `settings/plugs_patch.json` and deletes it (`0x80100894`); then TE's presets and the ones stored by
  hand are read, so those win (op-free presets.md) [code]. With the delete gone the file stays; `opz.py presets persist` writes it.

## 14. The load meter and more voices (`meter/`, build `galaxz-v8`; works on the unit, 2026-11-22)

- **What it reads**: the OS's own time of the instruments (`[FP - 0x20]` at `0x80118e40` in Synth::render), its notes cut off (the call of
  `0x8012d142` at `0x80119bc8`), and the audio callback, timed around it: the driver is given our routine instead of `0x8002325c` (the
  48-bit load at `0x800228bc`), called at `0x80031060` in the audio interrupt [code].
- **Against what**: 265,000 cycles a block for the instruments (the OS's line), 580,499 for everything (64 samples, 400 MHz; op-free
  cpu-budget). SHIFT + TEMPO, SHIFT + SCREEN; `tools/load_report.py` reads the figures on the Mac.
- **Voices** (`patches/more-voices.json`): counts per track at `0x815c7acc` (with generous_chords `0x815c7aec`), first records at
  `0x815c7b0c` (0 2 4 6 8 10 14 16), 22 records a layer, 44 in all, `0x17c` bytes each with the engine's state in them; read only by `0x8012d0ac` and
  `0x8012d1c4`. Lead 3 -> 4 and chord 4 -> 6 fill all the records there are; more would need the 44 moved. The line (`0x8110f5fc`) is as TE has it [code].
- **First reading, 2026-11-22**: played live, the peak light reached 11 of 16: the highest instrument block was 166,000-182,000 cycles, 63-69 % of the
  line, so 83,000-99,000 were left [unit, read by eye]. All audio work (the dials) and the settings played were not written down.
- **What is left, 2026-11-22**: our code and data take 0.32 of the 4 MB at `0x80C00000`; the pages cost ~4,000 cycles a UI frame idle and ~62,000
  with eight full tumblers and EUCLIDs (bfin-elf-run, no cache: 0.2 % and 3 % of the CPU at 120 BPM); parameter pages 6 of 6 (the table's
  rows), 50 KB engine slots 7 of 8, sound keys of the synth tracks 10 of 10.

## 15. The live layer's voices (`voices/`, build `galaxz-v9`; works on the unit, 2026-11-22)

- **Voice records**: 44 x `0x17c` at `0x0800452c` (L2, right before the FX's), + `0x10` track (0xff free), `0x14` plug, `0x18` blocks sounded, `0x34` level, `0x40` stage,
  `0x48` the engine's state. Layer 0 (pattern) 0-21, layer 1 (live) 22-43. Reached as base + number x `0x17c`, the numbers from `0x8012d0ac` (first) and
  `0x8012d1c4` (end); other loops over all 44: `0x8012d0d8` (made at start), `0x8012d10c` (all off), `0x8012d142` (overload) [code].
- **By number too**: an engine's 8 KB of its own, `0x8156fab8` + number x 8192, given to `init` (`0x8012d3e4`); 44 x 8 KB end at `0x815c7ab8`, where the OS's
  data goes on. More records without this would write over it [code].
- **Ours**: both number routines are replaced (only R0, R1, P0, P1 and CC may change: their callers keep R2, R3 and P2 across them). Layer 1 starts at 5,333,215,
  which + x `0x17c` lands at `0x80CC1030`; 40 records there, their 8 KB areas at `0x80CD0000`-`0x80D20000`. The 32-bit multiplies (`c271`, `ca71`) are integer, low
  32 bits: `0x80117852` multiplies `0x00808080` by a byte.
- **Overload**: as the OS's, over both layers. New: nothing fading and the instruments over 340,000 cycles -> the oldest live note is let go.

## 16. Telling the app (`tell/`, build `galaxz-v10`; its messages arrive [unit, 2026-11-22])

- **The app session** is `seq + 0x3463c0`: `+0x3c` the client id (-1: none; set from the hello, first byte high: 0x80114f16), `+0x34`/`+0x38` where its messages go, `+0x44`/`+0x48` when it
  was last heard (gone after 5 s). Looked after at `0x80113fac`, called at `0x80112a06` in the UI/sequencer task, every 20 ms (`0x8110e5b8`) [code].
- **A message out**: `0x80041eac` (`[0x81018320]`, bytes, length, id, from, from): TE's header, the bytes packed to 7 bits, sent like all MIDI [code].
- **Ours** is at `0x80d30000` (1,448 bytes), past the voices' areas; it reads the pages' state by address (`tell/where.h`, checked against `pages.json`).

## 17. The seventh page, and the chime (`pages/`, `chime/`, v11 on the unit 2026-11-22: starts, chimes [unit])

- **A seventh page is past its row** of the kinds (`0x811131cc`, 6 bytes a track): it reads the next track's first, `05 05 05 00 00 00 00 00` for tracks 1-8, valid kinds. Read
  at `0x8011d4ac` and `0x8011eff2` (after our hooks), `0x8011ebcc` (SHIFT; our fade hook has the colour) and `0x8011daa4` (the arp's, is it 4: 0). The page's own word has
  ten readers; none but the 2 bits of `$06` and the count (SHIFT `0x8011ebe4`, a track chosen `0x801258e0`, CC 102 `0x8010fe72`) cares how big it is [code].
- **GROOVE** goes by EUCLID's grid (96 ticks a beat). A progression's chord is the one of the beat; its root is at the key kept or within an octave under it; notes are
  brought back under 128 (a ninth over the top key was 129 until a test said so).
- **The mix** is handed on at `0x80023434` (`CALL 0x80117cd4`, R1 = 64 frames of interleaved stereo, 32 bits, full scale), after Synth::render, before USB out
  (`0x8002f944`) and the volume's ramp (`0x80023308`). The chime is added there: 2525 Hz, then 2475 Hz, a quarter second each, at 1/16 of full, 0.9 s after the sound
  begins. No loop registers, no calls; a load, a compare and a return when it is over.
- **TE's start sound** [unit: heard before ours with v11] is a sound of `samplepacks/sfx.aif`, played at one call, `0x8011a16c`, in main_task (`0x8002d3cc`) before the audio is
  started, if general.json's `disable_start_sound` (the byte `0x8110e524`, first of the general settings) is off. From v12 that call starts ours; the setting turns it off too.
- **Not settable from the app**: the OP-Z keeps that setting in `config/general.json` (content mode); no message that sets it was found. The app's switch is which build is
  installed.

## 18. SCREEN and a dial (`pages/`, build `galaxz-v14`)

- **SCREEN held** is `seq + 0x27` (set and cleared in `0x8010b770` on CC 48; the bit the OS's `$06` gives an app, `0x801088ac`).
- **It changes the screen**: `0x8010a29a`, called after every key, picks the screen on now (`seq + 0x3463bc`). SCREEN down, TEMPO up: the SCREEN screen,
  `seq + 0x3463b4` (or `+ 0x346258` when the byte `0x81113a60` is set); SCREEN + TEMPO (or the key's latched state `[0x0802ec0c]` = 3): the MIDI settings,
  `+ 0x3463b8`. The step screen is `+ 0x346260` (DefaultContext). Controls go to the screen's vtable + 8 (`0x80110030`) [code].
- **The SCREEN screen's onCC** (`0x8011e516`, vtable `0x81113074`) sends dials 1-4 out as CC 105-108 on channel 16, 1 a click one way, 127 the other
  (`0x800422d0`); nothing reaches the sound or DefaultContext. The green bar on the track keys while SCREEN is down is that screen's [unit, 2026-11-24].
- **v14's first build** hooked DefaultContext's dial cases for this and so never ran [unit]. **Its second** takes the blue dial at `0x8011e516`
  (`_hook_screen`, a JUMP.L over `R0 = R2; R0 += -1`): 4 clicks a page, a page at a time within the track's count (`0x81112f5c`), round at both ends,
  written to `+0x345e2c` as the OS's own CC 102 does (`0x801101cc`). When SCREEN is let go the page flashes: overlay 2 (`0x8003c60c`: `[0x81015e9c]`, 2,
  500 ms, the page, the kind's colour from `0x811130cc` by `0x811131cc`), as SHIFT starts it (`0x8011ec40`). The other dials go on as TE has them.
