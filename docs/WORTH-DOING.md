# Worth doing, not worth doing

Where time is best put next, and what was tried, weighed or read out of the question. It is an opinion, with the evidence beside it, so you can
disagree with a reason. Take anything on the first two lists: it is yours. Labels are those of [DISCLAIMER.md](../DISCLAIMER.md#what-works-means-here). All of it is OS 1.2.45 on one unit, up to 2026-11-22.

## The short version

1. **The app is where the best return is.** Plain MIDI reaches a great deal of the OP-Z, and nothing is flashed.
2. **Sound: write engines, not patches.** [OP-FREE](https://github.com/mutlisensor/op-free) installs them without flashing.
3. **Patch the OS only for what neither can do**: parameter pages, LEDs, keys, MIDI in, voices.
4. **The most useful thing anybody can give is a second unit's report.**

## Worth doing now

Cheap and useful. Mind the risk column.

| What | Why it is worth it | Effort | Risk |
|---|---|---|---|
| **Try it on a second OP-Z and report** | Everything here rests on one unit | An evening | Real if you flash, none for the app |
| **Measure the load**: play hard for 3–5 minutes with both FX, then SHIFT + SCREEN | One reading exists: 63–69 % of the OS's limit, FX not in it [unit]. Every idea below about voices needs this number | Minutes | None (v8+) |
| **Real debounce values** | +15 is a placeholder, and that the unit is ms is not confirmed. KEY TEST measures it | An hour | Low |
| **Find TRACK among LEDs 44–50** | Play the *Key check* animation and look. 44 is a guess | Minutes | Low |
| **Confirm v10 to v13 point by point**: do the app's balls and rings match, each GROOVE dial, the tones, the light green | They start and "it works"; the points have not been written down | Minutes | Real |
| **Try the app's playing on a unit**: PLAY, PERFORM, LEARN, SCREEN + first dial, CHOPS from MODULE, recording | All built, all tested against a virtual OP-Z. Volume and mute are seen on a unit, the rest are not | An evening | Low |
| **Run the iPad's and iPhone's sound path** with a cable | Built, never run with an OP-Z | Minutes | None |
| **Retry and read back when installing a plug** | The registration was dropped twice with no error | Small | Low |
| **Flash from Linux** ([PORTING.md](PORTING.md)) | `flash.py` is Python and looks for one port name, `/dev/cu.usbmodem*`. Windows needs its own | Small | Test on the fake port |
| **Notarizing the Mac app** | Without it people meet Gatekeeper. `NOTARY_PROFILE` in `Tools/package-mac.sh` does it, with an Apple account | Small | None |

## Worth doing, with time

| What | What we know |
|---|---|
| **32 steps, as a view** | Two patterns in a chain already play as one. Show them as 32 steps in the app, then a button that makes the chain. Keeping the sounds of both alike needs writes |
| **More moves for PERFORM** | Plain MIDI, in `OPZPlay/Perform.swift`. The OS smooths sound values by some 93 ms [code], so fast moves belong on gain |
| **Chops on the OP-Z itself** | A pack of 24 slices (12 s), read by an engine as the piano's is; some ten voices should fit [guess]. The app's sampler on MODULE is the model |
| **An effects library** | Load, take off, upload, remove, read back: one plug a FX track. Asked for in [PLAN-2.md](PLAN-2.md), not built |
| **A switch for the start tones** | `disable_start_sound` lives in `config/general.json` (content mode); no message that sets it was found. Today the switch is which build you install |
| **Windows and Linux** | Being worked towards, help wanted: [PORTING.md](PORTING.md). Five modules need nothing of Apple's; a window, a GPU pass and MIDI are what each system needs |
| **LED colours** | The palette is sixteen 4-byte entries of data at `0x81015fec` [code]. No code at all. Never built. Only the top row and the encoders have colour [unit] |
| **More boot animations** | Data in a player that is already proven. The hub has an editor |
| **A looper** | The 4 MB we used 0.32 of (v7) would hold some 44 s of mono. Only the parts our blocks use are proven free |
| **More pattern voices** | Like v9's live ones, but the pattern layer's 22 records have to move |
| **More sequencers** (TO-2's GARDEN and the like) | Cheap in CPU: the tumbler and EUCLID cost about 0.2 % idle and 3 % at the extreme (simulated, could be twice that) |

## Not worth doing

| What | Why not | Instead |
|---|---|---|
| **True 32-step patterns** | The step is 4 bits, 16 slots a track; 23 places use the position and 33 the size [code] | Chain two patterns |
| **An effect on MASTER** | It is called with no output buffer and would restart the unit [code] | FX1 or FX2; or an engine with an in-place mode, tested offline first |
| **Per-track inserts** | The OS has none; it has one plug a FX track [code] | An FX track with its dry level at 0 |
| **An engine that hears the microphone** | It reaches FX, not instruments [code]. It needs a tap in the mix | Record in the app |
| **Processing audio on PERFORM** | That track processes none [code] | Moves over MIDI |
| **Raising the overload limit** before measuring | 265,000 cycles a block is TE's line; the block is 580,499. OP-FREE's unit hung after minutes at an estimated 190,000, with both FX running; why was never proven | Measure, then voices |
| **Several engines as big as the piano** | 7 of 8 large slots were used on that unit, and one piano voice is about 3 % of the limit | One big one, many small |
| **Colour on the lower two rows** | Their LEDs are white only [unit] | The top row and the dials |
| **120 fps on the keys** | About 26 LEDs fit a message, always from LED 0. 60 changes a second, sent twice, is what worked [unit] | 60, full or off |
| **Lights during the boot itself** | Our player there showed nothing [unit]; whether it ran is not known | The first 4 s after it |
| **Flashing from iPad or iPhone** | An app cannot open the update-mode serial port | Mac now, Linux next |
| **Bluetooth on the Mac** | It took the OP-Z from the iPad | A cable |
| **Automatic backups over Bluetooth** | 3.4 MB takes minutes and holds up everything else | USB, by choice |
| **Fetching the project again at each edit** | 342 KB, 0.15–0.6 s. `$02` is decoded: 312 of 312 recorded edits | Apply the edit |
| **Waiting for `$05` at each step** | It comes at a start and once a pattern | Count, as `Playhead` does |
| **Double-tap gestures on SCREEN** | Watched once a UI frame it did not work [unit] | Take presses where the OS does (`0x8010b770`), with SHIFT |
| **Touching the keyboard or Bluetooth chip** | No way back, and nothing above needs it | |
| **Guessing addresses for another OS version** | Every one would have to be read again | Stay on 1.2.45 |

## Room left

On the one unit, 2026-11-22. Yours differs with what you installed.

| | Used | Of | |
|---|---|---|---|
| Parameter pages, tracks 1–8 | 7 | 7 | the seventh already reads past its row of the table and gets away with it; an eighth needs the table moved |
| Sound keys on bass, lead, arp, chord, FX1, FX2 | 10 | 10 | full |
| Engine slots: small / medium / large | 19 / 21 / 7 | 32 / 50 / 8 | large is nearly full |
| Sounds registered | 75 | 200 | plenty |
| Memory at `0x80C00000` | 0.32 MB at v7; blocks now reach `0x80D4` | 4 MB | plenty, but only what runs there is proven |
| Audio, instruments, peak | 63–69 % | the OS's limit | one reading, by eye |

## Dead ends, so you need not walk them

- **The kick would not animate.** Not the app's fault: that unit's kick sends on MIDI channel 16. The app now asks the OP-Z for its channels (`$0F` / `$10`).
- **The galaxy ran scrambled** at first: the OS's key table is white keys first, then black, not in pitch order.
- **The Motif 6** stayed silent for two builds and spoke on the third, when events of every port were taken. Whether that or the cable had been it, nobody knows.
- **Building for iPad then iPhone in one folder** rewrites `Assets.car` and does not sign again. `deploy-ipad.sh` starts clean and checks.
- **A Mac app that reads a guarded folder at launch** waits with no window for a question nobody sees.
- **Blackfin**: the assembler refuses `.equ` expressions in some operands; GCC needs `--with-system-zlib` on newer macOS; avoid hardware loops in hooks.
