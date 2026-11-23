#!/usr/bin/env python3
"""usbhost_build — as pages_build, for usbhost/usbhost.c: compile it into usbhost.gen.S and write patches/usbhost.json.

    usbhost_build.py OS.ldr     compile, assemble, write the record (TE's own os.ldr, for the bytes the edits replace)
"""
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ldr as L  # noqa: E402
import pages_build as P  # noqa: E402

DIR, TARGET = os.path.join(os.path.dirname(HERE), "usbhost"), 0x80C90000
HOOKS = [
    (0x8000a3e0, "_hook_adopt", 4, "before the USB host looks for an interface's driver, an older keyboard's is made to say it is MIDI",
     "'LINK 0x30', the start of the routine that walks the drivers (list 0x080198ac) for a device (R0) and interface (R1); its one caller is 0x8000aef8"),
    (0x80003bbe, "_hook_endpoints", 4, "after the audio/MIDI driver read a MIDI interface, its endpoints get a port count if they had none",
     "'CALL 0x8000323c' in the probe 0x80003ab8; the count is read at 0x80003a66-0x80003a6e through + 0x108, unchecked"),
    (0x8011ab60, "_hook_tidy", 4, "a USB MIDI packet is rid of empty events and other ports' before the OS reads it",
     "'LINK 0x8', the start of UsbMidi's reader: R1 = packet, R2 = length; a port other than 1 ends it (0x8011aba4)"),
    (0x8010b770, "_hook_key", 4, "a control's press or release is shown to us first (SHIFT + PROJECT: HOST or INSTRUMENT)",
     "'LINK 0x0', the start of the routine that keeps which keys are down; its one caller is 0x8010ffd2; R1 = control, R2 = value, -1 = press"),
    (0x8000a104, "_hook_new", 4, "a USB device's start, and what came of it, are written down", "'LINK 0xc', the start of the routine; callers 0x80006a66, 0x800075ac"),
    (0x800279d8, "_hook_role", 4, "what the keyboard chip says of the USB-C port is written down", "'LINK 0x0', the start of the routine; R1 = message, + 0xc its four bytes"),
    (0x8010a922, "_hook_frame", 4, "once a UI frame, a piece of what was written down is sent, if asked for", "'CALL 0x8003ac64' (DMX) in the UI frame, R0 = its object"),
]


def record(os_ldr: str) -> dict:
    img = L.Image(os_ldr)
    data, names = P.linked(DIR, "usbhost.S", TARGET)
    at = {n: a for n, a in names.items() if n.startswith("_hook_")}
    return {
        "name": "galaxz-usbhost", "status": "WORKS on the unit with a Motif 6 (2026-11-22)",
        "description": "Older USB keyboards (Yamaha Motif and the like, which say they are vendor specific) work on the OP-Z's USB host, "
                       "and SHIFT + PROJECT switches between HOST and INSTRUMENT (only receives MIDI). See usbhost/usbhost.c.",
        "source": {"file": "os.ldr", "firmware": "1.2.45", "size": 828136,
                   "sha256": "5be99760c8797bdd4797ed20cfb9a92b6588889d3a81109bae5a45646a9bde07", "crc32": 2403806141},
        "edits": [P.branch(img, address, at[hook], n, hook, what, evidence) for address, hook, n, what, evidence in HOOKS],
        "blocks": [{"what": "the USB host's hooks and state", "target": f"0x{TARGET:08x}", "source": "usbhost/usbhost.S",
                    "entries": {h: f"0x{a:08x}" for h, a in sorted(at.items())},
                    "state": {"report": f"0x{names['_report']:08x}"}, "data": data.hex(), "sha256": hashlib.sha256(data).hexdigest()}],
        "revert": "Flash Galax-z v5 (the hub, or Firmware/flash).",
        "risk": "Our code runs when a USB device is plugged into the OP-Z as host, on every USB MIDI packet and at every control's press. If it "
                "fails, the OS fails then: switch off, unplug, update mode (SCREEN), flash Galax-z v5 or the original.",
    }


if __name__ == "__main__":
    text = P.compiled(DIR, "usbhost.c")
    with open(os.path.join(DIR, "usbhost.gen.S"), "w") as f:
        f.write(text)
    rec, where = record(sys.argv[1]), os.path.join(os.path.dirname(HERE), "patches", "usbhost.json")
    if os.path.exists(where):
        with open(where) as f:
            rec["earlier"] = json.load(f).get("earlier", [])
    with open(where, "w") as f:
        json.dump(rec, f, indent=2)
        f.write("\n")
    print(f"usbhost.json: {len(rec['edits'])} edits, {len(rec['blocks'][0]['data']) // 2} bytes at 0x{TARGET:08x}")
