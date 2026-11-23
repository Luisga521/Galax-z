# Building

## What you need

| For | You need |
|---|---|
| The Mac app, the demo, the pictures | macOS 15 or newer, Xcode 16 or newer (built with 27.2), [`xcodegen`](https://github.com/yonaskolb/XcodeGen) |
| iPad and iPhone (iOS 18 or newer) | the same, and an Apple developer team of your own ([FORKING.md](FORKING.md), 3) |
| Flashing from the terminal | Python 3; `Firmware/flash` makes its own environment |
| Changing OS code | Blackfin GCC 15.3 and binutils 2.47 in `~/opt/bfin-elf` ([how](https://github.com/mutlisensor/op-free/blob/main/research/toolchain-setup.md)). Records keep their bytes, so building and flashing need none of it |
| Changing engines | [OP-FREE](https://github.com/mutlisensor/op-free) and its SDK; `OPFREE=/path/to/op-free` |

## The app

```bash
Tools/package-mac.sh                       # the Mac app, build/Galax-z.app and a zip; with no Apple account it is signed for this Mac only
PUBLIC=1 Tools/package-mac.sh              # the same to hand out: no Developer ID, no app id of yours, no debug symbols
./run-mac.sh -hub                          # build with your team (Mac Catalyst) and open the hub
./deploy-ipad.sh <device-udid>             # build, install, launch; plugged in and unlocked
xcodegen                                   # Galaxz.xcodeproj again, after project.yml changed
```

`-demo` as a launch argument starts with the demo OP-Z.

## Without an OP-Z

```bash
(cd Packages/GalaxzKit && swift test)      # the protocol and formats against OP-FREE's reference
swift run -c release --package-path Packages/GalaxzKit galaxz-shots /tmp/shots 360x240      # every page as a picture
swift run --package-path Packages/GalaxzKit galaxz-probe                                    # the same code against an OP-Z on the Mac, read-only
```

More in [TESTING.md](TESTING.md).

## Made files

| What | By |
|---|---|
| The app's copies of builds and records | `Tools/sync-firmware.sh` |
| Test fixtures, the demo song, the engine catalogue | `node --experimental-strip-types Tools/fixtures/make-fixtures.mjs /path/to/op-free` |
| The app icon | `swift Tools/icon/make-icon.swift App/Assets.xcassets/AppIcon.appiconset` |
| `*.gen.S` and the records' blocks | `Firmware/tools/*_build.py` |
| The pictures in `docs/screens` | `galaxz-shots`, with the demo song |
