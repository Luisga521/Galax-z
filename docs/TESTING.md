# Trying Galax-z with no OP-Z

```bash
(cd Packages/GalaxzKit && swift test)                          # 137 tests: protocol, edits, the playhead, screens, fuzzing, releases, the writer
for t in Firmware/tools/test_*.py; do python3 -I $t; done      # the OS code, in the Blackfin simulator
swift run -c release --package-path Packages/GalaxzKit galaxz-shots /tmp/shots 360x240     # every page as a picture, and what a frame costs
#   … -project ~/Documents/Backups/content/<time>/projects/project01.opz -pattern 2 -settings ~/Documents/Backups/content/<time>/settings     a project of yours
```

**The Mac app against a virtual OP-Z**, over real CoreMIDI, with nobody there (a debug build; `-scratch` keeps its backups and
releases out of yours; another bundle id keeps its settings out of yours):

```bash
xcodebuild -project Galaxz.xcodeproj -scheme Galaxz -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath /tmp/dd GALAXZ_ID=org.galax-z.selftest CODE_SIGNING_ALLOWED=NO build
swift run -c release --package-path Packages/GalaxzKit galaxz-fakeopz 45 &
/tmp/dd/Build/Products/Debug-maccatalyst/Galaxz.app/Contents/MacOS/Galaxz -selftest /tmp/out -scratch /tmp/scratch
```

**A self test only ever talks to a virtual OP-Z** (`MIDITransport.onlyVirtual`, and it looks again before it begins): it plays, mutes and turns things. Once, on
2026-11-22, it did so on the real one, which was plugged in: a cable came first.

`/tmp/out/report.txt` says what it saw and when; the pictures are its own GPU passes. 2026-11-22: connected in 0.4 s; the playhead ran on
from one `$05` a pattern, with and without MIDI clock; an edit, a knob, a page and a track followed at once with no read of the project; one read for a lost edit, one for a replaced
pattern; the meter's report taken; the OP-Z going away noticed.

**The hub's whole way over a serial port**, to a fake update mode (`Firmware/tools/fake_update_port.py`, the bootloader's own parser
modelled):

```bash
Firmware/.venv/bin/python Firmware/tools/fake_update_port.py galaxz-v8 /tmp/opz [--pull-at 300000 | --corrupt-at 500000]      # prints the port
…/Galaxz -selftest /tmp/out -scratch /tmp/scratch -updateport /dev/ttysNNN -flash galaxz-v9
```

2026-11-22: v8 to v9 ends with exactly the image that runs on the unit; no write before a read, one write for two asks; a downloaded
signed release installs; a cable pulled at piece 146 of 441 is caught, the warning outlives the app, only TE's original is then let
through and puts it right byte for byte; one changed byte is caught on the read back.

`-selftest DIR -scratch DIR -demo -window` opens the window on the Mac's display and measures it. On a 120 Hz display every page ran at 119-120
frames a second using 13-22 % of a core (2026-11-22). It also asks for two window sizes and gets them.

**FX and v10's telling** (`tell/`): `python3 -I Firmware/tools/test_tell.py` runs the block's own Blackfin bytes; `MachinesTests` reads the bytes it
sent there, and holds the app's dials, pulses and balls to what `pages.c` makes. `galaxz-shots DIR 235x460` and `453x228` are an iPhone's two ways up.

`galaxz-fakeopz` tells of a tumbler and an EUCLID as v10 does; the self test follows it over CoreMIDI and prints the link check.

The Mac app reads no folder the Mac guards before its first frame: a question from the Mac at launch once held it with no window.

The Mac's way of the sound (`SoundPath`) was run with a silent virtual device for the OP-Z (2026-11-22): it flows, the volume glides, stopping leaves the
Mac's devices and rate as they were. The iPad's and iPhone's was not run: it needs the OP-Z on a cable.

**What this does not show**: how a real OP-Z takes the playing pages ([STATUS.md](STATUS.md)), Bluetooth, touch on an iPad, dragging the Mac window's edge by hand.
