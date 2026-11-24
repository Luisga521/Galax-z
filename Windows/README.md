# Galax-z for Windows

**A test build, second pass.** The same screens as on the Mac, from the same Swift code, in a window of its own, with Settings
and the Galax-z OS installer over it as on the Mac. Built and run on Windows; its writer has put a boot animation on an OP-Z (2026-11-24).

## How it is made

| | |
|---|---|
| `Sources/GalaxzWindows/` | The window (Win32), the OP-Z over USB through Windows' own MIDI (WinMM), the frame loop, and Settings drawn by GDI in Galax-z's look (`Panel.swift`, `SettingsPanel.swift`). Windows only |
| `Sources/GalaxzDesktop/` | What needs no Windows, tested on a Mac too: the dots drawn by the CPU (`App/DotShaders.swift`'s four passes in plain Swift), the mouse, the timed MIDI sender, the hub (`App/Hub.swift` without SwiftUI), your animations, `settings.json` |
| `Sources/CGalaxzBluetooth/` | Bluetooth MIDI: Windows reaches it only through WinRT, so a little C++/WinRT behind a C door (`BluetoothMIDI.swift` uses it) |
| `Sources/galaxz-ports/` | The update mode from a terminal: which serial port is the OP-Z's, and what is installed on it. **It cannot write** |
| `../Android/core` | The Android app's core (`App/Live.swift` without actors), used as it is: `Desktop.swift` is its Swift door, as `JNI.swift` is Kotlin's |
| `../Packages/GalaxzKit` | Everything else, shared with the Mac, iPad, iPhone and Android. On Windows: swift-crypto where CryptoKit is, Galax-z's own inflate where zlib is |
| `build.ps1` | Tests everything, builds, packages `build\Galax-z\`, a zip and a setup program, and writes `build\report.txt` |
| `Galax-z.iss` | The setup program (Inno Setup 6): installs for the person, no administrator, with a Start menu entry and an uninstaller |

## Building

On a Windows 10 or 11 computer (x64 or ARM), in PowerShell:

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --force --custom "--add Microsoft.VisualStudio.Component.Windows11SDK.22621 --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.VC.Tools.ARM64"
winget install --id Swift.Toolchain --exact
winget install --id Git.Git --exact
```

Open a new PowerShell, then get the source **without changing its line ends** (signed release files are checked byte for byte):

```powershell
git -c core.autocrlf=false clone <the repository>
cd <the folder>
powershell -ExecutionPolicy Bypass -File Windows\build.ps1
```

It runs every test of the shared code on your computer (a few minutes), builds, and packages. Whatever happens, `Windows\build\report.txt`
says what it did; that file is what to send when something fails. `-SkipTests` builds only, `-Run` starts it afterwards. It finds
Visual Studio's linker and Swift's SDK by itself: any PowerShell will do, also one opened before the toolchain was installed.

| | |
|---|---|
| `build.ps1` | For you: `Galax-z-<version>-windows-<arch>-mine.zip`, with debug information (it names your folders: a warning says so) and your `git config galaxz.byline` in Settings › Credits |
| `build.ps1 -Public` | To hand out, as the Mac's `PUBLIC=1 Tools/package-mac.sh`: `Galax-z-<version>-windows-<arch>.zip`, debug information stripped, the default byline, and the build **fails** if any folder of yours is still in the programs |

Both check that the notices (`LICENSE`, `THIRD_PARTY.md`) are in the package and that no file of TE's is.

With Inno Setup on the computer (`winget install --id JRSoftware.InnoSetup --exact`) each build also makes
`Galax-z-<version>-windows-<arch>-setup.exe` (`-mine` too, without `-Public`); without it the setup is left out and the report says so.
`-Installer` makes it a must.

The programs and the setup are not signed: Windows' SmartScreen says "Windows protected your PC" the first time. **More info › Run
anyway**, once.

## Installing it

Run `Galax-z-<version>-windows-<arch>-setup.exe`. It asks for no administrator: Galax-z goes in `%LOCALAPPDATA%\Programs\Galax-z`, with
**Galax-z** and **Galax-z (demo OP-Z)** in the Start menu (a desktop icon if you tick it). A newer setup updates it in place; it asks
for Galax-z to be closed first, and Galax-z will not close while it writes to an OP-Z. **Settings › Apps › Galax-z › Uninstall** takes
the program away and leaves what is yours: your settings and TE's OS in `%LOCALAPPDATA%\Galax-z`, your backups in `Documents\Galax-z`.
The zip is the same program with no setup: unpack it anywhere and run `Galax-z.exe`.

## Using it

`Galax-z.exe` in `build\Galax-z\`. Plug in the OP-Z with a USB-C cable; it finds it by itself. Or over Bluetooth: **PAIR** (on the SKY
page, or Settings › BLUETOOTH) finds an OP-Z near and pairs it; after that Galax-z connects to it by itself whenever it is on and no cable
is in (the cable comes first). `--demo` (or **D**) plays the demo OP-Z.

It draws as many frames a second as the monitor shows (60, 144, 165, 240 Hz…, read from Windows for the monitor it is on), at full
resolution while a frame is drawn in time for that, every other pixel when it is not (a big full screen on a fast monitor).

| | |
|---|---|
| Click, drag | as a finger on the iPad: pads, faders, dials; a sideways drag turns the page |
| ← → | the page before, the next |
| ↑ ↓ | the track |
| 1 … 0 | the first to the tenth page |
| D | the demo OP-Z, on or off |
| H, or GALAX-Z OS on the screen | Settings › Galax-z OS: the installer |
| Ctrl+, or SETTINGS on the screen | Settings |
| F11, Alt+Enter, Esc | full screen, and back (remembered; also in Settings › SCREEN); Esc also closes Settings (not while the OP-Z is written) |

Close TE's app and every DAW first: Windows gives a MIDI device to one program at a time. The log is `%LOCALAPPDATA%\Galax-z\log.txt`.

**Settings**, as on the Mac: GENERAL (dots, glow, afterglow; the demo; backups, automatic or BACK UP NOW; the key test; the link
check, SAVE to a file; looking for new versions; credits) and GALAX-Z OS (the five steps, every version, the chime, boot animations
and their editor: pattern, three colours, black and white, how bright each row is).

| Where | |
|---|---|
| `Documents\Galax-z\Backups\content\<time>\` | Your projects and sound settings, laid out like the OP-Z's disk: put one back in content mode (hold TRACK while switching on) |
| `Documents\Galax-z\Backups\os\flash-<time>\` | What was on the OP-Z before every READ and write, and the log of it |
| `%LOCALAPPDATA%\Galax-z\os-1.2.45.ldr` | TE's OS, read off your OP-Z at the first READ. **Copy it somewhere safe**: it is the way back |
| `%LOCALAPPDATA%\Galax-z\settings.json` | The look, the chime, your animations, what is on the OP-Z, and a write that did not finish |

## What works, and what is not there yet

| | |
|---|---|
| Every page, the look, the demo | built; tested on a Mac through the same code (the picture is the CPU's, compared there) |
| The OP-Z over a USB-C cable (WinMM) | built, **not yet tried** |
| `galaxz-ports`: which COM port is the OP-Z's | built, **not yet tried**. It lists and opens nothing |
| `galaxz-ports read`: what is installed (as the Mac's READ) | built, **not yet tried**. Read-only: the console takes only its fixed ping and read frames |
| Settings: the look, the demo, backups, the key test, the link check | built; backups and the key test **not yet tried** with an OP-Z |
| **Installing Galax-z OS** (READ, every version, TE's original, the chime) | built, the Mac's hub and writer. **The writer is tried**: a boot animation went on an OP-Z from Windows (2026-11-24) and it started with it. A Galax-z OS version is **not yet installed** from Windows |
| Boot animations: the library, your own, installing one | **tried**: one installed on an OP-Z from Windows, 2026-11-24, and shown at start |
| LEARN (other MIDI controllers) | next pass: Windows opens only the OP-Z's MIDI so far |
| The OP-Z's sound, CHOPS' recording | later |
| Bluetooth: PAIR, then the OP-Z over Bluetooth MIDI | pairing **tried** on an OP-Z (Windows paired it, its ports came); the connection itself **not yet**: the OP-Z must be on and not with a phone. Over Bluetooth, backups take minutes and are not taken by themselves; installing Galax-z OS needs the cable |

## Safety, on Windows

Writing to an OP-Z is the Mac's hub's code, unchanged (`OPZFirmware.UpdateConsole`: fixed frames, only `os.ldr` and `os.crc32`,
only images it can check by SHA-256, a backup first, every file read back, a stalled upload locks everything until the OP-Z is switched
off). What Windows adds:

- **Which port.** A Mac names a USB modem `/dev/cu.usbmodem…`; Windows calls anything serial `COMn`. Galax-z talks only to a COM port
  whose USB device is teenage engineering's (vendor `2367`), only when there is exactly one, and never to a port Windows has seen given
  to another device too (`UpdatePorts`, tested).
- **Exclusive.** The port is opened for Galax-z alone: nothing else can write to it meanwhile, and it cannot open one that is in use.
- **No hanging.** A write the OP-Z does not take within 5 s fails, and counts as a stalled upload, instead of waiting forever.
- **Held, then asked.** HOLD TO INSTALL is held 1.4 s, then Windows asks once more (No is the default).
- **Not in the middle.** While the OP-Z is read or written the computer does not sleep, the window does not close, and Windows is
  asked not to shut down. A write that began and did not finish is kept in `settings.json`, so the warning is there after a crash too.

`galaxz-ports` (no arguments) is the first thing to try with an OP-Z in update mode (off, hold SCREEN, on, plug in): it says what
Windows sees and which port Galax-z would use, and touches none of them.
