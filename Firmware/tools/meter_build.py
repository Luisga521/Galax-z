#!/usr/bin/env python3
"""meter_build — as pages_build, for meter/meter.c: compile it into meter.gen.S and write patches/meter.json.

    meter_build.py OS.ldr     compile, assemble, write the record (TE's own os.ldr, for the bytes the edits replace)
"""
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ldr as L  # noqa: E402
import pages_build as P  # noqa: E402

DIR, TARGET = os.path.join(os.path.dirname(HERE), "meter"), 0x80CB0000
HOOKS = [
    (0x80119bc8, "_hook_kill", 4, "a note cut off by the OS because the instruments took too long is counted", "'CALL 0x8012d142', its only caller; R0 = its object"),
    (0x8003c6c8, "_hook_frame", 4, "in the UI frame, after the screens drew, the meter", "'LINK 0x8', the start of the overlays' routine; its one caller is 0x8010a97a (through the A/B bars)"),
    (0x8010ffd2, "_hook_key", 4, "a control's press is shown to the meter first", "'CALL 0x8010b770' (which then goes through usbhost's hook at its start)"),
]


def edit(img, address, new, hook, what, evidence):
    return {"what": what, "hook": hook, "device_address": f"0x{address:08x}", "file_offset": f"0x{img.offset_of(address):x}",
            "expected": img.read(address, len(new)).hex(" "), "new": new.hex(" "), "evidence": "[code] " + evidence}


def pointer(img, hook):
    """R0 = 0x8002325c (48-bit load: 00 da, high half, low half), the audio callback's address given to the driver."""
    assert img.read(0x800228bc, 6) == bytes.fromhex("00da02805c32")
    return edit(img, 0x800228bc, b"\x00\xda" + (hook >> 16).to_bytes(2, "little") + (hook & 0xFFFF).to_bytes(2, "little"), "_hook_block",
                "the audio driver is given our routine, which times the OS's callback and calls it",
                "'R0 = 0x8002325c' (48-bit load), the one place that address is; it is called at 0x80031060 in the audio interrupt")


def stage(img, hook):
    """P0 = [0x81059d1c] (64-bit load): a CALL and two NOPs; the hook makes the load."""
    assert img.read(0x80118e40, 8) == bytes.fromhex("00d805811c9d4000")
    off = (hook - 0x80118e40) // 2 & 0xFFFFFF
    return edit(img, 0x80118e40, bytes([off >> 16, 0xE3, off & 255, off >> 8 & 255, 0, 0, 0, 0]), "_hook_stage",
                "after the OS timed the instruments, the time is noted",
                "'P0 = [0x81059d1c]' (64-bit load) in Synth::render, where both ways from the overload check meet; [FP - 0x20] = elapsed; RETS was saved at its start")


def record(os_ldr: str) -> dict:
    img = L.Image(os_ldr)
    data, names = P.linked(DIR, "meter.S", TARGET)
    at = {n: a for n, a in names.items() if n.startswith("_hook_")}
    return {
        "name": "galaxz-meter", "status": "WORKS on the unit (2026-11-22)",
        "description": "A load meter: SHIFT + TEMPO shows the OP-Z's own timing of its instruments on the step row and of all its audio work on the "
                       "dials; SHIFT + SCREEN sends the figures. See meter/meter.c.",
        "source": {"file": "os.ldr", "firmware": "1.2.45", "size": 828136,
                   "sha256": "5be99760c8797bdd4797ed20cfb9a92b6588889d3a81109bae5a45646a9bde07", "crc32": 2403806141},
        "edits": [P.branch(img, address, at[hook], n, hook, what, evidence) for address, hook, n, what, evidence in HOOKS]
        + [pointer(img, at["_hook_block"]), stage(img, at["_hook_stage"])],
        "blocks": [{"what": "the keys' hooks and state", "target": f"0x{TARGET:08x}", "source": "meter/meter.S",
                    "entries": {h: f"0x{a:08x}" for h, a in sorted(at.items())},
                    "state": {n[1:]: f"0x{names[n]:08x}" for n in ("_meter_kills", "_meter_stage", "_meter_total", "_report")}, "data": data.hex(), "sha256": hashlib.sha256(data).hexdigest()}],
        "revert": "Flash Galax-z v7 (the hub, or Firmware/flash).",
        "risk": "Three short pieces of our code run in the audio interrupt, 689 times a second, meter on or off: if one fails there is no sound, or the "
                "OS fails at start. Switch off, update mode (SCREEN), flash Galax-z v7 or the original.",
    }


if __name__ == "__main__":
    text = P.compiled(DIR, "meter.c")
    with open(os.path.join(DIR, "meter.gen.S"), "w") as f:
        f.write(text)
    rec, where = record(sys.argv[1]), os.path.join(os.path.dirname(HERE), "patches", "meter.json")
    if os.path.exists(where):
        with open(where) as f:
            rec["earlier"] = json.load(f).get("earlier", [])
    with open(where, "w") as f:
        json.dump(rec, f, indent=2)
        f.write("\n")
    print(f"meter.json: {len(rec['edits'])} edits, {len(rec['blocks'][0]['data']) // 2} bytes at 0x{TARGET:08x}")
