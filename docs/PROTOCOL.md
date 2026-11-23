# What the OP-Z tells a StateSync replica (OS 1.2.45)

For the screen, beyond op-free's `research/patterns.md` §5 (hello, bank, acks, `$0E`, `$07`, `$0C`). Labels: **[code]** read in the OS,
**[unit]** checked against bytes a unit sent (312 edits, 2026-11-21).

## `$02`: edits, as they are made

Records one after another, until the payload ends: `u16` timestamp (counts up by one; a gap means one was lost) · `u16` offset ·
`u8` pattern address (project × 16 + pattern) · `u8` length · `u8` type · data [unit].

| Type | Data | Means |
|---|---|---|
| 0 | bytes | written at the offset of the pattern's 21,392 bytes [unit] |
| 5 | track, step, flag | the step's notes are taken out (each note byte becomes `ff`) [unit] |
| 2 | none | the whole pattern became another: ask for the bank [unit, code 0x8011391c] |
| 1, 3, 4, 6 | | a track, step or sound copied over: ask for the bank [code 0x8011384c, 0x801139b4, 0x80113a60, 0x80113bbc] |

A knob's value does not come this way but as `$0E`. Galax-z makes types 0 and 5 in its copy at once and asks for the bank only on the
others or a gap. (Before, every edit fetched 342 KB again: 0.15–0.6 s.)

## The panel [code]

| Message | Bytes | What |
|---|---|---|
| `$03` | 2 | octave of the selected track; bits 0–3 **selected track**, bit 4 **playing** (0x80108a48, applied at 0x8010983c) |
| `$05` | 17 | where each of the 16 tracks is: the step in bits 4–7, the sixteenths within it in bits 0–3; byte 16 bits 0–3 the pattern's sixteenth (0x8011762a, 0x80108f74). **Sent at a start and each time the pattern comes round, not at every step** (the flag is set at 0x80107ec8 and 0x801109f8 only) |
| `$06` | 4 | byte 0 bits 6–7 the parameter page, 0–5 the screen's own state; byte 1 bits 0–4 the step held (31: none), bit 5 SHIFT; byte 2 bit 7 recording (0x801087e6, 0x80107a44) |
| `$12` | 18 | the mixer's gain of each track (255: full; what the OS gives its track gain, 0x80108644), and 2 bytes not read yet (0x80107a08) |
| `$04` `$13` `$1b` | 4 | synth, pattern and meter state; not used yet (0x80108a9e, 0x80108c6c, 0x80108ec0) |

When they are sent [code]: a start sends `$03` and `$05` (0x80107e9c), a stop `$03` (0x8010c2dc), selecting a track `$03` (0x80109800), a
pattern coming round `$05` (0x80110774); `$06` `$12` whenever they changed, looked at in the OP-Z's own loop (0x80113c68). Only to a
connected replica (`+0x54afc`).

**Between two `$05` a replica counts for itself**, as the OS does (0x801106e6, 0x8010a5a4): 24 ticks a sixteenth; at each sixteenth a
track's low bits go up, and after its step length (track record + 6: 0 and 10 count as 1, 9 as 16) the step goes on, wrapping at its step
count. `Playhead` does this on the OP-Z's MIDI clock if it comes (6 a sixteenth), else on the tempo; `StageTests` holds it to the OS's
counting over random lengths and counts.

They arrive as read [unit, 2026-11-22, over Bluetooth]; no MIDI clock comes. If `$03` does not come, MIDI start and stop stand in.

## The pink and teal pages: `$70` `$71` (Galax-z OS v10's own, `Firmware/tell/`; they arrive [unit, 2026-11-22])

Sent through the OS's routine (0x80041eac) from its 20 ms look after the session, only while the session's client id is 0x4242 (op-free's and
Galax-z's; TE's app gets nothing). `$70` when it changed (at most 13 a second) and every second; `$71` 17 a second while the track has balls, at each step (at most 25 a second) while only its EUCLID runs.

| Message | Bytes | What |
|---|---|---|
| `$70` | 20 + 4 a ring | 0 version 1 · 1 parameter page 0–5 · 2 track · 3 tracks with balls · 4 tracks with EUCLID notes · 5 bit 0 MORE, bit 1 waiting for the first step · 6 the ring the dials turn · 7 rings · 8–19 the track's dials now (GRAVITY BOUNCE SPIN SCATTER STEPS PULSES ROTATE RATE GATE ACCENT CHANCE OCTAVES) · a ring: key, steps, pulses, rotation |
| `$71` | 8 + 6 a ball | 0 track · 1 balls · 2–3 the hexagon's turn (65536 = once round) · 4–7 EUCLID's steps since it started · a ball: x, y (128 = 1.0), vx, vy (16 = 1.0), note, flash |

Between two `$71` the app goes on with the same physics (`Tombola`). Without them (v9 and older) FX shows the effects only.

**Mutes** (in the pattern, so they come with `$02`): two bits a track in the active mute group's word at 21,344. 2: muted, its notes are
not played. 1: audio mute, its notes go on and its sound does not (0x80108528, 0x80108644, 0x8010d0c6) [code]; 2 is in the author's own
projects [data].

## The GROOVE page: `$72` (v11; red there, light green from v13; v11 works on the unit, this message was not looked at by itself)

12 bytes + 1 a note: track · notes kept · bit 0 MORE, bit 1 waiting · the groove's step (255 none) · its eight dials (GROOVE RATE GATE ORDER PROGRESSION KEY LENGTH SWING) ·
the notes. While the red page is on or the selected track's groove has notes: when it changed (13 a second at most), at each step (25), and every second.

## MIDI settings: `$0F` asks, `$10` answers [unit, 2026-11-22]

292 bytes, zlib: 16 track switches, 16 track channels (0-15), 16 x 16 parameter CCs (1-16 as made), flags (1 channel 1 to the selected track, 2 in, 4 out, 8 clock in,
16 clock out, 32 alt program change, 64 echo, 128 program change), 3 of padding. On that unit: every track on, **the kick on channel 16** (as motion is), the others on their own,
flags 0x97. That is why the kick never struck on the screen: the app took channel 1 for it. Notes go out inside `playNote` (0x8010ca7a), on the table's channel
(0x8003f7f0) [code], so EUCLID's and the tumbler's do too.
