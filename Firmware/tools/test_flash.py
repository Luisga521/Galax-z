#!/usr/bin/env python3
"""Tests for flash.py against fake_console.py (no OP-Z, no TE code), plus offline checks of the real images when
TE's os.ldr is in Firmware/dumps/.

    python3 -I Firmware/tools/test_flash.py
"""

from __future__ import annotations

import os
import sys
import unittest
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import flash  # noqa: E402
import ldr  # noqa: E402
from fake_console import FakeConsole  # noqa: E402

# Synthetic images: every byte value (C0 and 7D included), sizes off and on the 2,048-byte piece boundary.
OLD = bytes(range(256)) * 20 + b"\xc0\x7d" * 3            # 5126 bytes
NEW = bytes(reversed(OLD))[:4096]                          # exactly two pieces
IMAGES = {"original": flash.Image("original", "old", OLD), "next": flash.Image("next", "new", NEW),
          "draft": flash.Image("draft", "draft", None, reason="DRAFT records: x")}


def console(fake, out=None):
    return flash.Console(fake, flash.allowed(IMAGES), out or (lambda line: None))


def installed(im):
    return {"os.ldr": im.ldr, "os.crc32": im.crc}


class Frames(unittest.TestCase):
    def test_fixed_frames(self):
        self.assertEqual(flash.PING.hex(" "), "c0 01 00 00 00 00 00")
        self.assertEqual(flash.READ["os.ldr"], bytes.fromhex("c0 01 19 00 00 00 07") + b"os.ldr\0")
        self.assertEqual({f[2] for f in flash.FIXED}, {0x00, 0x19})

    def test_never_types_refused(self):
        for t in sorted(flash.NEVER) + [0x17, 0x21, 0x27, 0x02]:
            with self.assertRaises(flash.Refused):
                flash.frame(t)

    def test_header_counts_name_and_data(self):
        h = flash.write_header("os.ldr", 828136)
        # len = 4 + 7 + 828136 = 828147 = 0x000CA2F3; size 828136 = 0x000CA2E8
        self.assertEqual(h, bytes.fromhex("c0 01 11 00 0c a2 f3 00 0c a2 e8") + b"os.ldr\0")
        self.assertEqual(flash.decode_write(h + flash.escape(b"\xc0" * 828136))[0], "os.ldr")

    def test_send_refuses_anything_not_fixed(self):
        con = console(FakeConsole())
        for wire in (flash.write_header("os.ldr", 0), bytes.fromhex("c0 01 15 00 00 00 00"), flash.PING + b"\0"):
            with self.assertRaises(flash.Refused):
                con.send(wire)

    def test_write_refuses_unknown_data_and_names(self):
        con = console(FakeConsole())
        with self.assertRaises(flash.Refused):
            con.write_file("os.ldr", OLD + b"x")
        with self.assertRaises(flash.Refused):
            con.write_file("os.crc32", b"12345")
        with self.assertRaises(flash.Refused):
            con.write_file("bootloader.ldr", OLD)


class Flash(unittest.TestCase):
    def test_round_trip_changes_nothing(self):
        fake = FakeConsole(installed(IMAGES["original"]))
        flash.flash(console(fake), IMAGES, "original")
        self.assertEqual(fake.files, installed(IMAGES["original"]))
        self.assertEqual(set(fake.types), {0x00, 0x19, 0x11})
        self.assertEqual(fake.forbidden, [])

    def test_new_image_and_its_crc(self):
        fake = FakeConsole(installed(IMAGES["original"]))
        flash.flash(console(fake), IMAGES, "next")
        self.assertEqual(fake.files["os.ldr"], NEW)
        self.assertEqual(fake.files["os.crc32"], str(zlib.crc32(NEW)).encode())

    def test_draft_and_unknown_labels_refused(self):
        for label in ("draft", "nope"):
            fake = FakeConsole(installed(IMAGES["original"]))
            with self.assertRaises(flash.Refused):
                flash.flash(console(fake), IMAGES, label)
            self.assertEqual(fake.types, [])

    def test_unknown_installed_os_only_takes_original(self):
        fake = FakeConsole({"os.ldr": b"half an image", "os.crc32": b"1"})
        with self.assertRaises(flash.Refused):
            flash.flash(console(fake), IMAGES, "next")
        self.assertNotIn(0x11, fake.types)
        flash.flash(console(FakeConsole({"os.ldr": b"half"})), IMAGES, "original")

    def test_missing_answer_stops_everything(self):
        fake = FakeConsole(installed(IMAGES["original"]), drop_reply_after=1)
        con = console(fake)
        with self.assertRaises(flash.Stalled):
            flash.flash(con, IMAGES, "original")   # 3 pieces: the second one's answer never comes
        sent = len(fake.types)
        with self.assertRaises(flash.Stalled):
            con._write(flash.PING)
        self.assertEqual(len(fake.types), sent)

    def test_bad_read_back_is_reported(self):
        fake = FakeConsole(installed(IMAGES["original"]), corrupt_at=3000)
        with self.assertRaisesRegex(flash.Refused, "DIFFERENT"):
            flash.flash(console(fake), IMAGES, "original")

    def test_check_names_the_installed_image(self):
        self.assertEqual(flash.check(console(FakeConsole(installed(IMAGES["next"]))), IMAGES), "next")


ORIGINAL = flash.find_original()


@unittest.skipUnless(ORIGINAL, "TE's os.ldr is not in Firmware/dumps/")
class RealImages(unittest.TestCase):
    def test_builds(self):
        images = flash.load_images(ORIGINAL)
        self.assertEqual(flash.sha(images["original"].ldr), flash.ORIGINAL["sha256"])
        self.assertEqual(images["original"].crc, b"2403806141")
        for im in images.values():
            self.assertIsNotNone(im.ldr, f"{im.label}: {im.reason}")
            ldr.parse(im.ldr)                                    # every build still walks as an LDR stream
        walker = images["led-walker"].ldr
        self.assertIn(b"GALAXZ-WALKER-1", walker)
        self.assertEqual(walker[0x80186:][:4], bytes.fromhex("57e311ab"))

    def test_real_round_trip_on_the_fake(self):
        images = flash.load_images(ORIGINAL)
        fake = FakeConsole(installed(images["original"]))
        flash.flash(flash.Console(fake, flash.allowed(images), lambda line: None), images, "original")
        self.assertEqual(fake.files["os.ldr"], images["original"].ldr)


if __name__ == "__main__":
    unittest.main()
