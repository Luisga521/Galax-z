#!/usr/bin/env python3
"""The red page (pages/), off the OP-Z: its tables are the app's, every groove, progression and dial on the Mac with the sanitizers.
Its Blackfin bytes run in test_pages.py (pages_sim).   python3 -I Firmware/tools/test_groove.py"""
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import groove_data  # noqa: E402


class Groove(unittest.TestCase):
    def test_the_tables_are_the_apps(self):
        with open(groove_data.OUT) as f:
            self.assertEqual(f.read(), groove_data.text())
        self.assertEqual(len(groove_data.grooves()), 69)
        p = dict(groove_data.progressions())
        self.assertEqual((len(groove_data.progressions()), len(p)), (133, 133))
        self.assertEqual(p["ROYAL ROAD"], [(4, "major", False), (5, "major", False), (3, "minor", False), (6, "minor", False)])
        self.assertEqual(p["TRITONE"], [(2, "min7", False), (2, "dom7", True), (1, "maj7", False), (1, "maj7", False)])
        self.assertEqual(len(p["WHOLE SONG"]), 32)
        self.assertEqual(len(p["BLUES"]), 12)

    def test_the_page(self):
        with tempfile.TemporaryDirectory() as d:
            exe = os.path.join(d, "t")
            subprocess.run(["clang", "-O1", "-g", "-fsanitize=address,undefined", "-fno-sanitize-recover=undefined", "-Wall",
                            "-Wno-int-to-pointer-cast", "-Wno-unused-function", "-Wno-format-extra-args", "-o", exe, os.path.join(HERE, "test_groove.c")], check=True)
            r = subprocess.run([exe], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, (r.stdout + r.stderr)[:3000])


if __name__ == "__main__":
    unittest.main()
