#!/usr/bin/env python3
"""asm — assemble our own Blackfin code for a patch record's block, with binutils (~/opt/bfin-elf).

    asm.py PATCH.json            assemble every block's `source` at its `target`; show whether `data` matches
    asm.py PATCH.json --update   ... and write the assembled bytes and their sha256 into the record

Records keep the assembled bytes, so building and flashing need no binutils; this keeps them honest. Paths in
`source` are relative to Firmware/.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile

BIN = os.path.expanduser("~/opt/bfin-elf/bin")
FIRMWARE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def assemble(source: str, target: int) -> bytes:
    with tempfile.TemporaryDirectory() as d:
        obj, elf, out = (os.path.join(d, n) for n in ("a.o", "a.elf", "a.bin"))
        for cmd in ([f"{BIN}/bfin-elf-as", "-I", os.path.dirname(source), "-o", obj, source],
                    [f"{BIN}/bfin-elf-ld", f"-Ttext=0x{target:x}", "-e", "0", "-o", elf, obj],
                    [f"{BIN}/bfin-elf-objcopy", "-O", "binary", "-j", ".text", elf, out]):
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode:
                raise SystemExit(f"{cmd[0]} failed:\n{r.stderr}")
        with open(out, "rb") as f:
            data = f.read()
    return data + b"\0" * (-len(data) % 4)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("record")
    ap.add_argument("--update", action="store_true")
    a = ap.parse_args(argv)
    rec = json.load(open(a.record))
    same = True
    for blk in rec.get("blocks", []):
        data = assemble(os.path.join(FIRMWARE, blk["source"]), int(blk["target"], 16))
        digest = hashlib.sha256(data).hexdigest()
        ok = blk.get("data") == data.hex()
        same &= ok
        print(f"{blk['source']} at {blk['target']}: {len(data)} bytes, sha256 {digest} "
              f"({'matches the record' if ok else 'DIFFERS from the record'})")
        if a.update:
            blk["data"], blk["sha256"] = data.hex(), digest
    if a.update:
        with open(a.record, "w") as f:
            json.dump(rec, f, indent=2)
            f.write("\n")
        print(f"updated {a.record}")
    return 0 if same or a.update else 1


if __name__ == "__main__":
    sys.exit(main())
