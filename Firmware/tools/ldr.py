#!/usr/bin/env python3
"""ldr — read the OP-Z's OS image (a Blackfin+ LDR boot stream) offline: blocks, addresses, bytes, code, strings.

    ldr.py map     OS.ldr                       every block: flags, target, size, file offset
    ldr.py where   OS.ldr 0x80028394            the file offset of a device address (and its block)
    ldr.py bytes   OS.ldr 0x80028394 [N]        N bytes (default 32) at a device address
    ldr.py dis     OS.ldr 0x80028394 [N]        disassemble N bytes (default 64) with bfin-elf-objdump
    ldr.py strings OS.ldr [--min 6] [--grep RE] printable strings with their device addresses
    ldr.py find    OS.ldr HEXBYTES              every device address where these bytes occur
    ldr.py calls   OS.ldr 0x80131700            every CALL / JUMP.L (pc-relative, 32-bit) whose target is this address

A block is a 16-byte header `flags u16 | xor-checksum u8 | 0xAD | target u32 | count u32 | argument u32`, little-
endian, followed by `count` payload bytes unless it is a FILL block (op-free research/OPZ_FIRMWARE_MAP.md §5). Every
header must carry 0xAD in byte 3 and XOR to zero, and the walk must end exactly at the end of the file: the same
checks the OP-Z's own loader makes. Flags (Blackfin+ boot stream): 0x8000 FINAL, 0x4000 FIRST, 0x2000 INDIRECT,
0x1000 IGNORE, 0x0800 INIT, 0x0400 CALLBACK, 0x0200 QUICKBOOT, 0x0100 FILL.

Reads files only: never talks to an OP-Z. Python 3 standard library; `dis` needs ~/opt/bfin-elf (binutils 2.47).
"""

from __future__ import annotations

import argparse
import os
import re
import struct
import subprocess
import sys
import tempfile
from dataclasses import dataclass

FLAGS = [(0x8000, "FINAL"), (0x4000, "FIRST"), (0x2000, "INDIRECT"), (0x1000, "IGNORE"), (0x0800, "INIT"),
         (0x0400, "CALLBACK"), (0x0200, "QUICKBOOT"), (0x0100, "FILL")]
FILL, IGNORE = 0x0100, 0x1000
OBJDUMP = os.path.expanduser("~/opt/bfin-elf/bin/bfin-elf-objdump")


class LdrError(Exception):
    pass


@dataclass(frozen=True)
class Block:
    index: int
    header_offset: int
    flags: int
    target: int
    count: int
    argument: int

    @property
    def has_payload(self) -> bool:
        return not self.flags & FILL

    @property
    def loaded(self) -> bool:
        """Its payload lands in memory at `target` (not FILL, not IGNORE, not empty)."""
        return self.has_payload and not self.flags & IGNORE and self.count > 0

    @property
    def data_offset(self) -> int:
        return self.header_offset + 16

    def flag_names(self) -> str:
        names = [n for bit, n in FLAGS if self.flags & bit]
        low = self.flags & 0xFF
        return "|".join(names + ([f"0x{low:02x}"] if low else [])) or "data"


def parse(data: bytes) -> list[Block]:
    blocks, at = [], 0
    while at < len(data):
        if at + 16 > len(data):
            raise LdrError(f"truncated header at 0x{at:x}")
        header = data[at:at + 16]
        if header[3] != 0xAD:
            raise LdrError(f"bad header at 0x{at:x}: byte 3 is 0x{header[3]:02x}, not 0xAD")
        x = 0
        for b in header:
            x ^= b
        if x != 0:
            raise LdrError(f"bad header checksum at 0x{at:x}")
        flags = struct.unpack_from("<H", header, 0)[0]
        target, count, argument = struct.unpack_from("<III", header, 4)
        block = Block(len(blocks), at, flags, target, count, argument)
        blocks.append(block)
        at += 16 + (count if block.has_payload else 0)
    if at != len(data):
        raise LdrError(f"the walk ends at 0x{at:x}, not at the end of the file (0x{len(data):x})")
    return blocks


class Image:
    def __init__(self, path: str):
        with open(path, "rb") as f:
            self.data = f.read()
        self.blocks = parse(self.data)
        self.loaded = [b for b in self.blocks if b.loaded]

    def block_of(self, address: int) -> Block | None:
        """The last loaded block covering `address` (a later block overwrites an earlier one)."""
        hit = None
        for b in self.loaded:
            if b.target <= address < b.target + b.count:
                hit = b
        return hit

    def offset_of(self, address: int) -> int:
        b = self.block_of(address)
        if b is None:
            raise LdrError(f"0x{address:08x} is not in any loaded block")
        return b.data_offset + (address - b.target)

    def read(self, address: int, n: int) -> bytes:
        b = self.block_of(address)
        if b is None or address + n > b.target + b.count:
            raise LdrError(f"0x{address:08x}+{n} is not inside one loaded block")
        o = b.data_offset + (address - b.target)
        return self.data[o:o + n]

    def address_of(self, offset: int) -> int | None:
        for b in self.loaded:
            if b.data_offset <= offset < b.data_offset + b.count:
                return b.target + (offset - b.data_offset)
        return None


def cmd_map(img: Image) -> None:
    print(f"{len(img.blocks)} blocks, {len(img.loaded)} loaded, {len(img.data)} bytes")
    print("  #  flags                 target      count       argument    file offset")
    for b in img.blocks:
        print(f"{b.index:3d}  {b.flag_names():20s}  0x{b.target:08x}  0x{b.count:08x}  0x{b.argument:08x}  "
              f"0x{b.header_offset:06x}")


def imm48(img: Image, address: int) -> str | None:
    """Blackfin+'s 48-bit constant load `0xDA0r hi lo` (op-free memory-map.md), which GNU objdump calls ILLEGAL:
    `02 da 83 82 40 5b` loads 0x82835b40."""
    try:
        raw = img.read(address, 6)
    except LdrError:
        return None
    if raw[1] != 0xDA or raw[0] & 0xF0:
        return None
    hi, lo = struct.unpack_from("<HH", raw, 2)
    return f"{address:8x}:\t{raw.hex(' ')} \tIMM48 r{raw[0] & 0x0F} = 0x{hi << 16 | lo:08x};   (Blackfin+ 48-bit load)"


def cmd_dis(img: Image, address: int, n: int) -> None:
    if not os.path.exists(OBJDUMP):
        raise LdrError(f"{OBJDUMP} not found (build binutils for bfin-elf first)")
    b = img.block_of(address)
    if b is None:
        raise LdrError(f"0x{address:08x} is not in any loaded block")
    stop = min(address + n, b.target + b.count)
    payload = img.data[b.data_offset:b.data_offset + b.count]
    with tempfile.NamedTemporaryFile(suffix=".bin") as tmp:
        tmp.write(payload)
        tmp.flush()
        at = address
        while at < stop: # objdump from `at`; a 48-bit load is printed by us and objdump restarts after it
            out = subprocess.run([OBJDUMP, "-D", "-b", "binary", "-m", "bfin", f"--adjust-vma=0x{b.target:x}",
                                  f"--start-address=0x{at:x}", f"--stop-address=0x{stop:x}", tmp.name],
                                 capture_output=True, text=True, check=True).stdout
            restart = None
            for line in out.splitlines():
                m = re.match(r"\s*([0-9a-f]+):", line)
                if not m:
                    continue
                here = int(m.group(1), 16)
                decoded = imm48(img, here)
                if decoded:
                    print(decoded)
                    restart = here + 6
                    break
                print(line)
            if restart is None:
                break
            at = restart


def cmd_strings(img: Image, minimum: int, pattern: str | None) -> None:
    rx = re.compile(pattern, re.I) if pattern else None
    for b in img.loaded:
        payload = img.data[b.data_offset:b.data_offset + b.count]
        for m in re.finditer(rb"[\x20-\x7e]{%d,}" % minimum, payload):
            s = m.group().decode()
            if rx is None or rx.search(s):
                print(f"0x{b.target + m.start():08x}  {s}")


def calls_to(img: Image, target: int) -> list[tuple[int, str]]:
    """32-bit pc-relative CALL (0xE3) and JUMP.L (0xE2): first half-word 0xE2hh/0xE3hh, then the low 16 bits of a
    24-bit signed half-word offset from the instruction's own address."""
    hits = []
    for b in img.loaded:
        payload = img.data[b.data_offset:b.data_offset + b.count]
        for i in range(0, len(payload) - 3, 2):
            if payload[i + 1] not in (0xE2, 0xE3):
                continue
            off = payload[i] << 16 | payload[i + 2] | payload[i + 3] << 8
            if off & 0x800000:
                off -= 1 << 24
            here = b.target + i
            if here + 2 * off == target:
                hits.append((here, "CALL" if payload[i + 1] == 0xE3 else "JUMP.L"))
    return hits


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("map", "where", "bytes", "dis", "strings", "find", "calls"):
        p = sub.add_parser(name)
        p.add_argument("image")
        if name in ("where", "bytes", "dis", "calls"):
            p.add_argument("address", type=lambda s: int(s, 0))
        if name in ("bytes", "dis"):
            p.add_argument("n", type=int, nargs="?", default=32 if name == "bytes" else 64)
        if name == "strings":
            p.add_argument("--min", type=int, default=6)
            p.add_argument("--grep")
        if name == "find":
            p.add_argument("hex")
    a = ap.parse_args(argv)
    try:
        img = Image(a.image)
        if a.cmd == "map":
            cmd_map(img)
        elif a.cmd == "where":
            b = img.block_of(a.address)
            print(f"0x{a.address:08x} -> file offset 0x{img.offset_of(a.address):06x} (block {b.index}, "
                  f"0x{b.target:08x}+0x{b.count:x})")
        elif a.cmd == "bytes":
            print(img.read(a.address, a.n).hex(" "))
        elif a.cmd == "dis":
            cmd_dis(img, a.address, a.n)
        elif a.cmd == "strings":
            cmd_strings(img, a.min, a.grep)
        elif a.cmd == "calls":
            for here, kind in calls_to(img, a.address):
                print(f"0x{here:08x}  {kind} 0x{a.address:08x}")
        elif a.cmd == "find":
            needle = bytes.fromhex(a.hex)
            for b in img.loaded:
                payload = img.data[b.data_offset:b.data_offset + b.count]
                for m in re.finditer(re.escape(needle), payload):
                    print(f"0x{b.target + m.start():08x}")
    except LdrError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
