#!/usr/bin/env python3
"""The live voices (voices/), off the OP-Z: the block itself in the Blackfin simulator, and the bytes in patches/voices.json against their
source.   python3 -I Firmware/tools/test_voices.py"""
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
from test_pages import RUN, branch  # noqa: E402

with open(os.path.join(HERE, "..", "patches", "voices.json")) as f:
    RECORD = json.load(f)
BLOCK = RECORD["blocks"][0]
BASE, CODE = int(BLOCK["target"], 16), bytes.fromhex(BLOCK["data"])


FIRST = [0, 2, 4, 6, 8, 10, 14, 16, 22]                 # 0x815c7b0c, and a layer's 22
PLAIN, GENEROUS = [2, 2, 2, 2, 2, 3, 2, 4], [2, 2, 2, 2, 2, 3, 2, 6]


class Voices(unittest.TestCase):
    @unittest.skipUnless(os.path.exists(bfin_mini.BIN), "no Blackfin binutils")
    def test_the_record_is_the_source(self):
        self.assertEqual(asm.assemble(os.path.join(HERE, "..", BLOCK["source"]), BASE), CODE)

    @unittest.skipUnless(pages_build.GCC, "no bfin-elf-gcc")
    def test_the_assembly_is_the_c(self):
        folder = os.path.join(HERE, "..", "voices")
        with open(os.path.join(folder, "voices.gen.S")) as f:
            self.assertEqual(f.read(), pages_build.compiled(os.path.abspath(folder), "voices.c"))

    def test_every_edit_goes_to_its_hook(self):
        for e in RECORD["edits"]:
            new, old, at = bytes.fromhex(e["new"]), bytes.fromhex(e["expected"]), int(e["device_address"], 16)
            kind, target = branch(at, new)
            self.assertEqual(kind, "CALL" if e["hook"] == "_hook_memory" else "JUMP.L", e["what"])
            self.assertFalse(any(new[4:]), e["what"])
            self.assertEqual(target, int(BLOCK["entries"][e["hook"]], 16), e["what"])
        self.assertEqual({e["hook"] for e in RECORD["edits"]}, set(BLOCK["entries"]))

    @unittest.skipUnless(pages_build.GCC and RUN, "no bfin-elf-run")
    def test_the_bytes_run(self):
        sim = os.path.join(HERE, "voices_sim")
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, "block.h"), "w") as f:
                for name, at in BLOCK["entries"].items():
                    f.write(f"#define {name[1:].upper()} {at}u\n")
                for name, at in BLOCK["state"].items():
                    f.write(f"#define {name.upper()}_AT {at}u\n")
                f.write('__attribute__((section(".block"), used)) unsigned char block[] = {' + ",".join(map(str, CODE)) + "};\n")
            exe = os.path.join(d, "sim.elf")
            subprocess.run([pages_build.GCC, "-O1", "-mcpu=bf592-none", "-ffreestanding", "-nostdlib", "-I", d, "-T", os.path.join(sim, "sim.ld"),
                            os.path.join(sim, "sim.S"), os.path.join(sim, "sim.c"), "-o", exe, "-lgcc"], check=True, capture_output=True)
            regions = ["0x90000000,0x100000", "0x80cc0000,0x10000", "0x8012d000,0x2000"]
            r = subprocess.run([RUN] + [a for x in regions for a in ("--memory-region", x)] + [exe], capture_output=True, text=True, timeout=120)
            self.assertTrue(r.returncode == 0 and r.stdout.endswith("ok\n"), r.stdout + r.stderr)


    def test_counts_fit_the_records(self):
        record = json.load(open(os.path.join(HERE, "../patches/more-voices.json")))
        tables = {0x815C7ACC: list(PLAIN), 0x815C7AEC: list(GENEROUS)}
        for e in record["edits"]:
            at = int(e["device_address"], 16)
            base = max(t for t in tables if t <= at)
            track, odd = divmod(at - base, 4)
            self.assertEqual(odd, 0)
            old, new = (int.from_bytes(bytes.fromhex(e[k]), "little") for k in ("expected", "new"))
            self.assertEqual(tables[base][track], old, e["what"])
            tables[base][track] = new
        for table in tables.values():
            self.assertEqual(table, [2, 2, 2, 2, 2, 4, 2, 6])
            for track, n in enumerate(table):
                self.assertLessEqual(FIRST[track] + n, FIRST[track + 1], track)


if __name__ == "__main__":
    unittest.main()
