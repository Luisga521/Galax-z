#!/usr/bin/env python3
"""fake_update_port — an OP-Z in update mode that is not there: fake_console.py behind a pseudo serial port, for trying the hub's whole
way (its own port code included) with no unit.

    fake_update_port.py LABEL STATE_DIR [--pull-at BYTES] [--corrupt-at BYTES]

Has the build LABEL installed (or what STATE_DIR holds). Prints the port's path; writes what is on "it" to STATE_DIR whenever that
changes. --pull-at closes the port after that many bytes were sent to it: the cable pulled.
"""
import os
import pty
import sys
import tty
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import fake_console  # noqa: E402
import flash  # noqa: E402

args = [a for a in sys.argv[1:] if not a.startswith("--")]
opt = lambda n: int(sys.argv[sys.argv.index(n) + 1]) if n in sys.argv else None
label, state = args[0], Path(args[1])
state.mkdir(parents=True, exist_ok=True)
files = {f.name: f.read_bytes() for f in state.glob("os.*")}
if not files:
    files = dict(flash.load_images()[label].files())
con = fake_console.FakeConsole(files, corrupt_at=opt("--corrupt-at"))
master, slave = pty.openpty()
tty.setraw(slave)
print(os.ttyname(slave), flush=True)
pull, got, last = opt("--pull-at"), 0, {}
while True:
    data = os.read(master, 65536)
    got += len(data)
    con.write(data)
    if con.in_waiting:
        out = con.read(con.in_waiting)
        while out:
            out = out[os.write(master, out[:1024]):]
    if con.files != last:
        last = dict(con.files)
        for n, d in last.items():
            (state / n).write_bytes(bytes(d))
    if con.forbidden:
        print("FORBIDDEN", con.forbidden, flush=True)
    if pull is not None and got > pull:
        print("cable pulled", flush=True)
        os.close(master)
        os.close(slave)
        break
