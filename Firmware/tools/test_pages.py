#!/usr/bin/env python3
"""The pages (pages/), off the OP-Z: the tumbler and EUCLID beside TO-2's on the Mac, the block itself in the Blackfin simulator, and
the bytes in patches/pages.json against their source.   python3 -I Firmware/tools/test_pages.py"""
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asm  # noqa: E402
import bfin_mini  # noqa: E402
import pages_build  # noqa: E402

RECORD = json.load(open(os.path.join(HERE, "..", "patches", "pages9.json")))
BLOCK = RECORD["blocks"][0]
BASE, CODE = int(BLOCK["target"], 16), bytes.fromhex(BLOCK["data"])

RUN = next((p for p in (os.path.expanduser(f"~/opt/{d}/bin/bfin-elf-run") for d in ("bfin-elf", "bfin-elf-gcc")) if os.path.exists(p)), None)


def branch(address: int, code: bytes) -> tuple:
    """(kind, target) of a 32-bit pc-relative CALL or JUMP.L"""
    off = code[0] << 16 | code[2] | code[3] << 8
    off -= (off & 0x800000) << 1
    return {0xE3: "CALL", 0xE2: "JUMP.L"}[code[1]], address + 2 * off


class Pages(unittest.TestCase):
    def test_physics_and_page(self):
        with tempfile.TemporaryDirectory() as d:
            exe = os.path.join(d, "t")
            subprocess.run(["clang", "-O1", "-g", "-fsanitize=address,undefined", "-fno-sanitize-recover=undefined", "-Wall",
                            "-Wno-int-to-pointer-cast", "-Wno-unused-function", "-o", exe, os.path.join(HERE, "test_pages.c")], check=True)
            r = subprocess.run([exe], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    @unittest.skipUnless(os.path.exists(bfin_mini.BIN), "no Blackfin binutils")
    def test_the_record_is_the_source(self):
        self.assertEqual(asm.assemble(os.path.join(HERE, "..", BLOCK["source"]), BASE), CODE)

    @unittest.skipUnless(pages_build.GCC, "no bfin-elf-gcc")
    def test_the_assembly_is_the_c(self):
        with open(os.path.join(pages_build.DIR, "pages.gen.S")) as f:
            self.assertEqual(f.read(), pages_build.compiled())

    @unittest.skipUnless(pages_build.GCC and RUN, "no bfin-elf-run")
    def test_the_bytes_run(self):
        """The block itself, in the Blackfin simulator: every hook, every register, the physics as compiled."""
        sim = os.path.join(HERE, "pages_sim")
        e = BLOCK["entries"]
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, "block.h"), "w") as f:
                for name, at in e.items():
                    f.write(f"#define {name[1:].upper()} {at}u\n")
                f.write("".join(f"#define {k.upper()}_AT {v}u\n" for k, v in BLOCK["state"].items()))
                f.write('__attribute__((section(".block"), used)) unsigned char block[] = {' + ",".join(map(str, CODE)) + "};\n")
            exe = os.path.join(d, "sim.elf")
            subprocess.run([pages_build.GCC, "-O1", "-mcpu=bf592-none", "-ffreestanding", "-nostdlib", "-I", d, "-T", os.path.join(sim, "sim.ld"),
                            os.path.join(sim, "sim.S"), os.path.join(sim, "sim.c"), "-o", exe, "-lgcc"], check=True, capture_output=True)
            regions = ["0x90000000,0x100000", "0x80c30000,0x10000", "0x80028000,0x1000", "0x8003a000,0x4000", "0x8010a000,0x4000", "0x8011c000,0x4000", "0x81112000,0x2000", "0x81015000,0x1000",
                       "0x81059000,0x1000", "0x0802d000,0x1000", "0x81200000,0x400000", "0x80c40000,0x40000"]
            r = subprocess.run([RUN] + [a for x in regions for a in ("--memory-region", x)] + [exe], capture_output=True, text=True, timeout=300)
            self.assertTrue(r.returncode == 0 and r.stdout.endswith("ok\n"), r.stdout + r.stderr)

    def test_every_branch_goes_to_its_hook(self):
        hooks = BLOCK["entries"]
        for e in RECORD["edits"]:
            if "hook" not in e:
                continue
            new = bytes.fromhex(e["new"])
            kind, target = branch(int(e["device_address"], 16), new)
            self.assertEqual(kind, "CALL" if bytes.fromhex(e["expected"])[1] == 0xE3 else "JUMP.L", e["what"])
            self.assertEqual(target, int(hooks[e["hook"]], 16), e["what"])
        self.assertEqual({e["hook"] for e in RECORD["edits"] if "hook" in e}, set(hooks))

    @unittest.skipUnless(os.path.exists(bfin_mini.BIN), "no Blackfin binutils")
    def test_no_unknown_instructions(self):
        code = CODE[:CODE.index(b"GALAXZ-PAGES-001")]
        self.assertFalse([t for t, _ in bfin_mini.disassemble(code, BASE).values() if "ILLEGAL" in t])


if __name__ == "__main__":
    unittest.main()
