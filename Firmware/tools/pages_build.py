#!/usr/bin/env python3
"""pages_build — compile pages/pages.c into pages/pages.gen.S (checked in, so nobody needs the compiler), and write
patches/pages9.json: the assembled block and the edits that lead the OS into it.

    pages_build.py OS.ldr     compile, assemble, write the record (TE's own os.ldr, for the bytes the edits replace)
    pages_build.py            compile only, write pages.gen.S

Needs bfin-elf-gcc 15.3
(op-free research/toolchain-setup.md); every section goes to .text, so the block is one piece, state included.
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.join(os.path.dirname(HERE), "pages")
GCC = next((p for p in (os.path.expanduser(f"~/opt/{d}/bin/bfin-elf-gcc") for d in ("bfin-elf", "bfin-elf-gcc"))
            if os.path.exists(p)), None)
FLAGS = ["-std=c11", "-O2", "-Wall", "-Wextra", "-Werror", "-mcpu=bf592-none", "-ffreestanding", "-fno-common", "-fno-builtin",
         "-fno-zero-initialized-in-bss", "-fno-tree-loop-distribute-patterns", "-fno-jump-tables", "-fno-strict-aliasing",
         "-fno-asynchronous-unwind-tables", "-fno-ident", "-fomit-frame-pointer", "-mno-fdpic"]


def compiled(folder: str = DIR, source: str = "pages.c") -> str:
    if not GCC:
        raise SystemExit("bfin-elf-gcc not found")
    s = subprocess.run([GCC, *FLAGS, "-S", "-o", "-", source], cwd=folder, capture_output=True, text=True)
    if s.returncode:
        raise SystemExit(s.stderr)
    out = []
    for line in s.stdout.splitlines():
        if re.match(r"\s*(\.data|\.bss|\.section\b.*|\.text)\s*;?\s*$", line):
            line = "\t.text"
        out.append(line)
    if any(re.match(r"\s*\.(comm|lcomm)\b", x) for x in out):
        raise SystemExit("common symbols: not in .text")
    return f"/* made by tools/{os.path.basename(folder)}_build.py from {source}: do not edit */\n" + "\n".join(out) + "\n"



TARGET = 0x80C30000
HOOKS = [  # address, hook, bytes replaced, what, evidence
    (0x80110788, "_hook_tick", 4, "the UI task's call of the UI frame goes through our pages first",
     "'CALL 0x8010a818', its only caller; in the UI/sequencer task, R0 = the sequencer"),
    (0x8010e1fc, "_hook_note", 4, "a key or MIDI note about to sound (Sequencer::noteOn's call of playNote) is offered to our pages",
     "'CALL 0x8010c894' at the end of 0x8010dd0c, past the contexts; the note is its 4th argument"),
    (0x8011efe0, "_hook_knob", 6, "a turned dial (DefaultContext::onCC, dials 1-4) is offered to our pages",
     "the first instruction of cases 1-4 of the jump table at 0x81113318, 'P1 = 0x345e2c' (48-bit)"),
    (0x8011d498, "_hook_dials", 4, "the routine that draws the four dial LEDs asks our pages first",
     "'LINK 0x10', the routine's start; callers 0x8011d9d4, 0x8003aaa4, 0x8012411c, 0x80126854"),
    (0x8003c7b0, "_hook_fade", 4, "the dial LEDs' flash when SHIFT turns the page: pink on the fifth, teal on the sixth",
     "'CALL 0x8003d3f0' in overlay 2 (0x8003c768), started at 0x8011ec40 with the new page"),
    (0x8010a96e, "_hook_paint", 4, "after the lights bridge, the balls or the ring are painted over the step row",
     "'CALL 0x8003a9d4', its only caller; before the overlays (0x8010a97a, the A/B bars' hook)"),
    (0x8011f5d0, "_hook_stop", 4, "STOP pressed on the normal screen is offered to our pages",
     "'CALL 0x8010c344' in DefaultContext::onCC, case 17, value -1 (press), no step held"),
    (0x8010dd0c, "_hook_on", 4, "a key pressed is noted (with SHIFT down, it is not SHIFT alone)", "'LINK 0x4', the start of Sequencer::noteOn"),
    (0x8011e516, "_hook_screen", 4, "a dial turned while SCREEN is down (the SCREEN screen's onCC) is offered to our pages: the blue one turns the parameter pages",
     "'R0 = R2; R0 += -1', the start of the SCREEN screen's onCC (vtable 0x81113074 + 8; the screen put on at 0x8010a360 while SCREEN is down), "
     "which sends dials 1-4 out as CC 105-108 on channel 16"),
]


def linked(folder: str, source: str, target: int):
    """The assembled block and its symbols."""
    import tempfile
    sys.path.insert(0, HERE)
    import asm
    src = os.path.join(folder, source)
    with tempfile.TemporaryDirectory() as d:
        o, e = os.path.join(d, "o"), os.path.join(d, "e")
        subprocess.run([f"{asm.BIN}/bfin-elf-as", "-I", folder, "-o", o, src], check=True)
        subprocess.run([f"{asm.BIN}/bfin-elf-ld", f"-Ttext=0x{target:x}", "-e", "0", "-o", e, o], check=True)
        nm = subprocess.run([f"{asm.BIN}/bfin-elf-nm", e], capture_output=True, text=True, check=True).stdout
    return asm.assemble(src, target), {n: int(a, 16) for a, _, n in (x.split() for x in nm.splitlines())}


def branch(img, address: int, hook: int, n: int, name: str, what: str, evidence: str) -> dict:
    """The edit that leads `address` to `hook`: a CALL stays a CALL, anything else becomes a JUMP.L."""
    old = img.read(address, n)
    off = (hook - address) // 2
    assert -(1 << 23) <= off < 1 << 23
    off &= 0xFFFFFF
    new = bytes([off >> 16, 0xE3 if old[1] == 0xE3 else 0xE2, off & 255, off >> 8 & 255]) + b"\0" * (n - 4)
    return {"what": what, "hook": name, "device_address": f"0x{address:08x}", "file_offset": f"0x{img.offset_of(address):x}",
            "expected": old.hex(" "), "new": new.hex(" "), "evidence": "[code] " + evidence}


def record(ldr: str) -> dict:
    import hashlib
    sys.path.insert(0, HERE)
    import ldr as L
    img = L.Image(ldr)
    data, names = linked(DIR, "pages.S", TARGET)
    at = {n: a for n, a in names.items() if n.startswith("_hook_")}
    state = {n[1:]: f"0x{a:08x}" for n, a in sorted(names.items()) if n in ("_tumblers", "_euclids", "_knob", "_touched", "_grooves", "_gknob", "_now", "_beat", "_waiting")}
    edits = [branch(img, address, at[hook], n, hook, what, evidence) for address, hook, n, what, evidence in HOOKS]

    def data_edit(address, n, change, what, evidence):
        old = img.read(address, n)
        new = bytearray(old)
        change(new)
        edits.append({"what": what, "device_address": f"0x{address:08x}", "file_offset": f"0x{img.offset_of(address):x}",
                      "expected": old.hex(" "), "new": bytes(new).hex(" "), "evidence": "[code] " + evidence})

    def five(b):
        for t in range(8):
            assert b[t * 4] == 4
            b[t * 4] = 7

    def kinds(b):
        for t in range(8):
            assert b[t * 6 + 4] == b[t * 6 + 5] == 0xFF
            b[t * 6 + 4] = b[t * 6 + 5] = 3
    data_edit(0x81112F5C, 32, five, "tracks 1-8 have seven parameter pages, not four",
              "page counts, one word a track, used when SHIFT turns the page (0x8011ebe4), a track is chosen (0x801258e0) and by CC 102 (0x8010fe72)")
    data_edit(0x811131CC, 48, kinds, "the fifth and sixth pages have a valid kind (the orange page's) for anything that looks it up",
              "page kinds, 6 bytes a track, -1 = none; read at 0x8011d4ac and 0x8011eff2 (both after our hooks), 0x8011ebcc (SHIFT) and, for the arp only, 0x8011daa4. The "
              "seventh page reads the next track's first: 5 5 5 0 0 0 0 0, valid kinds, and 0 for the arp (not its 4)")
    return {
        "name": "galaxz-pages9", "status": "WORKS on the unit (2026-11-24)",
        "description": "Three more parameter pages on tracks 1-8: the tumbler (pink, TO-2's tombola), EUCLID (teal, TO-2's) and GROOVE (light green: TO-2's grooves and "
                       "progressions), both with MORE on SHIFT held 2 s. REC records their notes, and the first two's dials. With SCREEN held the blue dial turns the OP-Z's "
                       "parameter pages, both ways (the green one still goes out as CC 105, which the Galax-z app turns its pages by). See pages/pages.c.",
        "source": {"file": "os.ldr", "firmware": "1.2.45", "size": 828136,
                   "sha256": "5be99760c8797bdd4797ed20cfb9a92b6588889d3a81109bae5a45646a9bde07", "crc32": 2403806141},
        "edits": edits,
        "blocks": [{"what": "the pages: hooks, tumbler, EUCLID, GROOVE, state", "target": f"0x{TARGET:08x}", "source": "pages/pages.S",
                    "entries": {h: f"0x{a:08x}" for h, a in sorted(at.items())}, "state": state, "data": data.hex(),
                    "sha256": hashlib.sha256(data).hexdigest()}],
        "revert": "Flash Galax-z v13 (the hub, or Firmware/flash).",
        "risk": "Our code runs before every UI frame and in the key, dial and STOP paths, and plays notes through the OS's own "
                "playNote. If it fails, the OS fails right after start-up or on the new pages: switch off, update mode (SCREEN), "
                "flash Galax-z v13 or the original.",
    }


if __name__ == "__main__":
    path, text = os.path.join(DIR, "pages.gen.S"), compiled()
    open(path, "w").write(text)
    print(f"{path}: {len(text.splitlines())} lines")
    if len(sys.argv) > 1:
        import json
        rec, where = record(sys.argv[1]), os.path.join(os.path.dirname(HERE), "patches", "pages9.json")
        if os.path.exists(where):       # versions that have been on the OP-Z: kept, only recognised there
            with open(where) as f:
                rec["earlier"] = json.load(f).get("earlier", [])
        with open(where, "w") as f:
            json.dump(rec, f, indent=2)
            f.write("\n")
        print(f"pages9.json: {len(rec['edits'])} edits, {len(rec['blocks'][0]['data']) // 2} bytes at 0x{TARGET:08x}")
