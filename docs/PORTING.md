# Windows and Linux

Help is very welcome with both. **Windows has a test build** ([Windows/](../Windows/README.md), and a setup program in
[Releases](https://github.com/Luisga521/Galax-z/releases)): the screens, the demo, Settings, backups, PAIR over Bluetooth MIDI and the
Galax-z OS installer, built on Windows with one script. Its writer has put a boot animation on an OP-Z; a whole Galax-z OS version has not been installed from there yet. Linux has
nothing to run yet. This is where things stand, so that nobody starts from zero.

## What carries over

Counted on 2026-11-22. Most of the app is plain Swift that knows nothing of Apple's frameworks.

| Module | Lines | Needs of Apple's | To do |
|---|---|---|---|
| `OPZModel` formats, live edits, playhead | 1,055 | nothing | build it |
| `DotKit` the dot matrix | 438 | nothing | build it |
| `OPZPlay` chords, grooves, moves | 1,251 | nothing | build it |
| `OPZStage` every page | 2,304 | nothing | build it |
| `ChopKit` the sampler | 691 | nothing (Foundation, Synchronization) | build it |
| `OPZFirmware` images, patches, releases | 1,167 | CryptoKit, Darwin's serial port | [swift-crypto](https://github.com/apple/swift-crypto); termios on Linux, a COM port on Windows |
| `OPZLink` SysEx, sessions | 1,315 | CoreMIDI, CoreBluetooth, Compression | split: `OPFree/` needs only zlib; MIDI and Bluetooth need each system's own |
| `App` | | SwiftUI, Metal, AVFoundation | new: a window, a GPU pass, sound out |

On Windows it builds with the Swift toolchain for Windows ([Windows/](../Windows/README.md)): CryptoKit is swift-crypto there, zlib is
Galax-z's own inflate (`OPZLink/Inflate.swift`), the update mode is `COMn` (`SerialPortWindows.swift`, and only a teenage engineering
device's port: `UpdatePorts.swift`), MIDI is WinMM, and the dots are drawn by the CPU (`Windows/Sources/GalaxzDesktop/DotRenderer.swift`).
Nothing of it has been built on Linux yet. **It has been built for Android** ([Android/](../Android/README.md)), which is Linux underneath: the
modules above as they are, `OPZLink` with the system's zlib where Apple's Compression is (`CZlib`), Float maths from the C library where it has only
Double's (`ChopKit/FloatMath.swift`), the package's files from a folder (`PackageFiles`). The same should carry a Linux build most of the way.

## Where to begin

1. **Flashing from Linux.** `Firmware/tools/flash.py` is Python with pyserial, and looks for one port name, `/dev/cu.usbmodem*` (`flash_ui.py` too). Linux
   says `/dev/ttyACM*`, Windows `COMn`. Try it against `fake_update_port.py` first, never straight on an OP-Z.
2. **`swift build --target OPZStage`** on Linux, and the tests that need nothing of Apple's.
3. **`galaxz-shots` without CoreGraphics**: a PNG writer, and every page can be looked at with no window.
4. **A window**: upload a `DotCanvas` (about 360 × 240) as a texture, draw the round lights in one pass. `App/DotShaders.swift` is the whole of it, in Metal.
5. **MIDI**: SysEx in and out, notes and CCs. ALSA on Linux, WinMM or Windows MIDI Services on Windows. `galaxz-fakeopz` is what to talk to.
6. **Bluetooth, sound, the sampler** last.

Tell people what you are taking on with a *Help wanted* or *Fork* issue, so that two do not do the same.
