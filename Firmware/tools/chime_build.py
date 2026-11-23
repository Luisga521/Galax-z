#!/usr/bin/env python3
"""chime_build — as pages_build, for chime/chime.c: chime.gen.S, patches/chime2.json.   chime_build.py OS.ldr"""
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ldr as L  # noqa: E402
import pages_build as P  # noqa: E402

DIR, TARGET = os.path.join(os.path.dirname(HERE), "chime"), 0x80D40000
HOOKS = [
    (0x80023434, "_hook_mix", 4, "as the mix is handed on, the start's two tones are added to it",
     "'CALL 0x80117cd4' after 'CALL 0x801184c0' (Synth::render) in the audio callback 0x8002325c; R1 = R7 = the mix, 64 frames of interleaved stereo, 32 bits, "
     "before USB out (0x8002f944) and the volume's ramp (0x80023308)"),
    (0x8011a16c, "_hook_start", 4, "where TE's start sound is played, ours is started instead",
     "'CALL 0x80117b82' (R0 = 0x0802ee3c, R2 = 50: a sound of samplepacks/sfx.aif), reached only if general.json's disable_start_sound (0x8110e524, its only reader but the "
     "file's: 0x8011a0fe) is off; what follows (0x8011a104) is also where the other way goes, and uses none of its result"),
]


def record(os_ldr: str) -> dict:
    img = L.Image(os_ldr)
    data, names = P.linked(DIR, "chime.S", TARGET)
    at = {n: a for n, a in names.items() if n.startswith("_hook_")}
    return {
        "name": "galaxz-chime2", "status": "Tested off the OP-Z, not yet on the unit",
        "description": "Two Quindar tones when the OP-Z is switched on, in place of TE's start sound and through its own volume. See chime/chime.c.",
        "source": {"file": "os.ldr", "firmware": "1.2.45", "size": 828136,
                   "sha256": "5be99760c8797bdd4797ed20cfb9a92b6588889d3a81109bae5a45646a9bde07", "crc32": 2403806141},
        "edits": [P.branch(img, address, at[hook], n, hook, what, evidence) for address, hook, n, what, evidence in HOOKS],
        "blocks": [{"what": "the hook and the tones", "target": f"0x{TARGET:08x}", "source": "chime/chime.S",
                    "entries": {h: f"0x{a:08x}" for h, a in sorted(at.items())}, "state": {"chime_at": f"0x{names['_chime_at']:08x}"},
                    "data": data.hex(), "sha256": hashlib.sha256(data).hexdigest()}],
        "revert": "Flash Galax-z v11 (the hub, or Firmware/flash).",
        "risk": "Our code runs in the audio interrupt for the first second after a start, and for a few instructions a block after that. If it "
                "fails, the OP-Z stops at its start: switch off, update mode (SCREEN), flash Galax-z v11 or the original.",
    }


if __name__ == "__main__":
    path, text = os.path.join(DIR, "chime.gen.S"), P.compiled(DIR, "chime.c")
    with open(path, "w") as f:
        f.write(text)
    if len(sys.argv) > 1:
        rec, where = record(sys.argv[1]), os.path.join(os.path.dirname(HERE), "patches", "chime2.json")
        with open(where, "w") as f:
            json.dump(rec, f, indent=2)
            f.write("\n")
        print(f"chime2.json: {len(rec['edits'])} edits, {len(rec['blocks'][0]['data']) // 2} bytes at 0x{TARGET:08x}")
