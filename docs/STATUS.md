# Status: confirmed or not

A work in progress. Bugs that are known: [KNOWN-ISSUES.md](KNOWN-ISSUES.md).

As of 2026-11-22, one OP-Z, TE's OS 1.2.45. **Unit** means seen on it. "It works" was often said of a whole version and not of each point.
When you confirm something on yours, open a unit report.

## Galax-z OS

| Version | What | On the unit | Not confirmed |
|---|---|---|---|
| v1 | Debounce | Boots, keys good | The values are placeholders (+15) |
| v2 | Boot animations | Galaxy and others play after the start | Not all sixteen patterns were looked at |
| v3 | A/B bars | Seen white and purple | The moment of the change, point by point |
| v4 | Tumbler, recorded | Yes | Each dial and button one by one |
| v5 | EUCLID, MORE, recorded dials | Yes | The same. Recorded dials are lost at power-off, by design |
| v6 | Older USB keyboards, HOST / INSTRUMENT | Yes, with a Motif 6 | Any other keyboard |
| v7 | Pedal, wheel, presets that stay | Yes | The same |
| v8 | Load meter | Yes, shows on the keys | Sending the figures (SHIFT + SCREEN) |
| v9 | Live voices | Yes | Load with very many held notes |
| v10 | Tells the app | Yes: its messages arrive as read | That the picture is right, ball by ball |
| v11 | GROOVE, two tones at power-on | Yes: "it works", the tones heard after TE's start sound | Each dial, groove and progression |
| v12 | The tones in place of TE's start sound | Written, read back identical, starts | What is heard |
| v13 | GROOVE in light green; the signed release | Written, read back identical | How it starts, the colour |
| quiet builds | v11 to v13 without the tones | Never installed | All of it |

A patch record's own status line may say less than this table: records are not touched once a version is out. **v13** is the signed release (2026-11-22),
and makes byte for byte the image on the unit; v9's is kept beside it. v10 to v12 and the quiet builds are in the app and in `Firmware/builds/`.

| Engine | On the unit | Not confirmed |
|---|---|---|
| Piano v2 | Installed, works | How its sound was judged, point by point |
| OTT | Installed, works | The same |

## The app

| | State |
|---|---|
| Screen over USB and Bluetooth | Unit: panel, playhead, edits and v10's messages arrive as read. No MIDI clock comes from the OP-Z |
| Pairing list opening by itself | Not confirmed |
| Hub: read, install, go back | Unit, on a Mac; every failure path against a fake update port |
| Backups | Unit, read only; checksums of two sets matched |
| The OP-Z's sound through the device | Mac: with a silent virtual device. iPad and iPhone: never run with an OP-Z |
| Kick strikes on TRACK | Cause seen on the unit (its kick sends on channel 16), fixed in the app; not reported back yet |
| Tight picture over USB | Against a simulated OP-Z, 25 → 8 ms; the feel on the unit not reported |
| Touch: volume, mutes | The OP-Z takes both and says so (unit). Sends, pan, dials, patterns: virtual OP-Z only |
| PLAY, PERFORM, LEARN, SCREEN + first dial | Virtual OP-Z only; no real controller tried |
| CHOPS, MODULE as its lane, LIGHTS as PERFORM's | Virtual OP-Z only |
| Recording into CHOPS, from a microphone or the cable | Not tried |
| Settings › Credits | Builds, and the notices are in the package; not looked at on a screen |
| Frame rate | 119–120 fps on a 120 Hz Mac display, 13–22 % of a core (before PLAY, CHOPS and PERFORM) |
| iPad, iPhone | Installed and run on the author's only; no App Store, no TestFlight |

## Going back

| Way | State |
|---|---|
| Writing the original over a changed OS in update mode | Unit: the original written over itself, and it booted. Written over a changed OS too, as a step between two builds; whether it was started from there was not noted. Builds written over each other many times |
| TE's own `.zfw` over a broken OS | Never tried |
| Factory reset | Never tried |

## Asked for, not built

Uploading chops to the OP-Z, an engine that plays them there, an effects library, lights for the perform lane: [PLAN-2.md](PLAN-2.md).
