#!/usr/bin/env python3
"""tell_build — as pages_build, for tell/tell.c: where the pages' state is (tell/where.h), tell.gen.S, patches/tell.json.

    tell_build.py OS.ldr     compile, assemble, write the record (TE's own os.ldr, for the bytes the edits replace)

tell reads the state of pages/'s block by address. The addresses are those of the block in patches/pages.json, which is linked again
here and has to come out byte for byte; a pages.json that changes needs a new tell.json (test_tell.py fails otherwise).
"""
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ldr as L  # noqa: E402
import pages_build as P  # noqa: E402

DIR, TARGET = os.path.join(os.path.dirname(HERE), "tell"), 0x80D30000
PAGES = os.path.join(os.path.dirname(HERE), "patches", "pages9.json")
HOOKS = [
    (0x80112a06, "_hook_session", 4, "after the OS looked after its app session, the Galax-z app is told about the pink and teal pages",
     "'CALL 0x80113fac', its only caller, in the UI/sequencer task's loop, every 20 ms (0x8110e5b8 = 20,000,000 ns); R0 = the session, "
     "seq + 0x3463c0; its result is not used"),
]


def where() -> str:
    """tell/where.h: the addresses, from the pages' block as it is on the OP-Z."""
    with open(PAGES) as f:
        block = json.load(f)["blocks"][0]
    data, names = P.linked(P.DIR, "pages.S", P.TARGET)
    if hashlib.sha256(data).hexdigest() != block["sha256"]:
        raise SystemExit("pages/ is not what patches/pages.json has: build that first")
    at = {"TUMBLERS": "_tumblers", "EUCLIDS": "_euclids", "NOW": "_now", "BEAT": "_beat", "WAITING": "_waiting", "GROOVES": "_grooves", "GKNOB": "_gknob"}
    return f"/* made by tools/tell_build.py from the pages' block {block['sha256'][:16]}: do not edit */\n" + "".join(
        f"#define {k} 0x{names[n]:08x}\n" for k, n in at.items())


def record(os_ldr: str) -> dict:
    img = L.Image(os_ldr)
    data, names = P.linked(DIR, "tell.S", TARGET)
    at = {n: a for n, a in names.items() if n.startswith("_hook_")}
    with open(PAGES) as f:
        pages = json.load(f)["blocks"][0]["sha256"]
    return {
        "name": "galaxz-tell9", "status": "WORKS on the unit (2026-11-24)",
        "description": "The OP-Z tells the Galax-z app (only it) what the tumbler, EUCLID and GROOVE are doing, so that the app shows them. See tell/tell.c.",
        "source": {"file": "os.ldr", "firmware": "1.2.45", "size": 828136,
                   "sha256": "5be99760c8797bdd4797ed20cfb9a92b6588889d3a81109bae5a45646a9bde07", "crc32": 2403806141},
        "reads": {"pages_sha256": pages},
        "edits": [P.branch(img, address, at[hook], n, hook, what, evidence) for address, hook, n, what, evidence in HOOKS],
        "blocks": [{"what": "the hook, what it says, its state", "target": f"0x{TARGET:08x}", "source": "tell/tell.S",
                    "entries": {h: f"0x{a:08x}" for h, a in sorted(at.items())}, "data": data.hex(), "sha256": hashlib.sha256(data).hexdigest()}],
        "revert": "Flash Galax-z v13 (the hub, or Firmware/flash).",
        "risk": "Our code runs every 20 ms in the UI/sequencer task; it reads the pages' state and sends messages through the OS's own routine, only while the "
                "Galax-z app is connected. If it fails, the OP-Z stops answering with the app connected: switch off, take the cable out, "
                "update mode (SCREEN), flash Galax-z v13 or the original.",
    }


if __name__ == "__main__":
    with open(os.path.join(DIR, "where.h"), "w") as f:
        f.write(where())
    text = P.compiled(DIR, "tell.c")
    with open(os.path.join(DIR, "tell.gen.S"), "w") as f:
        f.write(text)
    rec, path = record(sys.argv[1]), os.path.join(os.path.dirname(HERE), "patches", "tell9.json")
    with open(path, "w") as f:
        json.dump(rec, f, indent=2)
        f.write("\n")
    print(f"tell.json: {len(rec['edits'])} edits, {len(rec['blocks'][0]['data']) // 2} bytes at 0x{TARGET:08x}")
