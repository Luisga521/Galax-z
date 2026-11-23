# Advised, not advised, never

What we learned on one OP-Z, some of it the hard way. It adds to [OP-FREE's safety rules](https://github.com/mutlisensor/op-free/blob/main/SAFETY.md);
follow those too.

## Before you install Galax-z OS

- [ ] You have read [DISCLAIMER.md](../DISCLAIMER.md), and you can live without this OP-Z if it goes wrong
- [ ] It runs TE's OS **1.2.45**. Anything else is refused, and should be
- [ ] Its battery is well charged
- [ ] **Backed up twice**: Settings › Backups › BACK UP NOW, and the whole disk copied in content mode (hold TRACK while switching on)
- [ ] That copy is also somewhere other than this computer
- [ ] TE's official 1.2.45 update file is on your computer, and you know TE's own update procedure
- [ ] The hub has read TE's OS off your OP-Z, and you copied `~/Library/Application Support/Galax-z/os-1.2.45.ldr` somewhere safe: it is the way back
- [ ] You know the way back: off, hold SCREEN, on, then **TE 1.2.45** in the hub
- [ ] No gig this week

The terminal tools look for that file in `Firmware/dumps/` (any folder in it, named `os.ldr`) and refuse to start without it. The hub gets it by itself.

## Advised

| Do | Why |
|---|---|
| **Use the app first, without the OS.** Try the demo, then the screen | It shows you most of what is here with nothing flashed |
| **Save the project before you play it from the app** | PERFORM puts back what it took, but a lost connection in the middle leaves it where it was. Most of these commands have only met a virtual OP-Z ([STATUS.md](STATUS.md)) |
| **Turn it down before CHOPS or a first start of v11 or newer** | CHOPS sounds from your device; the tones come at power-on (the *quiet* builds have none) |
| **Write TE 1.2.45 over itself before anything else** (the hub's **TE 1.2.45**, or `Firmware/flash flash original`) | It proves the way of writing with no change to what runs. It was our first write too |
| **Install one step, use it for a while, then the next** | If something is off you know what did it |
| **Read back after every write.** The tools do; do not skip it | The bootloader ignores errors when it writes. Reading back is the only proof |
| **Wait for the end.** Do not unplug, do not switch off, do not close the app | Half an OS does not start |
| **If it stops halfway: switch off, hold SCREEN, on, write TE 1.2.45** | Unplugging is not enough, the battery keeps the old upload open; more bytes would land inside the file |
| **Close TE's app and every other copy of Galax-z** | Two clients on one session break both. Over Bluetooth the OP-Z seems to take one link |
| **Use a cable for anything big** | Ten projects are 3.4 MB: seconds over USB, minutes over Bluetooth |
| **Test against the virtual OP-Z** (`galaxz-fakeopz`), with yours unplugged | A self test of ours once ran on the real one for half a minute: it chopped eight tracks and left a level at half |
| **Give tests their own folders** (`-scratch`) | A test once left 28 fake backups among the real ones. Restoring one would have written a 1-byte project |
| **Use a spare project for new engines** | An engine that crashes in the project the OP-Z starts with crashes every start |
| **Label what you know**: [unit], [code], [inferred] | We called a guess proven more than once, and had to take it back |

## Not advised

| Don't | Why |
|---|---|
| Install the OS on an OP-Z you need, or on somebody else's | One tested unit in the world |
| Flash v10 or newer without reading [STATUS.md](STATUS.md) | Less has been confirmed there than for v9 |
| Raise the OS's overload limit to fit more notes | Measure first (SHIFT + TEMPO). Expect a freeze past the real limit, not clicks [inferred] |
| Run code in the audio interrupt | The riskiest place there is. The load meter does it, with a timer around the callback and nothing else |
| Pace anything by UI frames | They follow tempo (192 a second at 120 BPM). Use the millisecond clock |
| Update plugs with one try and trust it | The OP-Z dropped the piano's registration twice with no error; the same bytes took the third time. Read back and retry |
| Point Galax-z at an OS that is not 1.2.45 by shifting addresses | Every address here was read in that image. Each one has to be found again |
| Use a build somebody made for you as an image | It contains TE's OS, and you cannot see what else. Use records and signed releases |
| Post your backups, dumps or `os.ldr` | Yours are private; TE's are not ours to give |

## Never

These are refused by the tools. Do not work around them.

1. **Never type into the update-mode console.** It is a root shell. `0x15` formats the whole NAND on its header alone; `0x10` and `0x14` write
   or format the SPI flash; `0x23` upgrades; `0x29` deletes; `0x31` runs code; `0x37` renames; `0x06` and `0x34` switch off or reset; what
   `0x3b` does nobody knows.
2. **Never write anything but `/yaffs2/os.ldr` and `/yaffs2/os.crc32`.** The bootloader, the SPI flash, the keyboard chip's and the Bluetooth
   chip's firmware are the way back. Lose them and there is none.
3. **Never write an image that is not the original or the patcher's own output**, checked by SHA-256.
4. **Never put an effect on the MASTER track.** The OS calls it with no output buffer: it writes to address 0 and restarts the unit, probably at
   every start of that project [code].
5. **Never send the OP-Z** `$02` (refused), `$06` (it writes the held keys), `$0E` for a track above 15, or `$09` without checking its size: the
   OS checks no bounds [code].
6. **Never put anything but your own plugs in** `settings/plugs_patch.json`. It is read at every start.
7. **Never commit or hand out** `os.ldr`, `.zfw`, dumps, keys, or the release signing key.

## If it does not start

| What you see | What to do |
|---|---|
| Crash, freeze, no sound | Switch off (wait for the battery if it will not), hold **SCREEN**, switch on. Update mode belongs to the bootloader, which Galax-z never writes. Install what you had before, or **TE 1.2.45** |
| Update mode is there, the app refuses | Update the app: it may be older than what is on there. From the terminal, `Firmware/flash check` says what it is and `Firmware/flash flash original` writes TE's own back |
| That fails too | TE's procedure: copy their `.zfw` onto "OP-Z Boot", eject, do not switch off until it restarts (their manual, p. 63). **Not tried by us from a broken OS** |
| Still broken | Factory reset in update mode (SCREEN + STOP). It removes your content: that is what the backup is for |
| A track is silent, or crashes when played | Probably an engine, not the OS. Put another sound there; see [OP-FREE's runbook](https://github.com/mutlisensor/op-free/blob/main/research/crash-recovery.md) |

Then please open a **unit report**, so the next person knows.
