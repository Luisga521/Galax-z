# Known issues

Galax-z is a work in progress and it has bugs. These are the ones known on 2026-11-22. Seen another? Open a *Bug* issue. Fixed one? Please send
it: that is how this gets good.

## Please help look

| What | What is known |
|---|---|
| **The kick did not animate** where its track sends on another MIDI channel than 1 | Fixed in the app, waiting to be seen working |
| **The playing pages are young**: PLAY, PERFORM, LEARN, CHOPS | Tested with a virtual OP-Z. On a real one only volume and mute have been seen. If a move is cut off by a lost connection, what it took stays taken |
| **SCREEN + first dial** may move the sound's first value as well as the tabs | Not tried on a unit |
| **Recording into CHOPS**, and the OP-Z's sound through an iPad or iPhone | Built, never tried with an OP-Z |
| **The seventh page (GROOVE)** reads past the end of a table of TE's OS, where the values happen to be valid ones | Looked at in the code, works on one unit |
| **A plug's registration can be dropped** by the OP-Z without an error | Seen twice with the piano; the same bytes took the third time. The installer should read back and try again |
| **The debounce values are placeholders** (+15) | Very fast repeats of one key may be swallowed. KEY TEST measures what is needed |
| **The lock after an interrupted install can be fooled**, by quitting the app or by the port going away; the terminal tool has none | Switch the OP-Z off, hold SCREEN, switch on, install again ([SAFETY.md](SAFETY.md)) |
| **Sending the load meter's figures** (SHIFT + SCREEN) | Not confirmed |

## Known, and how it is for now

| What | |
|---|---|
| One app at a time | TE's app, or a second Galax-z, breaks the session of the first |
| The first Bluetooth pairing can need Apple's list by hand | Afterwards it links by itself |
| The OP-Z sends no MIDI clock to the app | The app counts for itself; a tempo change is picked up as it comes |
| With v9 and older, the pink, teal and GROOVE pages show as the first page in the app | TE's message has two bits for the page |
| Recorded dials are lost at power-off | They live in memory |
| The start tones are switched by choosing a *quiet* build, or `disable_start_sound` in content mode | No message that sets it was found |
| Settings stays a column in a very large Mac window | |
| The Mac app is not notarized | macOS asks you to allow it. Building it yourself avoids that |
| The update check finds nothing while the repository is private | |

What has been confirmed and what has not, version by version: [STATUS.md](STATUS.md).
