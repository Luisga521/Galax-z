#!/usr/bin/env python3
"""The USB host (usbhost/), off the OP-Z: the block itself in the Blackfin simulator, against a Motif's descriptors as the OP-Z keeps
them, and the bytes in patches/usbhost.json against their source.   python3 -I Firmware/tools/test_usbhost.py"""
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

with open(os.path.join(HERE, "..", "patches", "usbhost.json")) as f:
    RECORD = json.load(f)
BLOCK = RECORD["blocks"][0]
BASE, CODE = int(BLOCK["target"], 16), bytes.fromhex(BLOCK["data"])


class UsbHost(unittest.TestCase):
    @unittest.skipUnless(os.path.exists(bfin_mini.BIN), "no Blackfin binutils")
    def test_the_record_is_the_source(self):
        self.assertEqual(asm.assemble(os.path.join(HERE, "..", BLOCK["source"]), BASE), CODE)

    @unittest.skipUnless(pages_build.GCC, "no bfin-elf-gcc")
    def test_the_assembly_is_the_c(self):
        folder = os.path.join(HERE, "..", "usbhost")
        with open(os.path.join(folder, "usbhost.gen.S")) as f:
            self.assertEqual(f.read(), pages_build.compiled(os.path.abspath(folder), "usbhost.c"))

    def test_every_branch_goes_to_its_hook(self):
        for e in RECORD["edits"]:
            kind, target = branch(int(e["device_address"], 16), bytes.fromhex(e["new"]))
            self.assertEqual(kind, "CALL" if bytes.fromhex(e["expected"])[1] == 0xE3 else "JUMP.L", e["what"])
            self.assertEqual(target, int(BLOCK["entries"][e["hook"]], 16), e["what"])
        self.assertEqual({e["hook"] for e in RECORD["edits"]}, set(BLOCK["entries"]))

    @unittest.skipUnless(pages_build.GCC and RUN, "no bfin-elf-run")
    def test_the_bytes_run(self):
        sim = os.path.join(HERE, "usbhost_sim")
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, "block.h"), "w") as f:
                for name, at in BLOCK["entries"].items():
                    f.write(f"#define {name[1:].upper()} {at}u\n")
                f.write(f"#define REPORT_AT {BLOCK['state']['report']}u\n#define REPORT_SIZE 362\n")
                f.write('__attribute__((section(".block"), used)) unsigned char block[] = {' + ",".join(map(str, CODE)) + "};\n")
            exe = os.path.join(d, "sim.elf")
            subprocess.run([pages_build.GCC, "-O1", "-mcpu=bf592-none", "-ffreestanding", "-nostdlib", "-I", d, "-T", os.path.join(sim, "sim.ld"),
                            os.path.join(sim, "sim.S"), os.path.join(sim, "sim.c"), "-o", exe, "-lgcc"], check=True, capture_output=True)
            regions = ["0x90000000,0x100000", "0x80c90000,0x10000", "0x80003000,0x1000", "0x8000a000,0x2000", "0x8010b000,0x1000", "0x80027000,0x1000", "0x8003a000,0x3000",
                       "0x80042000,0x1000", "0x81004000,0x1000", "0x8011a000,0x1000", "0x81059000,0x1000", "0x81015000,0x1000", "0x819c2000,0x1000", "0x81200000,0x10000"]
            r = subprocess.run([RUN] + [a for x in regions for a in ("--memory-region", x)] + [exe], capture_output=True, text=True, timeout=120)
            self.assertTrue(r.returncode == 0 and r.stdout.endswith("ok\n"), r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main()
