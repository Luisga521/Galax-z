# Whose is what

Whose each part is. [`REUSE.toml`](REUSE.toml) says the same file by file (`uvx --from "reuse[charset-normalizer]" reuse lint` checks that none is left out); the notices
themselves are in [THIRD_PARTY.md](THIRD_PARTY.md). Anything from OP-FREE in the app sits in a folder called **`OPFree`**; the other files
that follow it in part say so in their first lines.

"Galax-z's own" means Luis Tosado's, written with Claude ([DISCLAIMER.md](DISCLAIMER.md#who-made-this-and-who-did-not)).

## Galax-z's own (MIT)

| | Where |
|---|---|
| The app: screens, hub, settings, sound, backups | `App/` |
| The dot matrix, its type, its motion | `Packages/GalaxzKit/Sources/DotKit` |
| Every page and its drawing | `…/OPZStage` |
| Playing: chords, grooves, moves, learning; the sampler and its effects | `…/OPZPlay`, `…/ChopKit` |
| Live edits, the playhead, panel state, the tumbler and EUCLID in the app, key test, load report | `…/OPZModel`, but not `OPFree` |
| CoreMIDI, Bluetooth, link check | `…/OPZLink`, but not `OPFree` |
| Images, animations, catalogue, signed releases, serial port | `…/OPZFirmware` |
| Patches and their code: boot animations, A/B bars, tumbler, EUCLID, GROOVE, USB host, keys, meter, voices, tell, chime | `Firmware/` `galaxy` `ab` `pages` `usbhost` `keys` `meter` `voices` `tell` `chime` `walker` `patches` `builds` |
| Reading images, building blocks, the simulators' benches, the fake console | `Firmware/tools/` |
| The piano's player, its codec and pack builder; OTT's compressor | `Firmware/engines/` |
| What was found out here: LEDs, debounce, the write command, panel messages, voices, MIDI in | `Firmware/notes/`, `docs/` |
| The look, the icon, the pictures | `App/Assets.xcassets`, `Tools/icon`, `docs/screens` |

The tumbler, EUCLID, the grooves, the progressions, the slicer, the sung voice and the look come from **TO-2**, Luis Tosado's too; files taken from it say so.

## Theirs: [OP-FREE](https://github.com/mutlisensor/op-free) (MIT, Lourens Smit and the op-z-engines contributors)

| Here | What of theirs |
|---|---|
| `…/OPZLink/OPFree/SysEx.swift` | A Swift port of `core/src/sysex.ts` |
| `…/OPZLink/OPFree/StateSync.swift` | After `core/src/session.ts` and `research/patterns.md` |
| `…/OPZLink/OPFree/FileClient.swift` | After `FileSession.pull` in `core/src/session.ts` |
| `…/OPZModel/OPFree/Bank.swift` | A Swift port of the read side of `core/src/project.ts` |
| `…/OPZModel/Resources/OPFree/engines.json` | Its engine catalogue: names, knobs, presets, short help |
| `…/OPZLink/Resources/OPFree/demo-session.json`, `Fixtures/statesync-vector.json`, `Fixtures/file-session.json` | Recorded from its fake OP-Z. The demo song is Galax-z's |

## Both

Galax-z's, after theirs in part. How much was looked at line by line against OP-FREE on 2026-11-22.

| Here | What is theirs in it |
|---|---|
| `Firmware/tools/flash.py` | Framing and port reading follow `opz_os_read.py` (37 of 349 lines are the same); the write side is Galax-z's. `UpdateConsole.swift` is its port |
| `Firmware/tools/patch.py`, the records | Their draft record format; code blocks in it are Galax-z's. `Patch.swift` is its port |
| `Firmware/engines/ott/ott.c` | The engine's frame is their SDK's (22 of 132 lines as in their `glue`) |
| `Firmware/engines/piano/piano.c` | The engine's frame is their SDK's (about 22 of 435 lines) |
| `*.engine` | Built with their SDK headers and tools, which are not here |
| `Firmware/engines/piano/install_piano.py` | Uses their `opz.py` and follows its steps |
| `Firmware/engines/*/tests` | Their scenario format; the tests are Galax-z's |
| `Tools/fixtures/make-fixtures.mjs` | `vectorProject()` is their test's |
| Notes and protocol | Where they say "op-free", that part was found by OP-FREE |

## Theirs: others

| Here | Whose |
|---|---|
| `Firmware/engines/piano/opzk_piano.aif` | Made from the **Salamander Grand Piano V3** by Alexander Holm, **CC BY 3.0**. The recordings are Holm's; the cutting and encoding are Galax-z's, under the same licence |
| The 81 edits' `expected` bytes in `Firmware/patches/`, 620 in all (262 without repeats), and the same inside `Releases/*.galaxz` | **teenage engineering**'s code, only as much as a patch needs to know it is in the right place. Not licensed here. Addresses and function names in the notes are facts about their OS |
| OP-Z, OP-1 | teenage engineering's trademarks |

## If you fork

Keep both notices, MIT and CC BY. Add your own line beside them, not over them. New file after somebody's work? Put it in a folder of that
name, or say so in its first lines, and add it here and in `REUSE.toml`.
