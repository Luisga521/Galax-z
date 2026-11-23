#!/usr/bin/env python3
"""The chime (chime/), off the OP-Z: what it sounds like in numbers, and its own Blackfin bytes, sample for sample, in the simulator.
python3 -I Firmware/tools/test_chime.py"""
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
import chime_build  # noqa: E402
import pages_build  # noqa: E402

with open(os.path.join(HERE, "..", "patches", "chime2.json")) as f:
    RECORD = json.load(f)
BLOCK = RECORD["blocks"][0]
CODE, BASE = bytes.fromhex(BLOCK["data"]), int(BLOCK["target"], 16)
RUN = next((p for p in (os.path.expanduser(f"~/opt/{d}/bin/bfin-elf-run") for d in ("bfin-elf", "bfin-elf-gcc")) if os.path.exists(p)), None)


class Chime(unittest.TestCase):
    def mac(self, *args):
        with tempfile.TemporaryDirectory() as d:
            exe = os.path.join(d, "t")
            subprocess.run(["clang", "-O1", "-g", "-fsanitize=address,undefined", "-fno-sanitize-recover=undefined", "-Wall", "-Wno-unused-function", "-Wno-format-extra-args",
                            "-o", exe, os.path.join(HERE, "test_chime.c"), "-lm"], check=True)
            return subprocess.run([exe, *args], capture_output=True, text=True)

    def test_what_it_sounds_like(self):
        r = self.mac()
        self.assertEqual(r.returncode, 0, (r.stdout + r.stderr)[:2000])

    @unittest.skipUnless(os.path.exists(bfin_mini.BIN), "no Blackfin binutils")
    def test_the_record_is_the_source(self):
        self.assertEqual(asm.assemble(os.path.join(HERE, "..", BLOCK["source"]), BASE), CODE)

    @unittest.skipUnless(pages_build.GCC, "no bfin-elf-gcc")
    def test_the_assembly_is_the_c(self):
        with open(os.path.join(chime_build.DIR, "chime.gen.S")) as f:
            text = f.read()
        self.assertEqual(text, pages_build.compiled(chime_build.DIR, "chime.c"))
        self.assertNotIn("LSETUP", text.upper())                # the interrupt's loop registers are the OS's
        self.assertNotIn("CALL", text.upper())

    def test_the_edits_go_to_their_hooks(self):
        for e, hook, was in zip(RECORD["edits"], ("_hook_mix", "_hook_start"), (0x80117CD4, 0x80117B82)):
            new, old, at = bytes.fromhex(e["new"]), bytes.fromhex(e["expected"]), int(e["device_address"], 16)

            def target(code):
                off = code[0] << 16 | code[2] | code[3] << 8
                return at + 2 * (off - ((off & 0x800000) << 1))
            self.assertEqual((new[1], target(new), old[1], target(old)), (0xE3, int(BLOCK["entries"][hook], 16), 0xE3, was))
        self.assertEqual(len(RECORD["edits"]), 2)

    def test_silence_is_the_same_call_left_out(self):
        with open(os.path.join(HERE, "..", "patches", "no-start-sound.json")) as f:
            e, = json.load(f)["edits"]
        self.assertEqual((e["device_address"], e["expected"], e["new"]), (RECORD["edits"][1]["device_address"], RECORD["edits"][1]["expected"], "00 00 00 00"))

    @unittest.skipUnless(pages_build.GCC and RUN, "no bfin-elf-run")
    def test_the_bytes_run(self):
        sim = os.path.join(HERE, "chime_sim")
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, "block.h"), "w") as f:
                f.write(f"#define HOOK_MIX {BLOCK['entries']['_hook_mix']}u\n#define HOOK_START {BLOCK['entries']['_hook_start']}u\n")
                f.write('__attribute__((section(".block"), used)) unsigned char block[] = {' + ",".join(map(str, CODE)) + "};\n")
            exe = os.path.join(d, "sim.elf")
            c = subprocess.run([pages_build.GCC, "-O1", "-mcpu=bf592-none", "-ffreestanding", "-nostdlib", "-I", d, "-T", os.path.join(sim, "sim.ld"),
                                os.path.join(sim, "sim.S"), os.path.join(sim, "sim.c"), "-o", exe, "-lgcc"], capture_output=True, text=True)
            self.assertEqual(c.returncode, 0, c.stderr)
            regions = ["0x90000000,0x100000", "0x80d40000,0x10000", "0x80117000,0x2000"]
            r = subprocess.run([RUN] + [a for x in regions for a in ("--memory-region", x)] + [exe], capture_output=True, text=True, timeout=300)
            self.assertTrue(r.returncode == 0 and r.stdout.endswith("ok\n"), r.stdout[-600:] + r.stderr)
            m = self.mac("sums")
            self.assertEqual(r.stdout, m.stdout)                # every block it changed, sample for sample


if __name__ == "__main__":
    unittest.main()
