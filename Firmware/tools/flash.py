#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Derived in part from OP-FREE: its framing and port reading follow tools/opz_os_read.py
# Copyright (c) 2026 Lourens Smit and the op-z-engines contributors (OP-FREE)
# Copyright (c) 2026 Luis Tosado (this version of it)
"""flash — the strict update-mode writer: puts a known OS image on the OP-Z, and nothing else.

    flash.py images                         every image it knows, offline: label, SHA-256, CRC-32, flashable or why not
    flash.py frames                         every fixed frame it can send, and the shape of a write; opens no port
    flash.py check  [--port P]              ping, read os.crc32 and os.ldr, name the image installed (read-only)
    flash.py flash  LABEL [--port P] [--yes] [--dry-run]
                                            write LABEL's os.crc32 then os.ldr, reading each back byte for byte

LABEL is `original` (TE's 1.2.45, read off this unit) or a build in Firmware/builds/ (e.g. `galaxz-v1`).
`flash original` is also the way back. The OP-Z must be in update mode (hold SCREEN while switching on).

WHAT IT CAN SEND (Firmware/README.md, the single-unit protocol, step 3)
  Fixed at import, nothing else passes `Console.send`:
    C0 01 00 00000000                ping
    C0 01 19 <len> os.ldr 00         read /yaffs2/os.ldr        (and the same for os.crc32)
  And `0x11` writes, built only by `Console.write_file`, which refuses unless the name is os.ldr or os.crc32 and the
  data's SHA-256 is one of the images below (os.crc32: the decimal CRC-32 of one of their os.ldr). Every frame is
  decoded again before it leaves, and any type in NEVER is refused wherever it appears.

  An image is flashable when it is TE's 1.2.45 (SHA-256 checked) or a build of patch records applied to it by
  patch.py, none of them DRAFT.

THE WRITE COMMAND (read 2026-11-21 in this unit's bootloader, read off its SPI flash with 0x17; notes/update-write.md)
  C0 01 11 <len u32 BE> <size u32 BE> <name> 00 <data>, everything after C0 escaped (C0/7D -> 7D, byte ^ 0x20).
  <len> counts everything after the header: 4 + name + 1 + data. The name's zero byte opens /yaffs2/<name> with
  "w+b" (the old file is gone from here on); the data is written in 2,048-byte pieces, each answered with an empty
  type-0x12 frame; after the last byte the file is closed and synced and a type-0x13 frame comes back.
  This tool sends one piece, then waits for its answer. If an answer does not come it stops sending anything at all
  (a frame sent into an open upload would become file data): switch off, back into update mode, flash again.

Runs and backups go to Firmware/dumps/flash-<UTC time>/ (git-ignored). Needs pyserial except for images, frames and
--dry-run (Firmware/flash sets that up).
"""

from __future__ import annotations

import argparse
import datetime
import glob
import hashlib
import json
import os
import subprocess
import sys
import time
import zlib
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import patch  # noqa: E402

FIRMWARE = HERE.parent
BUILDS = FIRMWARE / "builds"
PATCHES = FIRMWARE / "patches"

START, ESCAPE, ESCAPE_XOR = 0xC0, 0x7D, 0x20
ROUTING_HOST = 0x01
TYPE_PING, TYPE_WRITE, TYPE_READ, TYPE_LOG = 0x00, 0x11, 0x19, 0x04
REPLY_PONG, REPLY_PIECE, REPLY_WRITTEN, REPLY_READ = 0x01, 0x12, 0x13, 0x20
ALLOWED_TYPES = frozenset((TYPE_PING, TYPE_READ, TYPE_WRITE))
# Formats or writes SPI flash, formats the NAND, upgrades, deletes, renames, runs code, unknown, power/reset.
NEVER = frozenset((0x06, 0x10, 0x14, 0x15, 0x23, 0x29, 0x31, 0x34, 0x37, 0x3B))
NAMES = ("os.ldr", "os.crc32")
PIECE = 2048

ORIGINAL = {"firmware": "1.2.45", "size": 828136, "crc32": 2403806141,
            "sha256": "5be99760c8797bdd4797ed20cfb9a92b6588889d3a81109bae5a45646a9bde07"}


class Refused(Exception):
    pass


class Stalled(Exception):
    """An upload is open on the OP-Z and did not finish. Nothing more may be sent until it is switched off."""


# ---------------------------------------------------------------- frames

def escape(data: bytes) -> bytes:
    out = bytearray()
    for b in data:
        if b in (START, ESCAPE):
            out += bytes((ESCAPE, b ^ ESCAPE_XOR))
        else:
            out.append(b)
    return bytes(out)


def unescape(data: bytes) -> bytes:
    out, esc = bytearray(), False
    for b in data:
        if esc:
            out.append(b ^ ESCAPE_XOR)
            esc = False
        elif b == ESCAPE:
            esc = True
        elif b == START:
            raise Refused("a raw C0 inside a frame")
        else:
            out.append(b)
    if esc:
        raise Refused("a frame ends inside an escape")
    return bytes(out)


def frame(mtype: int, payload: bytes = b"") -> bytes:
    if mtype in NEVER or mtype not in ALLOWED_TYPES:
        raise Refused(f"type 0x{mtype:02x} is never sent")
    body = bytes((ROUTING_HOST, mtype)) + len(payload).to_bytes(4, "big") + payload
    return bytes((START,)) + escape(body)


PING = frame(TYPE_PING)
READ = {n: frame(TYPE_READ, n.encode() + b"\0") for n in NAMES}
FIXED = frozenset((PING, *READ.values()))


def write_header(name: str, size: int) -> bytes:
    """C0 and the escaped header, size and name up to its zero byte: on that byte the OP-Z opens the file."""
    if name not in NAMES:
        raise Refused(f"{name!r} is not one of {NAMES}")
    raw = name.encode()
    body = (bytes((ROUTING_HOST, TYPE_WRITE)) + (4 + len(raw) + 1 + size).to_bytes(4, "big")
            + size.to_bytes(4, "big") + raw + b"\0")
    return bytes((START,)) + escape(body)


def decode_write(wire: bytes) -> tuple[str, bytes]:
    """Read a whole write frame back the way the OP-Z's parser does; refuse anything else."""
    if wire[:1] != bytes((START,)):
        raise Refused("a frame must start with C0")
    body = unescape(wire[1:])
    if len(body) < 11 or body[0] != ROUTING_HOST or body[1] != TYPE_WRITE:
        raise Refused(f"not a write frame: {body[:2].hex(' ')}")
    length, size = int.from_bytes(body[2:6], "big"), int.from_bytes(body[6:10], "big")
    end = body.find(b"\0", 10)
    if end < 0:
        raise Refused("the name has no zero byte")
    name, data = body[10:end].decode("ascii", "replace"), body[end + 1:]
    if name not in NAMES or len(data) != size or length != 4 + len(name) + 1 + size:
        raise Refused(f"inconsistent write frame: name {name!r}, size {size}, length {length}, data {len(data)}")
    return name, data


# ---------------------------------------------------------------- images

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


@dataclass(frozen=True)
class Image:
    label: str
    title: str
    ldr: bytes | None          # None: not flashable (see reason)
    reason: str = ""
    patches: tuple[str, ...] = ()

    @property
    def crc(self) -> bytes:
        return str(zlib.crc32(self.ldr)).encode()

    def files(self) -> dict[str, bytes]:
        return {"os.crc32": self.crc, "os.ldr": self.ldr}


def roots() -> list[Path]:
    """This checkout and, from a worktree, the main checkout: TE's files live only in the main one's dumps/."""
    out = [FIRMWARE.parent]
    try:
        common = subprocess.run(["git", "-C", str(HERE), "rev-parse", "--path-format=absolute", "--git-common-dir"],
                                capture_output=True, text=True, check=True).stdout.strip()
        main = Path(common).parent
        if main not in out:
            out.append(main)
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    return out


def dumps_dir() -> Path:
    for r in roots():
        d = r / "Firmware" / "dumps"
        if d.is_dir():
            return d
    return roots()[0] / "Firmware" / "dumps"


def find_original() -> Path | None:
    for r in roots():
        for p in sorted(glob.glob(str(r / "Firmware" / "dumps" / "**" / "os.ldr"), recursive=True)):
            if os.path.getsize(p) == ORIGINAL["size"] and sha(Path(p).read_bytes()) == ORIGINAL["sha256"]:
                return Path(p)
    return None


def load_images(original: Path | None = None) -> dict[str, Image]:
    original = original or find_original()
    if original is None:
        raise Refused("TE's 1.2.45 os.ldr (read off the unit) is not in Firmware/dumps/: nothing can be flashed")
    data = original.read_bytes()
    if sha(data) != ORIGINAL["sha256"]:
        raise Refused(f"{original} is not TE's 1.2.45 os.ldr")
    images = {"original": Image("original", "TE 1.2.45 (original)", data)}
    for path in sorted(BUILDS.glob("*.json")):
        b = json.loads(path.read_text())
        label, names = path.stem, tuple(b["patches"])
        title = b.get("title", label)
        try:
            records = [json.loads((PATCHES / n).read_text()) for n in names]
            drafts = [r["name"] for r in records if str(r.get("status", "")).upper().startswith("DRAFT")]
            if drafts:
                raise patch.PatchError(f"DRAFT records: {', '.join(drafts)}")
            ldr, _ = patch.apply(str(original), records)
            images[label] = Image(label, title, ldr, patches=names)
        except (patch.PatchError, OSError, KeyError, ValueError) as e:
            images[label] = Image(label, title, None, reason=str(e), patches=names)
    return images


def allowed(images: dict[str, Image]) -> frozenset[tuple[str, str]]:
    out = set()
    for im in images.values():
        if im.ldr is not None:
            out |= {(n, sha(d)) for n, d in im.files().items()}
    return frozenset(out)


def identify(images: dict[str, Image], ldr: bytes | None, crc: bytes | None) -> str:
    for im in images.values():
        if im.ldr is not None and ldr == im.ldr:
            crc_note = "" if crc is not None and crc.strip() == im.crc else " (os.crc32 does not match it)"
            return f"{im.label}{crc_note}"
    if ldr is None:
        return "no os.ldr"
    return f"unknown os.ldr ({len(ldr)} bytes, sha256 {sha(ldr)[:16]}…)"


# ---------------------------------------------------------------- the console

class FrameReader:
    """The OP-Z's byte stream -> (routing, type, payload). The device escapes its header as well as the payload."""

    def __init__(self):
        self.frames, self._body, self._esc = [], None, False

    def feed(self, data: bytes) -> None:
        for b in data:
            if b == START:
                self._body, self._esc = bytearray(), False
                continue
            if self._body is None:
                continue
            if self._esc:
                b, self._esc = b ^ ESCAPE_XOR, False
            elif b == ESCAPE:
                self._esc = True
                continue
            self._body.append(b)
            if len(self._body) >= 6 and len(self._body) == 6 + int.from_bytes(self._body[2:6], "big"):
                self.frames.append((self._body[0], self._body[1], bytes(self._body[6:])))
                self._body = None

    def take(self):
        out, self.frames = self.frames, []
        return out


class Console:
    def __init__(self, transport, allowed_files: frozenset, out=print):
        self.port, self.allowed, self.out = transport, allowed_files, out
        self.reader = FrameReader()
        self.stalled = False

    def _write(self, wire: bytes) -> None:
        if self.stalled:
            raise Stalled("an upload did not finish: send nothing until the OP-Z is switched off and on")
        self.port.write(wire)
        self.port.flush()

    def send(self, wire: bytes) -> None:
        if wire not in FIXED:
            raise Refused(f"{wire[:16].hex(' ')}… is not a fixed frame (writes go through write_file)")
        self.out(f"  >> {wire.hex(' ')}")
        self._write(wire)

    def wait(self, want: int, timeout: float, idle: float | None = None) -> bytes | None:
        """The payload of the next frame of type `want`, or None after `timeout` s. With `idle`, once bytes flow the
        limit becomes `idle` s of silence instead (a long read is not cut short)."""
        start = last = time.monotonic()
        while True:
            chunk = self.port.read(self.port.in_waiting or 1)
            now = time.monotonic()
            if chunk:
                last = now
                self.reader.feed(chunk)
            for _, t, p in self.reader.take():
                if t == TYPE_LOG:
                    self.out(f"  << log {p.split(b'\0', 1)[0].decode('utf-8', 'replace')}")
                elif t == want:
                    return p
                else:
                    self.out(f"  << ignored frame type 0x{t:02x}, {len(p)} bytes")
            if idle is None or last == start:
                if now - start > timeout:
                    return None
            elif now - last > idle:
                return None

    def drain(self) -> None:
        self.port.reset_input_buffer()
        self.reader = FrameReader()

    def ping(self, timeout: float = 2.0) -> bool:
        self.send(PING)
        return self.wait(REPLY_PONG, timeout) == b""

    def start(self) -> None:
        """Opening the port eats the first frame, so ping twice and require the second pong."""
        self.ping(1.0)
        self.drain()
        if not self.ping():
            raise Refused("no answer: is the OP-Z connected and in update mode (hold SCREEN while switching on)?")
        self.out("  pong: update mode")

    def read_file(self, name: str) -> bytes | None:
        self.send(READ[name])
        return self.wait(REPLY_READ, timeout=8.0, idle=3.0)

    def write_file(self, name: str, data: bytes, progress=None) -> None:
        if (name, sha(data)) not in self.allowed:
            raise Refused(f"{name}: sha256 {sha(data)} is not a file of any flashable image")
        head = write_header(name, len(data))
        pieces = [data[i:i + PIECE] for i in range(0, len(data), PIECE)] or [b""]
        wires = [escape(p) for p in pieces]
        decoded = decode_write(head + b"".join(wires))
        if decoded != (name, data):
            raise Refused("the write frame does not decode to what was asked")
        self.out(f"  >> write {name}: {head.hex(' ')} + {len(data)} bytes in {len(pieces)} pieces")
        self.drain()
        self._write(head)
        time.sleep(0.3)  # the zero byte mounts and opens; nothing answers it
        for i, w in enumerate(wires):
            last = i == len(wires) - 1
            self._write(w)
            reply = self.wait(REPLY_WRITTEN if last else REPLY_PIECE, timeout=30.0 if last else 10.0)
            if reply is None:
                self.stalled = True
                raise Stalled(f"{name}: no answer after piece {i + 1} of {len(wires)}. The upload is still open on "
                              f"the OP-Z: switch it off, back on holding SCREEN, and flash again")
            if progress:
                progress(name, i + 1, len(wires))
        self.out(f"  << {name} written ({len(data)} bytes)")


# ---------------------------------------------------------------- jobs

def open_serial(port: str | None):
    try:
        import serial
    except ImportError:
        raise Refused("pyserial is missing: run Firmware/flash, or python3 -m pip install pyserial")
    if port is None:
        ports = sorted(glob.glob("/dev/cu.usbmodem*"))
        if len(ports) != 1:
            raise Refused(f"expected exactly one /dev/cu.usbmodem* port (the OP-Z in update mode), found {ports}")
        port = ports[0]
    return serial.Serial(port, 115200, timeout=0.2)


def run_dir() -> Path:
    d = dumps_dir() / f"flash-{datetime.datetime.now(datetime.timezone.utc):%Y%m%dT%H%M%SZ}"
    d.mkdir(parents=True, exist_ok=True)
    return d


def read_installed(con: Console, folder: Path | None) -> tuple[bytes | None, bytes | None]:
    crc = con.read_file("os.crc32")
    ldr = con.read_file("os.ldr")
    if folder:
        for name, data in (("os.crc32", crc), ("os.ldr", ldr)):
            if data is not None:
                (folder / f"installed-{name}").write_bytes(data)
    return ldr, crc


def check(con: Console, images: dict[str, Image], folder: Path | None = None) -> str:
    con.start()
    ldr, crc = read_installed(con, folder)
    found = identify(images, ldr, crc)
    con.out(f"installed: {found}")
    return found


def flash(con: Console, images: dict[str, Image], label: str, folder: Path | None = None, progress=None) -> None:
    im = images.get(label)
    if im is None:
        raise Refused(f"no image {label!r}; known: {', '.join(images)}")
    if im.ldr is None:
        raise Refused(f"{label} is not flashable: {im.reason}")
    con.start()
    con.out("backing up what is installed")
    ldr, crc = read_installed(con, folder)
    found = identify(images, ldr, crc)
    con.out(f"installed: {found}")
    if found.startswith(("unknown", "no os.ldr")) and label != "original":
        raise Refused("the installed OS is not a known image: only `original` may be written over it")
    for name, data in (("os.crc32", im.crc), ("os.ldr", im.ldr)):
        con.write_file(name, data, progress)
        back = con.read_file(name)
        if back != data:
            got = "nothing" if back is None else f"{len(back)} bytes, sha256 {sha(back)[:16]}…"
            raise Refused(f"{name} read back DIFFERENT ({got}). Do not switch on normally: flash `original`")
        con.out(f"  {name} read back identical")
    con.out(f"done: {im.title} is on the OP-Z. Switch it off and on to start it")


# ---------------------------------------------------------------- command line

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("images")
    sub.add_parser("frames")
    c = sub.add_parser("check")
    c.add_argument("--port")
    f = sub.add_parser("flash")
    f.add_argument("label")
    f.add_argument("--port")
    f.add_argument("--yes", action="store_true")
    f.add_argument("--dry-run", action="store_true")
    a = ap.parse_args(argv)
    try:
        if a.cmd == "frames":
            print("Fixed frames (nothing else passes Console.send):")
            print(f"  ping           {PING.hex(' ')}")
            for n in NAMES:
                print(f"  read {n:9s} {READ[n].hex(' ')}")
            print("Writes (Console.write_file, only a flashable image's files):")
            for n in NAMES:
                print(f"  write {n:8s} {write_header(n, 0)[:3].hex(' ')} <len> <size> {n.encode().hex(' ')} 00 <data>")
            print(f"Never: {', '.join(f'0x{t:02x}' for t in sorted(NEVER))}")
            return 0
        images = load_images()
        if a.cmd == "images":
            for im in images.values():
                if im.ldr is None:
                    print(f"{im.label:12s} {im.title}: NOT flashable: {im.reason}")
                else:
                    print(f"{im.label:12s} {im.title}: {len(im.ldr)} bytes, crc32 {im.crc.decode()}, "
                          f"sha256 {sha(im.ldr)}" + (f", patches {', '.join(im.patches)}" if im.patches else ""))
            return 0
        if a.cmd == "flash" and a.dry_run:
            im = images[a.label]
            if im.ldr is None:
                raise Refused(f"{a.label} is not flashable: {im.reason}")
            for name, data in im.files().items():
                print(f"would write {name}: {write_header(name, len(data)).hex(' ')} + {len(data)} bytes, "
                      f"{-(-len(data) // PIECE)} pieces, sha256 {sha(data)}")
            return 0
        folder = run_dir()
        log = open(folder / "log.txt", "w")

        def out(line):
            print(line)
            log.write(line + "\n")
            log.flush()

        con = Console(open_serial(a.port), allowed(images), out)
        try:
            if a.cmd == "check":
                check(con, images, folder)
            else:
                if not a.yes and input(f"Type {a.label} to write it to the OP-Z: ").strip() != a.label:
                    raise Refused("not confirmed")
                flash(con, images, a.label, folder)
        finally:
            con.port.close()
            out(f"log and backups: {folder}")
    except (Refused, Stalled) as e:
        print(f"STOPPED: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
