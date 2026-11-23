#!/usr/bin/env python3
"""Tests for ldr.py and patch.py on small synthetic LDR streams (no TE code), plus read-only checks against the
real 1.2.45 image when it is in Firmware/dumps/.

    python3 -I Firmware/tools/test_tools.py
"""

from __future__ import annotations

import glob
import hashlib
import json
import os
import struct
import sys
import tempfile
import unittest
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ldr  # noqa: E402
import patch  # noqa: E402


def header(flags: int, target: int, count: int, argument: int = 0) -> bytes:
    h = bytearray(struct.pack("<HBBIII", flags, 0, 0xAD, target, count, argument))
    x = 0
    for b in h:
        x ^= b
    h[2] = x  # makes the whole header XOR to zero
    return bytes(h)


def stream() -> bytes:
    """FIRST|IGNORE stream header, two data blocks, a fill, FINAL: the shape of an OP-Z engine or OS image."""
    code = bytes(range(16))
    table = bytes([0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88])
    body = (header(0x0004, 0x80000000, len(code)) + code
            + header(0x0004, 0x80001000, len(table)) + table
            + header(0x0104, 0x80002000, 0x100))
    first = header(0x5004, 0x11A00000, 0, 16 + len(body))
    return first + body + header(0x8004, 0x11A00000, 0)


def record(data: bytes, edits: list[dict], status: str = "TEST") -> dict:
    return {"name": "t", "status": status, "source": {"file": "os.ldr", "size": len(data),
            "sha256": hashlib.sha256(data).hexdigest(), "crc32": zlib.crc32(data)}, "edits": edits}


class Ldr(unittest.TestCase):
    def setUp(self):
        self.data = stream()
        self.tmp = tempfile.NamedTemporaryFile(suffix=".ldr", delete=False)
        self.tmp.write(self.data)
        self.tmp.close()
        self.img = ldr.Image(self.tmp.name)

    def tearDown(self):
        os.unlink(self.tmp.name)

    def test_walk_and_addresses(self):
        self.assertEqual(len(self.img.blocks), 5)
        self.assertEqual([b.flag_names() for b in self.img.blocks],
                         ["FIRST|IGNORE|0x04", "0x04", "0x04", "FILL|0x04", "FINAL|0x04"])
        self.assertEqual(len(self.img.loaded), 2)
        self.assertEqual(self.img.read(0x80001002, 3), bytes([0x33, 0x44, 0x55]))
        self.assertEqual(self.img.offset_of(0x80001000), 16 + 16 + 16 + 16)
        self.assertEqual(self.img.address_of(self.img.offset_of(0x80000005)), 0x80000005)
        with self.assertRaises(ldr.LdrError):
            self.img.offset_of(0x80002000)  # a FILL block has no bytes in the file

    def test_bad_streams_are_refused(self):
        bad = bytearray(self.data)
        bad[16 + 2] ^= 1  # second header's checksum
        with self.assertRaisesRegex(ldr.LdrError, "checksum"):
            ldr.parse(bytes(bad))
        with self.assertRaisesRegex(ldr.LdrError, "truncated"):
            ldr.parse(self.data + b"\x00")  # a stray byte after FINAL
        with self.assertRaisesRegex(ldr.LdrError, "not at the end"):
            long = bytearray(self.data)
            long[16:32] = header(0x0004, 0x80000000, 0x1000)  # a payload that runs past the end of the file
            ldr.parse(bytes(long))
        bad = bytearray(self.data)
        bad[3] = 0xAC
        with self.assertRaisesRegex(ldr.LdrError, "0xAD"):
            ldr.parse(bytes(bad))

    def test_imm48_decoding(self):
        raw = bytes([0x02, 0xDA, 0x83, 0x82, 0x40, 0x5B])
        data = header(0x5004, 0x11A00000, 0, 0) + header(0x0004, 0x80000000, 6) + raw + header(0x8004, 0x11A00000, 0)
        with tempfile.NamedTemporaryFile(suffix=".ldr") as f:
            f.write(data)
            f.flush()
            line = ldr.imm48(ldr.Image(f.name), 0x80000000)
        self.assertIn("0x82835b40", line)


class Patch(unittest.TestCase):
    def setUp(self):
        self.data = stream()
        self.dir = tempfile.mkdtemp()
        self.path = os.path.join(self.dir, "os.ldr")
        with open(self.path, "wb") as f:
            f.write(self.data)
        self.img = ldr.Image(self.path)

    def edit(self, address=0x80001002, expected="33 44", new="aa bb", offset=None):
        return {"what": "test", "device_address": f"0x{address:08x}",
                "file_offset": f"0x{self.img.offset_of(address) if offset is None else offset:x}",
                "expected": expected, "new": new, "evidence": "test"}

    def test_applies_and_keeps_the_stream_valid(self):
        out, log = patch.apply(self.path, [record(self.data, [self.edit()])])
        self.assertEqual(len(log), 1)
        self.assertEqual(out[self.img.offset_of(0x80001002):][:2], bytes([0xAA, 0xBB]))
        self.assertEqual(len(ldr.parse(out)), 5)

    def test_refusals(self):
        cases = {
            "expected": [self.edit(expected="00 00")],
            "the record says": [self.edit(offset=3)],
            "same length|as long": [self.edit(new="aa")],
            "overlaps": [self.edit(), self.edit(address=0x80001003, expected="44 55", new="cc dd")],
            "crosses the end": [self.edit(address=0x80001007, expected="88", new="99")
                                | {"expected": "88 00", "new": "99 00"}],
        }
        for msg, edits in cases.items():
            with self.subTest(msg), self.assertRaisesRegex(patch.PatchError, msg):
                patch.apply(self.path, [record(self.data, edits)])
        with self.assertRaisesRegex(patch.PatchError, "DRAFT"):
            patch.apply(self.path, [record(self.data, [self.edit()], status="DRAFT, do not apply")])
        patch.apply(self.path, [record(self.data, [self.edit()], status="DRAFT")], allow_draft=True)
        other = record(self.data, [self.edit()])
        other["source"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(patch.PatchError, "sha256"):
            patch.apply(self.path, [other])

    def block(self, target=0x80C00000, data=bytes(range(8))):
        return {"what": "test", "target": f"0x{target:08x}", "source": "x.S", "data": data.hex(),
                "sha256": hashlib.sha256(data).hexdigest()}

    def test_adds_a_block_before_final(self):
        rec = record(self.data, [self.edit()]) | {"blocks": [self.block()]}
        out, log = patch.apply(self.path, [rec])
        blocks = ldr.parse(out)
        self.assertEqual(len(blocks), 6)
        self.assertEqual((blocks[-2].target, blocks[-2].count), (0x80C00000, 8))
        self.assertEqual(blocks[-1].flag_names(), "FINAL|0x04")
        self.assertEqual(blocks[0].argument, len(out) - 16)            # the stream header's length follows
        self.assertEqual(out[blocks[-2].data_offset:][:8], bytes(range(8)))
        self.assertEqual(out[self.img.offset_of(0x80001002):][:2], bytes([0xAA, 0xBB]))  # edits untouched

    def test_block_refusals(self):
        cases = {
            "free region": self.block(target=0x80000000),
            "aligned": self.block(target=0x80C00002),
            "sha256": self.block() | {"sha256": "0" * 64},
            "overlaps": None,
        }
        for msg, blk in cases.items():
            blocks = [self.block(), self.block(target=0x80C00004)] if blk is None else [blk]
            with self.subTest(msg), self.assertRaisesRegex(patch.PatchError, msg):
                patch.apply(self.path, [record(self.data, []) | {"blocks": blocks}])

    def test_never_touches_a_header(self):
        # the byte right before the second data block's payload is the end of its header
        e = self.edit()
        e["device_address"] = "0x80001000"
        with self.assertRaises(patch.PatchError):
            bad = dict(e, file_offset=f"0x{self.img.offset_of(0x80001000) - 1:x}")
            patch.apply(self.path, [record(self.data, [bad])])


REAL = sorted(glob.glob(os.path.join(HERE, "..", "dumps", "*", "os.ldr")))


@unittest.skipUnless(REAL, "no os.ldr in Firmware/dumps (read it with op-free's opz_os_read.py)")
class RealImage(unittest.TestCase):
    """Read-only checks of the image read off the author's OP-Z against what op-free documents for 1.2.45."""

    def test_layout_and_known_constant(self):
        img = ldr.Image(REAL[-1])
        self.assertEqual(hashlib.sha256(img.data).hexdigest(),
                         "5be99760c8797bdd4797ed20cfb9a92b6588889d3a81109bae5a45646a9bde07")
        self.assertEqual(len(img.blocks), 164)
        # memory-map.md: the OS's DDR address check loads 0x84000000 at 0x80028394
        self.assertEqual(img.read(0x80028394, 6), bytes.fromhex("01da00840000"))
        self.assertEqual(img.blocks[-1].flag_names(), "FINAL|0x04")


if __name__ == "__main__":
    unittest.main(verbosity=1)
