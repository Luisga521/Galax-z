#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Derived in part from OP-FREE: its patch-record format (guides/propose-a-firmware-mod.md)
# Copyright (c) 2026 Lourens Smit and the op-z-engines contributors (OP-FREE)
# Copyright (c) 2026 Luis Tosado (this version of it)
"""patch — apply Galax-z OS patch records to your own copy of the OP-Z's OS, offline.

    patch.py check  OS.ldr PATCH.json [PATCH.json ...]            check every record against the image, write nothing
    patch.py build  OS.ldr PATCH.json [PATCH.json ...] --out DIR  write DIR/os.ldr and DIR/os.crc32
                    [--allow-draft]                               (DRAFT records are refused without it)

A record is op-free's draft patch format (op-free guides/propose-a-firmware-mod.md):

    {"name", "status", "description", "revert", "risk",
     "source": {"file": "os.ldr", "firmware": "1.2.45", "size", "sha256", "crc32"},
     "edits": [{"what", "device_address", "file_offset", "expected", "new", "evidence"}],
     "blocks": [{"what", "target", "source", "data", "sha256"}]}        (optional: our own code)

The patcher refuses unless the source image matches the record exactly (size, SHA-256, CRC-32); every edit's file
offset is where its device address lies in the image's LDR block layout (tools/ldr.py); the bytes there are the
`expected` ones; `new` has the same length; no two edits overlap; and no edit touches an LDR block header (which the
OP-Z checks). A block is new data (our own code, assembled from `source`) loaded at `target` by an LDR block of its
own, inserted before the FINAL block; the target must lie in a region nothing in the OS uses (FREE, notes/leds.md),
be 4-byte aligned, and overlap no other block; the stream header's length is raised to match. It writes the result and `os.crc32` (the decimal CRC-32 of the new image, as TE's update writes it)
to DIR, which must be inside a git-ignored folder. It never talks to an OP-Z: writing to the unit is a separate,
strict tool (Firmware/README.md).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import struct
import subprocess
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ldr import Image, LdrError, parse  # noqa: E402


class PatchError(Exception):
    pass


# DDR that nothing in the 1.2.45 OS refers to (op-free research/memory-map.md, notes/leds.md).
FREE = [(0x80C00000, 0x81000000)]
DATA_FLAGS = 0x0004          # what the OS image's own data blocks carry


def block_header(flags: int, target: int, count: int, argument: int = 0) -> bytes:
    h = bytearray(struct.pack("<HBBIII", flags, 0, 0xAD, target, count, argument))
    x = 0
    for b in h:
        x ^= b
    h[2] = x  # the whole header XORs to zero, as the loader checks
    return bytes(h)


def add_blocks(data: bytes, blocks: list[dict], name: str) -> tuple[bytes, list[str]]:
    """Insert each block before the FINAL block and raise the stream header's length to match."""
    if not blocks:
        return data, []
    parsed = parse(data)
    first, final = parsed[0], parsed[-1]
    if not first.flags & 0x4000 or not final.flags & 0x8000 or final.header_offset != len(data) - 16:
        raise PatchError(f"{name}: the image does not start with a FIRST block and end with a FINAL block")
    if first.argument != len(data) - 16:
        raise PatchError(f"{name}: the stream header's length is {first.argument}, the stream is {len(data) - 16}")
    used = [(b.target, b.target + b.count) for b in parsed if b.count and not b.flags & 0x1000]
    log, inserted = [], b""
    for i, blk in enumerate(blocks):
        where = f"{name} block {i + 1} ({blk.get('what', '')})"
        target, payload = int(blk["target"], 16), bytes.fromhex(blk["data"])
        if hashlib.sha256(payload).hexdigest() != blk.get("sha256"):
            raise PatchError(f"{where}: data does not match its sha256")
        end = target + len(payload)
        if not payload or target % 4 or len(payload) % 4:
            raise PatchError(f"{where}: target and size must be 4-byte aligned and not empty")
        if not any(a <= target and end <= b for a, b in FREE):
            raise PatchError(f"{where}: 0x{target:08x}-0x{end:08x} is not inside a free region")
        if any(a < end and target < b for a, b in used):
            raise PatchError(f"{where}: overlaps another block")
        used.append((target, end))
        inserted += block_header(DATA_FLAGS, target, len(payload)) + payload
        log.append(f"{where}: {len(payload)} bytes at 0x{target:08x}, sha256 {blk['sha256'][:16]}…")
    head = block_header(first.flags, first.target, first.count, first.argument + len(inserted))
    return head + data[16:final.header_offset] + inserted + data[final.header_offset:], log


def describe(data: bytes) -> dict:
    return {"size": len(data), "sha256": hashlib.sha256(data).hexdigest(), "crc32": zlib.crc32(data)}


def apply(image_path: str, records: list[dict], allow_draft: bool = False) -> tuple[bytes, list[str]]:
    img = Image(image_path)
    src = describe(img.data)
    out = bytearray(img.data)
    log, touched = [], []
    headers = [(b.header_offset, b.header_offset + 16) for b in img.blocks]
    for rec in records:
        name = rec.get("name", "?")
        status = str(rec.get("status", ""))
        if status.upper().startswith("DRAFT") and not allow_draft:
            raise PatchError(f"{name}: status is {status!r}: refused (--allow-draft builds it for offline checks)")
        want = rec.get("source", {})
        for key in ("size", "sha256", "crc32"):
            if want.get(key) != src[key]:
                raise PatchError(f"{name}: the image's {key} is {src[key]}, the record needs {want.get(key)}")
        for i, e in enumerate(rec.get("edits", [])):
            where = f"{name} edit {i + 1} ({e.get('what', '')})"
            address = int(e["device_address"], 16)
            offset = int(e["file_offset"], 16)
            try:
                mapped = img.offset_of(address)
            except LdrError as err:
                raise PatchError(f"{where}: {err}") from None
            if mapped != offset:
                raise PatchError(f"{where}: 0x{address:08x} is at file offset 0x{mapped:x}, the record says 0x{offset:x}")
            expected, new = bytes.fromhex(e["expected"]), bytes.fromhex(e["new"])
            if len(new) != len(expected) or not new:
                raise PatchError(f"{where}: `new` must be as long as `expected` and not empty")
            span = (offset, offset + len(new))
            if img.block_of(address + len(new) - 1) is not img.block_of(address):
                raise PatchError(f"{where}: crosses the end of its LDR block")
            if any(a < span[1] and span[0] < b for a, b in headers):
                raise PatchError(f"{where}: touches an LDR block header")
            if any(a < span[1] and span[0] < b for a, b in touched):
                raise PatchError(f"{where}: overlaps another edit")
            if bytes(out[span[0]:span[1]]) != expected:
                raise PatchError(f"{where}: expected {expected.hex(' ')}, found {bytes(out[span[0]:span[1]]).hex(' ')}")
            out[span[0]:span[1]] = new
            touched.append(span)
            log.append(f"{where}: 0x{address:08x} (file 0x{offset:x}) {expected.hex(' ')} -> {new.hex(' ')}")
        new, blog = add_blocks(bytes(out), rec.get("blocks", []), name)
        out = bytearray(new)
        log += blog
    parse(bytes(out))  # the result must still walk exactly like the original
    return bytes(out), log


def ignored_by_git(path: str) -> bool:
    folder = os.path.abspath(path)
    try:
        subprocess.run(["git", "-C", os.path.dirname(folder), "rev-parse"], check=True, capture_output=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        return True  # not in a git checkout
    probe = os.path.join(folder, "os.ldr")
    return subprocess.run(["git", "-C", os.path.dirname(folder), "check-ignore", "-q", probe]).returncode == 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["check", "build"])
    ap.add_argument("image")
    ap.add_argument("patches", nargs="+")
    ap.add_argument("--out")
    ap.add_argument("--allow-draft", action="store_true")
    a = ap.parse_args(argv)
    try:
        records = []
        for p in a.patches:
            with open(p) as f:
                records.append(json.load(f))
        data, log = apply(a.image, records, a.allow_draft)
        for line in log:
            print(line)
        info = describe(data)
        print(f"result: {info['size']} bytes, sha256 {info['sha256']}, crc32 {info['crc32']}")
        if a.cmd == "build":
            if not a.out:
                raise PatchError("build needs --out DIR")
            if not ignored_by_git(a.out):
                raise PatchError(f"{a.out} is not git-ignored: TE's code must never reach a commit")
            os.makedirs(a.out, exist_ok=True)
            with open(os.path.join(a.out, "os.ldr"), "wb") as f:
                f.write(data)
            with open(os.path.join(a.out, "os.crc32"), "w") as f:
                f.write(str(info["crc32"]))
            print(f"wrote {a.out}/os.ldr and os.crc32")
    except (PatchError, LdrError, KeyError, ValueError, json.JSONDecodeError) as e:
        print(f"refused: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
