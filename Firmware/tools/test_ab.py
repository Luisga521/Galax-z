#!/usr/bin/env python3
"""The A/B bars' assembled code (patches/ab-bars.json), run on fake OP-Z memory.   python3 -I Firmware/tools/test_ab.py"""

import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asm  # noqa: E402
import bfin_mini  # noqa: E402

BLOCK = json.load(open(os.path.join(HERE, "..", "patches", "ab-bars.json")))["blocks"][0]
BASE, CODE = int(BLOCK["target"], 16), bytes.fromhex(BLOCK["data"])
SEQ, RECORDS, PTR, NEXT = 0x80200000, 0x0802D3A4, 0x81059D1C, 0x8003C6C8
WHITE, B = (0, 0, 0, 255), (0xB0, 0x40, 0xFF, 0)


def words(addr, v):
    return {addr + i: v >> 8 * i & 0xFF for i in range(4)}


@unittest.skipUnless(os.path.exists(bfin_mini.BIN), "no Blackfin binutils")
class ABBars(unittest.TestCase):
    def run_it(self, leds, pattern=0, screen=SEQ + 0x346260, seq=SEQ):
        mem = {RECORDS + i: 0 for i in range(265)}
        for led, rgbw in leds.items():
            mem.update({RECORDS + led * 5 + k: v for k, v in enumerate(rgbw)})
        mem |= words(PTR, seq) | words(SEQ + 0x3463BC, screen) | words(SEQ + 0x44, pattern & 0xFFFFFFFF)
        m = bfin_mini.Machine(CODE, BASE, mem)
        m.reg["R0"] = 0x12345678                                # the callee's argument
        self.assertEqual(m.run(BASE), NEXT)
        self.assertEqual(m.reg["R0"], 0x12345678)
        self.assertLessEqual(set(m.reg), {"R0", "R1", "R2", "R3", "P0", "P1", "P2"})
        self.assertTrue(all(RECORDS <= a < RECORDS + 80 and (a - RECORDS) % 5 < 4 for a in m.writes), m.writes)
        return {i: tuple(m.mem[RECORDS + i * 5 + k] for k in range(4)) for i in range(53)}, m

    def test_playhead_takes_the_parts_colour(self):
        for pattern, colour in ((0, WHITE), (1, B), (2, WHITE), (16, WHITE), (17, B), (158, WHITE), (159, B)):
            for step in (0, 7, 15):
                out, m = self.run_it({step: WHITE}, pattern)
                self.assertEqual(out[step], colour, (pattern, step))
                self.assertEqual(bool(m.writes), colour == B)   # A: nothing is written
                self.assertTrue(all(v == (0, 0, 0, 0) for i, v in out.items() if i != step))

    def test_everything_else_keeps_its_colour(self):
        leds = {1: (255, 0, 0, 0), 2: (0, 217, 255, 0), 3: (127, 0, 255, 0), 4: (140, 245, 0, 0), 5: (1, 0, 0, 200),
                16: (0, 0, 0, 255), 39: (0, 0, 0, 255), 40: (0, 0, 0, 90), 48: (255, 0, 0, 0), 50: (0, 0, 0, 255)}
        out, m = self.run_it(leds, 1)
        for i, v in leds.items():
            self.assertEqual(out[i], v, i)
        self.assertEqual(m.writes, set())

    def test_brightness_is_kept(self):
        out, _ = self.run_it({3: (0, 0, 0, 127), 4: (0, 0, 0, 1)}, 1)
        self.assertEqual(out[3], (88, 32, 127, 0))
        self.assertTrue(all(v <= 2 for v in out[4]))

    def test_only_on_the_step_screen(self):
        for screen in (0, SEQ + 0x3462AC, SEQ + 0x3462F0, 0xDEADBEEF):
            _, m = self.run_it({3: (0, 0, 0, 255)}, 1, screen=screen)
            self.assertEqual(m.writes, set())

    def test_no_sequencer_yet(self):
        _, m = self.run_it({3: (0, 0, 0, 255)}, 1, seq=0)
        self.assertEqual(m.writes, set())

    def test_all_sixteen_at_once_is_short(self):
        out, m = self.run_it({i: (0, 0, 0, 255) for i in range(16)}, 1)
        self.assertTrue(all(out[i] == B for i in range(16)))
        self.assertLess(m.steps, 600)                           # instructions per UI frame, at worst

    def test_the_record_is_the_source(self):
        self.assertEqual(asm.assemble(os.path.join(HERE, "..", BLOCK["source"]), BASE), CODE)


if __name__ == "__main__":
    unittest.main()
