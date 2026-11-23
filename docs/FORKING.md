# Forking Galax-z

You do not need to ask. Fork it, rename it, take one part of it, sell what you build: [MIT](../LICENSE). Keep [THIRD_PARTY.md](../THIRD_PARTY.md) with it; [OWNERSHIP.md](../OWNERSHIP.md) says whose each part is.

## Pick what you want to take over

| You want | Take | Leave |
|---|---|---|
| Only the screen | `App/`, `Packages/GalaxzKit` | `Firmware/`, `Releases/` |
| Only the OS patches | `Firmware/`: Python, no Xcode needed | `App/` |
| A port to Linux or Windows | `OPZModel`, `DotKit`, `OPZPlay`, `ChopKit`, `OPZStage`, `OPZFirmware` | Metal, CoreMIDI |
| Only the piano or OTT | `Firmware/engines/`, with [OP-FREE](https://github.com/mutlisensor/op-free)'s SDK | the rest |
| Only what we found out | `Firmware/notes/`, [PROTOCOL.md](PROTOCOL.md) | the rest |

## Five things to change first

Until you do, your app asks **this** repository for updates and trusts **its** key.

| What | Where | To |
|---|---|---|
| 1. **Where updates come from** | `ReleaseFeed.defaultURL`, `Packages/GalaxzKit/Sources/OPZFirmware/Release.swift` | your repository |
| 2. **Who may sign them** | `Packages/GalaxzKit/Sources/OPZFirmware/ReleaseKeys.swift` | your public key: `swift run galaxz-release keygen` ([RELEASING.md](RELEASING.md)) |
| 3. **Who you are to Apple** | nothing in the code: `git config galaxz.team <your team>` and `git config galaxz.id <your.app.id>`, which the scripts pass on (in Xcode: `DEVELOPMENT_TEAM`, `GALAXZ_ID`); `git config galaxz.byline "by …"` puts your name on the start screen in place of "by Luis Tosado". For a published fork change `org.galax-z` in `project.yml` and `App/` too, then `xcodegen` | your team and your ids |
| 4. **The iPad** | nothing in the code | `./deploy-ipad.sh <udid>`, or once `git config galaxz.ipad <udid>` |
| 5. **The name and the numbers** | the app's name and its byline (`GALAXZ_BYLINE` in `project.yml`); `galaxz-vN` is how a release and a build are named (`Release.swift`, `Catalog.swift`) | your own name. **Please do not publish another "Galax-z v14"**: two different images under one name is how somebody writes the wrong one |

The signing key here is not handed on. A fork with its own key is safer for everybody.

## The first day

```bash
git clone https://github.com/<you>/<your-fork> && cd <your-fork>
(cd Packages/GalaxzKit && swift test)                       # 137 tests; two need your own os.ldr and skip without it
for t in Firmware/tools/test_*.py; do python3 -I $t; done   # what needs the Blackfin tools skips itself
Tools/package-mac.sh                                        # the Mac app; no Apple account needed
open build/Galax-z.app                                      # Settings › DEMO OP-Z
```

A fresh clone does all four with nothing else on it (checked 2026-11-22, Xcode 27.2, macOS).

Then read, in this order: [SAFETY.md](SAFETY.md), [STATUS.md](STATUS.md), [WORTH-DOING.md](WORTH-DOING.md), and for patches the
[device guide](../Firmware/notes/device-guide.md).

Tests on GitHub are written and switched off. To switch them on: `git mv .github/workflows.off .github/workflows`.

## Adding a patch to the OS

1. Find the place in **your own** `os.ldr` (`Firmware/tools/ldr.py` reads and disassembles it). Write down the evidence.
2. Write a record in `Firmware/patches/`: address, the bytes expected, the new bytes, why, the risk, how to revert. Status **DRAFT**: a draft
   cannot be flashed.
3. Code goes in a block of its own in `0x80C00000`–`0x80FFFFFF`, one range a feature. Taken so far: walker `80C0`, galaxy `80C1`, A/B bars
   `80C2`, pages `80C3`–`80C7`, USB host `80C9`, keys `80CA`, meter `80CB`, voices `80CC`–`80D2`, tell `80D3`, chime `80D4`. `patch.py` refuses overlaps.
4. Test it off the OP-Z: the Blackfin simulator, `bfin_mini.py`, the fake console. No test, no flash.
5. A new build in `Firmware/builds/`. **Never edit a record that is out**: a version's records are frozen, make a new one.
6. `Tools/sync-firmware.sh`, then the tests. They fail if the app's copies drift.
7. On the unit: smallest change first, one at a time, the original at hand, read back.

## Adding to the app

Each module depends only on those above it ([ARCHITECTURE.md](ARCHITECTURE.md)), so a new page is one file in `OPZStage` drawn on a `DotCanvas`,
and `galaxz-shots` draws it to a PNG with no unit and no window. `galaxz-fakeopz` is an OP-Z on your Mac's MIDI. If it sends anything to the
OP-Z, back it up, show it, confirm it, read it back, and roll back if it fails.

## Working together

A fork does not have to be goodbye. If yours fixes something, send it here too; if it goes its own way, open a **Fork** issue with a line about what it
is for, so people find each other and the README can point to it.
