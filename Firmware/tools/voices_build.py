#!/usr/bin/env python3
"""voices_build — as pages_build, for voices/voices.c: compile it into voices.gen.S and write patches/voices.json.

    voices_build.py OS.ldr     compile, assemble, write the record (TE's own os.ldr, for the bytes the edits replace)
"""
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ldr as L  # noqa: E402
import pages_build as P  # noqa: E402

DIR, TARGET = os.path.join(os.path.dirname(HERE), "voices"), 0x80CC0000
HOOKS = [
    (0x8012d0ac, "_hook_start", 4, "where a track's voices begin is ours", "'P1 = R1' and half of a load, the start of getVoiceStartIndex; the rest of it is left unused"),
    (0x8012d1c4, "_hook_end", 4, "where a track's voices end is ours", "'P2 = R1; LINK', the start of getVoiceEndIndex; the rest of it is left unused"),
    (0x8012d142, "_hook_overload", 4, "which note is cut when the instruments took too long is ours", "'R1 = R0; R1 += 0x10', the start of handleOverload; its one caller is 0x80119bc8 (through the meter), FP = Synth::render's"),
    (0x8012d10c, "_hook_off", 4, "all notes off is ours", "'LINK 0x0', the start of it; its one caller is 0x801180b2"),
]


def edit(img, address, new, hook, what, evidence):
    return {"what": what, "hook": hook, "device_address": f"0x{address:08x}", "file_offset": f"0x{img.offset_of(address):x}",
            "expected": img.read(address, len(new)).hex(" "), "new": new.hex(" "), "evidence": "[code] " + evidence}


def memory(img, hook):
    """R0 = 0x8156fab8 (48-bit load) and a NOP: a CALL and two NOPs; the hook makes the load."""
    assert img.read(0x8012d3e4, 8) == bytes.fromhex("00da5681b8fa0000")
    off = (hook - 0x8012d3e4) // 2 & 0xFFFFFF
    return edit(img, 0x8012d3e4, bytes([off >> 16, 0xE3, off & 255, off >> 8 & 255, 0, 0, 0, 0]), "_hook_memory",
                "a live voice's 8 KB of an engine's memory are ours",
                "'R0 = 0x8156fab8', its one use: + (number << 13) is what init is given; R2 = number << 13 from 0x8012d3ce; RETS was saved at 0x8012d278")


def record(os_ldr: str) -> dict:
    img = L.Image(os_ldr)
    data, names = P.linked(DIR, "voices.S", TARGET)
    at = {n: a for n, a in names.items() if n.startswith("_hook_")}
    assert names["_voice_records"] == 0x0800452c + 5333215 * 0x17c
    assert (0x54B12000 + (5333215 << 13)) & 0xFFFFFFFF == 0x80CD0000
    return {
        "name": "galaxz-voices", "status": "WORKS on the unit (2026-11-22)",
        "description": "More notes at once: lead 4 and chord 6 in patterns; played live bass 6, lead 10, arp 6, chord 10, in records of our own. See voices/voices.c.",
        "source": {"file": "os.ldr", "firmware": "1.2.45", "size": 828136,
                   "sha256": "5be99760c8797bdd4797ed20cfb9a92b6588889d3a81109bae5a45646a9bde07", "crc32": 2403806141},
        "edits": [P.branch(img, address, at[hook], n, hook, what, evidence) for address, hook, n, what, evidence in HOOKS] + [memory(img, at["_hook_memory"])],
        "blocks": [{"what": "the live voices and the routines that find them", "target": f"0x{TARGET:08x}", "source": "voices/voices.S",
                    "entries": {h: f"0x{a:08x}" for h, a in sorted(at.items())},
                    "state": {"voice_records": f"0x{names['_voice_records']:08x}"}, "data": data.hex(), "sha256": hashlib.sha256(data).hexdigest()}],
        "revert": "Flash Galax-z v8 (the hub, or Firmware/flash).",
        "risk": "Every note goes through this: if it is wrong the OS stops at the first note, or sounds the wrong one. Many held notes are much CPU: above 340,000 cycles "
                "the oldest live one is let go. Switch off, update mode (SCREEN), flash Galax-z v8 or the original.",
    }


if __name__ == "__main__":
    text = P.compiled(DIR, "voices.c")
    with open(os.path.join(DIR, "voices.gen.S"), "w") as f:
        f.write(text)
    rec, where = record(sys.argv[1]), os.path.join(os.path.dirname(HERE), "patches", "voices.json")
    if os.path.exists(where):
        with open(where) as f:
            rec["earlier"] = json.load(f).get("earlier", [])
    with open(where, "w") as f:
        json.dump(rec, f, indent=2)
        f.write("\n")
    print(f"voices.json: {len(rec['edits'])} edits, {len(rec['blocks'][0]['data']) // 2} bytes at 0x{TARGET:08x}")
