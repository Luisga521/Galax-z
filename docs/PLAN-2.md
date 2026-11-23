# Galax-z 2: the plan

On `main` since 2026-11-22. What is confirmed and what is not: [STATUS.md](STATUS.md). What is left of it is in [WORTH-DOING.md](WORTH-DOING.md).

What was asked for on 2026-11-22, what each rests on, and where it is. [unit] seen on the OP-Z, [code] read in its OS, [guess] neither.

| Part | How | Where it is |
|---|---|---|
| Tight picture | The count is held to what sounds, hits are drawn on the beat, frames for when they are seen | **done**, measured against a simulated and a virtual OP-Z; the unit's own figures: LINK CHECK, SAVE |
| One Settings | GENERAL, LEARN, GALAX-Z OS | **done** |
| Mixer, mutes, sounds, patterns by touch | CC 50, 53, 1-18, 103 [code, TE's manual] | **done in the app**; not tried on the unit. CC 53 (127/0) sets and clears the pattern's mute, CC 50 the gain, and the OP-Z says so in `$02` and `$12` [unit, 2026-11-22: a self test of ours ran on it by mistake; one can no longer] |
| PLAY: every track under the fingers | Notes on channel 1-16 (lead heard [unit], the others [guess]); chords, scales, hold, drone, groove from TO-2 | **done in the app** |
| PERFORM: a bay and a gallery | 35 moves over MIDI, all put back | **done in the app**. Sound values are smoothed some 93 ms by the OS [code]: fast moves on them will be softer than on gain |
| LEARN | Any controller; relative knobs, pick-up | **done**; not tried with a real MiniLab |
| SCREEN + first dial | `$06` byte 2 bit 5 [code] and the dial's own value | **done in the app**; not tried. The OP-Z may move the sound's first value too: if it does, a later version takes the turn instead |
| Vocal chops on the app | MODULE (track 14) is a MIDI lane: its notes play chops in the app; sources: this device's mic, the OP-Z over USB, any file; TO-2's slicer (Chopper.swift, pure) and CHOP (bloom, mutate, tail) | **done in the app**: CHOPS page, kits, 12 effects, MODULE's notes and CCs 1-8 (its dials send those numbers: `$10` [unit]), all against the virtual OP-Z. Recording from a microphone or the OP-Z's cable is not tried |
| Chops on the OP-Z | A pack of 24 slices (AIFF, 12 s, as the piano's) uploaded by the file service, read back, removable | after that; a write to the unit: when its owner says so |
| A chop engine on the OP-Z, its mic in it | An engine that reads a pack: some ten voices fit [guess from the piano's 116-141 cycles]; recording needs a tap in the mix, an instrument does not hear the mic [code] | firmware, not begun |
| MASTER as the chop track | An effect there writes to address 0 and restarts the unit [code]: only its notes and page can be taken over, not its sound slot | open: MODULE first |
| LIGHTS (DMX) as the perform lane | Its notes on channel 15 begin moves, so they are in the pattern; the 16 step LEDs are already its own | **done in the app** (PERFORM, LIGHTS: PLAYS; off until chosen); its LEDs not begun |
| MODULE button | The chops' track; 16 CCs (its 4 pages) are the chops' dials, with parameter locks | with the chops |
| Effects on the OP-Z | One plug a FX track; 15 from op-free and OTT; load, take off (another plug), upload, remove, read back | not begun; uploading is a write to the unit |
| Per-track inserts, Perform with sound of its own | The OS has none [code] | firmware research |
| The GROOVE page (SHIFT, the seventh) and the Quindar tones | firmware v11 to v13 | **v11 works on the unit**; v12 and v13 are on it, not reported point by point |

**Never sent**: `$02` (refused from an app [code]), `$06` (it writes the held keys), `$0E` for a track over 15 and `$09` (no bounds in the OS).
