# Read this first

Plain words, so nobody is surprised.

## Who made this, and who did not

- Galax-z is a hobby project by **Luis Tosado**, made in spare time as a private person and shared for free. It is **not made by, endorsed by, sponsored by or
  connected with teenage engineering** (TE), nor with anybody's employer, company or client. OP-Z and OP-1 are TE's trademarks.
- **Do not ask TE to support an OP-Z running Galax-z OS.** Put TE's own OS back first. Assume that a changed OS affects your warranty.
- Galax-z stands on [OP-FREE](https://github.com/mutlisensor/op-free), by other people, who have nothing to do with what is here and should
  not be asked about it.
- **It was made with AI.** The code and documents were written with Claude (Anthropic), directed by Luis, and tried on Luis's own OP-Z. Most
  changes were. Review it as you would anybody's code.

## What can go wrong

- **Galax-z OS replaces your instrument's operating system.** A bad write or a bad patch can leave an OP-Z that does not start, loses its
  content, or needs a repair nobody offers.
- **It has run on one OP-Z.** One unit, one hardware revision, one person's way of playing, TE's OS **1.2.45** only. Yours may differ.
- Every build written so far has started, and TE's original can be written back through update mode (written and read back; see
  [STATUS.md](docs/STATUS.md#going-back)). **Going back from an OS that does not start has never been tried**, because nothing has broken that far.
- The OP-Z protects nothing from code running on it. A mistake in a patch or an engine can freeze it; there is no watchdog, so a freeze ends
  when you switch it off or the battery runs out.
- **The app's MIX, PLAY, PERFORM and CHOPS pages send MIDI** while you touch them. They write nothing into the OP-Z, but what you change there stays
  changed, as on the OP-Z itself. Save your project before you try them.
- A factory reset removes your own content. Back up first, and keep the copy somewhere else too.
- Loud surprises are possible. Turn the volume down, and take headphones off, the first time you start something new.

## What the app checks before it writes

The installer is built so that a mistake is hard to make. Before and while it writes Galax-z OS, it:

- **Writes only in update mode.** An OP-Z switched on normally cannot be written. You put it in update mode yourself (off, hold SCREEN, on).
- **Refuses any OS but TE's 1.2.45** or a Galax-z version built from it.
- **Writes two files and nothing else**, `os.ldr` and `os.crc32`. The bootloader, which holds update mode, and the firmware of the keyboard
  and Bluetooth chips are never written, so update mode stays there as the way back.
- **Writes only images it can check**, by SHA-256: TE's own, read off your OP-Z, or one built from it. A release you download is signed, checked
  against the key in the app, and must build to exactly the image it promises.
- **Sends only fixed commands.** The update-mode console can format the OP-Z's memory; the app never types into it, and refuses the commands
  that could.
- **Saves what is there first**, then reads each file back after writing and compares it byte for byte.
- **Stops everything if an upload stalls**, until the OP-Z is switched off, so no stray bytes land in the file.
- **Asks you to hold the button** on a version until it fills. On Windows it also asks once more, talks only to teenage engineering's USB port,
  and keeps the computer from sleeping or closing the app while it writes.

These checks lower the risk. **They do not remove it.** They were written for one OP-Z and tried on that one, mostly from a Mac. The Windows installer
uses the same writer; it has put a boot animation on that OP-Z, but no Galax-z OS version has been installed from Windows yet. Nothing above protects against a patch that starts but misbehaves, a cable pulled
mid-write, a flat battery, or a unit that differs from the one it was made on. Read [SAFETY.md](docs/SAFETY.md) before you install.

## Responsibility

Please read this as meant: it is what lets somebody share a thing like this at all.

- It is provided **as is, with no warranty of any kind**, as the [licence](LICENSE) says in full. To the extent the law allows, neither the authors
  nor anybody who contributes is liable for a broken instrument, lost music, lost time or money, damaged hearing or equipment, a lost warranty, or
  anything else that comes of using it, changing it or passing it on.
- **What you do with your OP-Z is your decision and your risk**, and so is making sure it is allowed where you live. Nothing here is legal,
  technical or safety advice to you in particular, and no answer in an issue is a promise or a service.
- Who passes on a changed version answers for it, under a name of their own.
- Nothing here takes away rights that the law gives you and that cannot be waived.

## What "works" means here

Claims carry a label where it matters. Please keep this habit in your fork.

| Label | Means |
|---|---|
| **[unit]** | Seen on the one real OP-Z |
| **[code]** | Read in the OS's code, not seen happening |
| **[inferred]**, **[guess]** | Follows from something, or a hunch |
| tested off the OP-Z | Passed in a simulator, on fake memory or against a virtual OP-Z |

"Works on the unit" often means it was played, found to work, and left at that. [STATUS.md](docs/STATUS.md) says where that was not point by point.

## What of TE's is in here

- **No** firmware image, dump, key, engine, sample, artwork or font of TE's, in the app or in this repository or its releases.
- The app reads the OS from **your** OP-Z and builds the changed one on your computer. A `.galaxz` release holds only addresses, the bytes
  expected there, our bytes, and the checksum of the result.
- **The exception, stated plainly:** the patch records' 81 edits carry the original bytes they replace, so that a patch refuses any OS it was not
  made for: 620 bytes in all, 262 without the repeats between versions. Notes name addresses, a few function names, short instructions and what routines do.
- Never add more than that. Do not commit `os.ldr`, `.zfw` files, dumps or listings, and do not share a built image: it contains TE's OS.

Rules about changing and studying firmware differ by country, and this is not legal advice. If you hold rights in something here and object to it, open
an issue that says what, and it will be looked at in good faith.

## Your privacy

- No account, no analytics, no tracking. Nothing about you or your OP-Z is sent anywhere.
- The app asks GitHub for the list of releases when it opens. You can turn that off in Settings.
- **Bluetooth** is used to find the OP-Z. **The microphone permission** is what the system asks for any incoming sound. The app uses it to play the
  OP-Z's USB audio, and to record a sound into CHOPS when you touch RECORD. Recordings stay on your device.
- **LINK CHECK › SAVE** writes a file with the first messages of each kind from your OP-Z, with no projects or sounds. Look at it before you post it.
- Backups stay on your device. They hold your music: do not attach them to an issue.

## The people here

**Please respect the privacy of whoever works on it**, Luis included: no looking up or posting anybody's home
address, employer, family or private accounts, and no contact outside this repository about it. Issues and discussions here are the place. This
goes for everybody who takes part.

## Support

It is a work in progress, worked on as time allows. There is no promise of an answer or a date, and others in the community may well answer first.
Things that could break somebody's OP-Z are what matters most ([SECURITY.md](SECURITY.md)). Whatever happens here, the code stays yours to use
under [MIT](LICENSE).
