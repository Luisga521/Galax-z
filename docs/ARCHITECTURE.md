# How the app is made

Each part depends only on the ones above it. All but the last two know nothing of Apple's UI frameworks, so other platforms can use them.

```
OPZModel     the OP-Z's formats: pattern bank, live edits, panel state, settings files, OP-FREE's engine catalogue
DotKit       a matrix of lights to draw on, its type, its motion
OPZPlay      playing it: chords, grooves, performance moves, learned controllers. Events in, MIDI commands out
ChopKit      the sampler: a source cut up, played, twelve effects. Samples in, samples out
OPZStage     the screens, drawn on it: TRACK GRID MIX PLAY CHOPS PERFORM FX SONG NOTES LOAD SKY, a look for each kind of engine
OPZFirmware  OS images, patch records, signed releases, the strict update-mode writer
OPZLink      SysEx, the StateSync replica, the file service, CoreMIDI, Bluetooth, the demo OP-Z
App          the Metal view that shows the dots, the hub, settings
```

## How it talks to the OP-Z

TE's app is a StateSync replica (OP-FREE `research/patterns.md` §5). Galax-z does the same. Bytes: [PROTOCOL.md](PROTOCOL.md).

| What | How | Galax-z |
|---|---|---|
| Read the open project | StateSync bank: 16 patterns × 21,392 bytes in parts, each acked with `$0B` | yes |
| Follow every edit | `$02`, made in the app's copy at once; the bank is fetched again only when an edit cannot be made that way | yes |
| Follow the panel | `$03` `$05` `$06` `$12`: track, playhead, page, held step, SHIFT, levels; the app counts between messages as the OS does | yes |
| Name every sound and slot | file service: `plugs.json`, `slotConfiguration.json` | yes |
| Back up projects | file service, ids 3–12, read only | yes |
| Ask for its MIDI settings | `$0F`, answered by `$10`: which channel each track is on | yes |
| Play it, mix it, select patterns | plain MIDI on those channels: notes, CC 1–18, 50, 53, 103 | yes, only while you touch |
| Set a sound, push patterns | `$0E`, `$09` / `$0A` (RAM only) | known, not used |

Close TE's app meanwhile: two clients on one session break both. With no cable in, the iPad looks for the OP-Z over Bluetooth by itself
(CoreBluetooth, then `MIDIBluetoothDriverActivateAllConnections` hands the link to CoreMIDI); **PAIR BY HAND** opens Apple's list.

## How it stays fast

- A page is drawn by the CPU into a small matrix (about 360 × 240): **0.02–0.1 ms a frame**, nothing allocated per dot.
- The GPU uploads that, adds afterglow and glow at one texel a dot, and draws the round lights in one pass.
- A still picture is not redrawn; with nothing playing it drifts at 30 a second; covered, it stops.
- An edit on the OP-Z is made in the app's copy of the project (a few bytes) instead of reading 342 KB again.

## The hub (Settings › GALAX-Z OS)

It puts an OS on the OP-Z over USB in update mode, on a Mac: only there can an app open the update-mode serial port. The iPad shows the same
without installing.

- Builds are `Firmware/builds/*.json` over `Firmware/patches/*.json`, shipped in the app; a test fails if the copies drift.
- The writer is a Swift port of `Firmware/tools/flash.py`, with the same fixed frames, refusals and fake-console tests; both build Galax-z v1
  byte for byte alike.
- It reads `os.ldr` off the unit, or rebuilds TE's original from any Galax-z build on it, and keeps it in
  `~/Library/Application Support/Galax-z/`. Before every write it saves what was installed, with the log, in `Backups/os/`.
- New versions are signed files ([RELEASING.md](RELEASING.md)).

## Backups

On demand, or at every USB connection if AUTOMATIC is on (off by default), the ten projects as last saved and the sound settings are copied,
reading only, into `Documents/Backups/content/<time>/`, laid out like the OP-Z's disk. An unchanged OP-Z only marks the newest as checked; the
newest 30 are kept. Putting one back is a copy in content mode.

## Rules it was built by

- An original look in teenage engineering's spirit: none of their artwork, fonts or code.
- Every write to an OP-Z is backed up, shown, confirmed, verified by reading back, and rolled back if it fails.
- A self test can only ever meet a virtual OP-Z.
