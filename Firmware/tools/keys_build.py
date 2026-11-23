#!/usr/bin/env python3
"""keys_build — as pages_build, for keys/keys.c: compile it into keys.gen.S and write patches/keys.json.

    keys_build.py OS.ldr     compile, assemble, write the record (TE's own os.ldr, for the bytes the edits replace)
"""
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ldr as L  # noqa: E402
import pages_build as P  # noqa: E402

DIR, TARGET = os.path.join(os.path.dirname(HERE), "keys"), 0x80CA0000
HOOKS = [
    (0x80111090, "_hook_on", 4, "a MIDI note's start: what waits of it for the pedal ends first, and its track is noted", "'CALL 0x8010dd0c' (Sequencer::noteOn) where MIDI is taken; R1 = channel, R2 = note"),
    (0x801110ac, "_hook_off", 4, "a MIDI note's end (note on, velocity 0) waits while the pedal is down", "'CALL 0x8010e55c' (Sequencer::noteOff); R1 = channel, R2 = note, then source, flags"),
    (0x801110d8, "_hook_off", 4, "a MIDI note's end waits while the pedal is down", "as above, from note off"),
    (0x8011103c, "_hook_control", 4, "a MIDI control change: sustain, and modulation in INSTRUMENT, are ours", "'CALL 0x8010fd48'; R1 = channel, R2 = control, then value"),
    (0x80110f9c, "_hook_bend", 4, "the MIDI pitch wheel is noted, for the vibrato to ride on", "'CALL 0x80107f68'; R1 = channel, R2 = low, then high"),
    (0x8010a836, "_hook_frame", 4, "once a UI frame: the vibrato", "'CALL 0x8003d5e0' (clear the LEDs) at the UI frame's start, no arguments"),
]


def record(os_ldr: str) -> dict:
    img = L.Image(os_ldr)
    data, names = P.linked(DIR, "keys.S", TARGET)
    at = {n: a for n, a in names.items() if n.startswith("_hook_")}
    return {
        "name": "galaxz-keys", "status": "WORKS on the unit (2026-11-22)",
        "description": "What a keyboard sends besides notes: the sustain pedal, the modulation wheel (vibrato, in INSTRUMENT), and keys that "
                       "end on the track they began on. See keys/keys.c.",
        "source": {"file": "os.ldr", "firmware": "1.2.45", "size": 828136,
                   "sha256": "5be99760c8797bdd4797ed20cfb9a92b6588889d3a81109bae5a45646a9bde07", "crc32": 2403806141},
        "edits": [P.branch(img, address, at[hook], n, hook, what, evidence) for address, hook, n, what, evidence in HOOKS],
        "blocks": [{"what": "the keys' hooks and state", "target": f"0x{TARGET:08x}", "source": "keys/keys.S",
                    "entries": {h: f"0x{a:08x}" for h, a in sorted(at.items())}, "data": data.hex(), "sha256": hashlib.sha256(data).hexdigest()}],
        "revert": "Flash Galax-z v6 (the hub, or Firmware/flash).",
        "risk": "Our code runs on every MIDI note, control change and pitch bend that comes in, and once a UI frame. If it fails, the OS "
                "fails then: switch off, update mode (SCREEN), flash Galax-z v6 or the original.",
    }


if __name__ == "__main__":
    text = P.compiled(DIR, "keys.c")
    with open(os.path.join(DIR, "keys.gen.S"), "w") as f:
        f.write(text)
    rec, where = record(sys.argv[1]), os.path.join(os.path.dirname(HERE), "patches", "keys.json")
    if os.path.exists(where):
        with open(where) as f:
            rec["earlier"] = json.load(f).get("earlier", [])
    with open(where, "w") as f:
        json.dump(rec, f, indent=2)
        f.write("\n")
    print(f"keys.json: {len(rec['edits'])} edits, {len(rec['blocks'][0]['data']) // 2} bytes at 0x{TARGET:08x}")
