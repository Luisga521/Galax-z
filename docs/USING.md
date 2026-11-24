# Using Galax-z

Galax-z is the screen the OP-Z never had, and the way to put Galax-z OS on it. It runs on an iPad and on a Mac (a phone works too).
It is not made by or connected with teenage engineering; OP-Z is their trademark.

## The screen

Plug the OP-Z in with a USB-C cable (iPad or Mac), or let the iPad find it over Bluetooth. Close TE's own app first: only one
app can follow an OP-Z at a time. If none is found, the pairing list
opens by itself and closes once your OP-Z is there. No OP-Z at hand? **Settings › DEMO OP-Z** plays a song on a pretend one.

| Page | What it shows |
|---|---|
| **TRACK** | The track selected on the OP-Z: its sound moving, its four dials for the page you are on, its sixteen steps |
| **GRID** | All sixteen tracks by sixteen steps: velocity is brightness, yellow corners are step components, white underlines are parameter locks |
| **MIX** | Levels, what each track plays, FX sends, pan, mutes |
| **FX** | The two effects moving with what is sent to them, their dials, how much of each track goes to each; and the tumbler and EUCLID of the selected track, the balls and the rings as they are (Galax-z OS v10). On the OP-Z's pink or teal page, TRACK shows them too |
| **SONG** | The project's sixteen patterns, tempo, where you are |
| **NOTES** | Everything played, going by over a keyboard, and the chord you hold |
| **LOAD** | How hard the OP-Z works (Galax-z OS v8 and newer: SHIFT + SCREEN sends the figures) |
| **SKY** | A galaxy. Each track is part of an arm; each note throws a star |

**Settings › SOUND** (or OUT at the top of the screen) chooses where the OP-Z is heard: from itself, or through this iPad, iPhone or Mac. That
needs the cable (Bluetooth carries no sound). The system asks for the microphone, as it does for any sound coming in; for this only the OP-Z's is used; nothing
is recorded unless you touch RECORD on CHOPS, and it is never sent back to the OP-Z.

**Settings › LINK CHECK** lights each thing the app has heard from your OP-Z, and says what to do to hear the rest. If something on the screen does
not follow, SAVE it and send the file along: it holds the first few messages of each kind, no project or sounds.

Tap a tab or swipe to change page. On a keyboard: `1`–`0` pages, `←` `→` turn, `↑` `↓` track, `H` Galax-z OS, `⌘,` settings. The screen
follows the OP-Z: select a track there and it shows here. On the OP-Z, hold **SCREEN** and turn the first dial: the tabs go by.

**Touching changes the OP-Z**, by MIDI, only while you touch: it needs MIDI in switched on there (hold TEMPO + SCREEN, key 2). Nothing is written
into it: what you change lasts as a change made on the OP-Z does.

- **MIX**: drag a fader (volume), a send or the pan; tap the number under a track to mute it.
- **TRACK**: drag a dial up and down. **SONG**: tap a pattern to go to it.
- **PLAY**: pads play the selected track. KEY and SCALE hold them to a scale; CHORD turns a pad into a chord, the numbers of a key, or the next chord
  of a progression (133 of TO-2's); HOLD keeps notes, DRONE keeps up to eight until touched again; GROOVE plays what is kept. The left of a
  choice is the one before, the right the next. NOTES ALL OFF ends everything.
- **PERFORM**: sixteen pads of moves: gates, filter sweeps, throws, tape stops, mutes, rolls. Hold one, or LATCH. What a move takes is put back when it
  ends. GALLERY loads another move on the pad you touched, or takes it off; TAKES says which tracks, AMOUNT how much.

- **CHOPS**: a sound in pieces, played by its pads and by the OP-Z's **MODULE** track (14), which can sequence it: its keys are the chops, or with ITS KEYS on
  PITCH the notes of the one chosen. FROM MIC, OP-Z (its sound over the cable, with its microphone when that is on) or FILE, then RECORD or OPEN; CUT where
  its hits are or in equal parts. SHOW turns between eight dials, twelve effects (touch one to see its dials, again for on and off) and the chosen chop's
  own pitch, level, pan, way, choke. VOX is a sung voice that is always there. Kits are kept on this device (Files › Galax-z › Chops). The sound comes
  from this device, not from the OP-Z.
- **PERFORM › LIGHTS**: PLAYS makes the LIGHTS track's notes (15) press the pads, so moves can be in a pattern.

**Settings › LEARN**: touch what you want to control, then move a knob or press a pad of any MIDI controller. A knob takes hold when it passes where the
value is, so nothing jumps; endless knobs are found out. KEYS › PLAY THE TRACK makes a keyboard play the selected track.

Every button combination of the OP-Z with Galax-z OS: [SHORTCUTS.md](SHORTCUTS.md).

**Settings › Screen** sets how bold the dots are, how much they glow and how long they linger.

**The GROOVE page (Galax-z OS v11; light green from v13, red before)**: on tracks 1-8, SHIFT after the teal page. Keys are kept (again: let go) and played by a groove: GROOVE, RATE, GATE, ORDER. Hold SHIFT alone for
two seconds for PROGRESSION (all the way down: none), KEY, LENGTH of a chord, SWING; with a progression one key says where its chords are. STOP empties it, REC
records it. The app shows it on TRACK. **The chime** (v12: in place of TE's start sound) is chosen in Settings › GALAX-Z OS, and goes with the version when that is installed; `disable_start_sound` in the OP-Z's general.json
turns it off too.

## Updating Galax-z OS (on a Mac or Windows)

**Settings › GALAX-Z OS** takes you through it, on a Mac or on Windows (`H` opens it). iPad, iPhone and Android have no installer: they
cannot reach the OP-Z's update mode, so they never write its OS.

**On Windows the installer is the Mac's writer, unchanged.** It has put a boot animation on an OP-Z; a Galax-z OS version has not been installed from Windows yet.
Windows adds its own checks ([Windows/README.md](../Windows/README.md#safety-on-windows)): it talks only to teenage engineering's
port, holds it for itself, gives up on a write that stalls, and asks once more after HOLD TO INSTALL.

1. **Back up.** With the OP-Z on normally and plugged in. Your projects and sounds are copied, reading only.
2. **Update mode.** Switch off. Hold **SCREEN** and switch on.
3. **Read.** The hub reads what is on it and changes nothing. The first time, this is also where it gets TE's own OS 1.2.45, from
   *your* OP-Z, to build every version from. Galax-z ships no OS of TE's.
4. **Install.** Hold the button on a version until it fills. What is there is saved first; two files are written and each is read
   back and compared, byte for byte. Don't unplug meanwhile.
5. **Restart.** Off, then on, with nothing held.

**If it does not start:** switch off, hold SCREEN, switch on: update mode is not part of what was written. Install the version you
had, or **TE 1.2.45**. If that fails, TE's own update procedure is the next step (their manual).

Your OP-Z must be on TE's OS **1.2.45** (or a Galax-z version). Anything else is refused.

The app checks a lot before it writes ([what it checks](../DISCLAIMER.md#what-the-app-checks-before-it-writes)). Those checks make a
mistake hard to make; they do not make one impossible.

**This replaces the operating system of your instrument. It has been tried on one OP-Z, mostly from a Mac. You do it at your own risk.**

### New versions

When the app opens it asks GitHub for the list of releases (off in Settings if you like; nothing about you or your OP-Z is sent).
A new one lights up in the corner. Every release is signed and checked against the key in the app, and must build to exactly the
image it promises, before it can be installed. **OPEN FILE** takes a `.galaxz` file you were given; the same checks apply.

## Backups

**Settings › Backups**, or the hub's first step. They are in Files › Galax-z › Backups (on the Mac, the app's Documents), laid out
like the OP-Z's own disk, so putting one back is a copy in content mode (hold TRACK while switching on).
