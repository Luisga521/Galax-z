#!/usr/bin/env python3
"""load_report — read the OP-Z's load meter (Galax-z meter/meter.c, struct Report), over MIDI.

    $OPFREE/.venv/bin/python Firmware/tools/load_report.py [seconds]

With the OP-Z plugged into the Mac, in HOST, the meter on (SHIFT + TEMPO) and something played: start this, then hold SHIFT and press
SCREEN. Only listens: sends nothing. usb_report.py has how it comes.
"""
import struct
import sys

import usb_report

SIZE, LINE, BLOCK = 40, 265_000, 580_499


def show(r):
    if len(r) != SIZE or r[:4] != b"GZL1":
        return f"not a whole report: {len(r)} bytes, {r[:8].hex(' ')}"
    tenths, stage, stage_top, total, total_top, kills, voices, gap = struct.unpack_from("<8I", r, 4)
    pc = lambda v, of: f"{v:,} cycles, {100 * v / of:.0f} %"
    return "\n".join([
        f"checksum {'good' if sum(r[:-1]) & 255 == r[-1] else 'BAD'}; measured for {tenths / 10:.1f} s",
        f"instruments, of the OS's limit:     average {pc(stage, LINE)}; highest block {pc(stage_top, LINE)}",
        f"all audio work, of the whole block: average {pc(total, BLOCK)}; highest block {pc(total_top, BLOCK)}",
        f"notes cut off: {kills}; most notes at once: {voices}; longest wait for a UI frame: {gap} ms"])


if __name__ == "__main__":
    usb_report.SIZE = SIZE
    print(show(usb_report.collect(float(sys.argv[1]) if len(sys.argv) > 1 else 120)))
