#!/usr/bin/env python3
"""tell (tell/), off the OP-Z: the block itself in the Blackfin simulator beside the pages' block whose state it reads, and the bytes in
patches/tell.json against their source.   python3 -I Firmware/tools/test_tell.py"""
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asm  # noqa: E402
import bfin_mini  # noqa: E402
import pages_build  # noqa: E402
import tell_build  # noqa: E402
from test_pages import RUN, branch  # noqa: E402

with open(os.path.join(HERE, "..", "patches", "tell8.json")) as f:
    RECORD = json.load(f)
with open(os.path.join(HERE, "..", "patches", "pages8.json")) as f:
    PAGES = json.load(f)["blocks"][0]
BLOCK = RECORD["blocks"][0]
BASE, CODE = int(BLOCK["target"], 16), bytes.fromhex(BLOCK["data"])
FOLDER = os.path.abspath(os.path.join(HERE, "..", "tell"))
with open(os.path.join(FOLDER, "where.h")) as f:
    WHERE = f.read()


class Tell(unittest.TestCase):
    @unittest.skipUnless(os.path.exists(bfin_mini.BIN), "no Blackfin binutils")
    def test_the_record_is_the_source(self):
        self.assertEqual(asm.assemble(os.path.join(HERE, "..", BLOCK["source"]), BASE), CODE)

    @unittest.skipUnless(pages_build.GCC, "no bfin-elf-gcc")
    def test_the_assembly_is_the_c(self):
        with open(os.path.join(FOLDER, "tell.gen.S")) as f:
            self.assertEqual(f.read(), pages_build.compiled(FOLDER, "tell.c"))

    def test_it_reads_the_pages_there_are(self):
        self.assertEqual(RECORD["reads"]["pages_sha256"], PAGES["sha256"])
        for name, key in (("TUMBLERS", "tumblers"), ("EUCLIDS", "euclids"), ("GROOVES", "grooves"), ("GKNOB", "gknob")):
            self.assertIn(f"#define {name} {PAGES['state'][key]}\n", WHERE)

    @unittest.skipUnless(os.path.exists(bfin_mini.BIN), "no Blackfin binutils")
    def test_the_addresses_are_the_linkers(self):
        self.assertEqual(WHERE, tell_build.where())

    def test_the_pages_structures_are_theirs(self):
        def shape(text, name):
            return re.sub(r"\s+", " ", re.sub(r"/\*.*?\*/", "", re.search(r"typedef struct \{[^}]*\} " + name + ";", text).group(0)))
        with open(os.path.join(HERE, "..", "pages", "pages.c")) as f:
            theirs = f.read().replace("BALLS", "8")
        with open(os.path.join(FOLDER, "tell.c")) as f:
            ours = f.read()
        for name in ("Ball", "Tumbler", "Ring", "Euclid", "Groove"):
            self.assertEqual(shape(theirs, name), shape(ours, name))

    def test_the_edit_goes_to_its_hook(self):
        e, = RECORD["edits"]
        self.assertEqual(branch(int(e["device_address"], 16), bytes.fromhex(e["new"])), ("CALL", int(BLOCK["entries"]["_hook_session"], 16)))
        self.assertEqual(branch(int(e["device_address"], 16), bytes.fromhex(e["expected"])), ("CALL", 0x80113FAC))

    @unittest.skipUnless(pages_build.GCC and RUN, "no bfin-elf-run")
    def test_the_bytes_run(self):
        sim = os.path.join(HERE, "tell_sim")
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, "block.h"), "w") as f:
                f.write(f"#define HOOK_SESSION {BLOCK['entries']['_hook_session']}u\n" + WHERE)
                for name, data in (("block", CODE), ("pages", bytes.fromhex(PAGES["data"]))):
                    f.write(f'__attribute__((section(".{name}"), used)) unsigned char {name}[] = {{' + ",".join(map(str, data)) + "};\n")
            exe = os.path.join(d, "sim.elf")
            c = subprocess.run([pages_build.GCC, "-O1", "-mcpu=bf592-none", "-ffreestanding", "-nostdlib", "-I", d, "-T", os.path.join(sim, "sim.ld"),
                                os.path.join(sim, "sim.S"), os.path.join(sim, "sim.c"), "-o", exe, "-lgcc"], capture_output=True, text=True)
            self.assertEqual(c.returncode, 0, c.stderr)
            regions = ["0x90000000,0x100000", "0x80d30000,0x10000", "0x80c30000,0x10000", "0x80028000,0x1000", "0x80041000,0x2000",
                       "0x80113000,0x2000", "0x81059000,0x1000", "0x81018000,0x1000", "0x81200000,0x400000"]
            r = subprocess.run([RUN] + [a for x in regions for a in ("--memory-region", x)] + [exe], capture_output=True, text=True, timeout=120)
            if os.environ.get("SHOW"):
                print(r.stdout)
            self.assertTrue(r.returncode == 0 and r.stdout.endswith("ok\n"), r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main()
