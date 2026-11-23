#!/usr/bin/env python3
"""usb_report — read what the OP-Z wrote down about its USB port (Galax-z usbhost/usbhost.c, struct Report), over MIDI.

    $OPFREE/.venv/bin/python Firmware/tools/usb_report.py [seconds]

With the OP-Z plugged into the Mac (and not switched off since the keyboard), start this, then on the OP-Z, in HOST: hold SHIFT,
press MIXER. Each byte comes as two notes (velocity 1-16 = a nibble; note 24-87 counts). Only listens: sends nothing.
"""
import sys
import time

SIZE = 362


def collect(seconds):
    import mido
    names = [n for n in mido.get_input_names() if "OP-Z" in n]
    if len(names) != 1:
        raise SystemExit(f"expected one OP-Z MIDI input, found {names}")
    got, start = [], time.time()
    with mido.open_input(names[0]) as port:
        while time.time() - start < seconds and len(got) < SIZE * 2:
            for m in port.iter_pending():
                if m.type == "note_on" and 1 <= m.velocity <= 16 and 24 <= m.note < 88:
                    if m.note - 24 == len(got) & 63:
                        got.append(m.velocity - 1)
                    elif m.note == 24:
                        got = [m.velocity - 1]          # started again
                    else:
                        print(f"lost one at {len(got)}: note {m.note}")
                        got = []
            time.sleep(0.001)
    return bytes(a << 4 | b for a, b in zip(got[::2], got[1::2]))


def show(r):
    if len(r) != SIZE or r[:4] != b"GZU1":
        return f"not a whole report: {len(r)} bytes, {r[:8].hex(' ')}"
    u16 = lambda o: r[o] | r[o + 1] << 8
    out = [f"checksum {'good' if sum(r[:-1]) & 255 == r[-1] else 'BAD'}"]
    out.append(f"USB-C messages {r[4]}, devices seen {r[5]}, interfaces asked about {r[6]}, taken as older keyboards {r[7]}, "
               f"MIDI interfaces read {r[8]} (result {r[9]}), USB driver then {r[10]} (2 = host, 1 = device)")
    n = r[4]
    for i in range(min(n, 8)):
        k = (n - min(n, 8) + i) & 7
        a = r[16 + k * 4:20 + k * 4]
        out.append(f"  cable: {a.hex(' ')}   connected {a[0]}, role 0x{a[2]:02x} ({ {0x20: 'none', 0x21: 'device', 0x22: 'host'}.get(a[2], '?')})")
    out.append(f"last device: start {'good' if r[48] == 0 else 'FAILED' if r[48] == 255 else r[48]}, speed {r[49]}, last interface class {r[50]:02x}/{r[51]:02x}")
    d = r[52:70]
    out.append(f"  device descriptor {d.hex(' ')}   id {d[8] | d[9] << 8:04x}:{d[10] | d[11] << 8:04x} (as the OP-Z keeps it)")
    out.append(f"  configuration, {u16(70)} bytes: {r[72:72 + min(u16(70), 256)].hex(' ')}")
    out.append(f"packets since {u16(12)}, {u16(14)} bytes; the first events:")
    out += [f"  {r[328 + i * 4:332 + i * 4].hex(' ')}" for i in range(8) if any(r[328 + i * 4:332 + i * 4])]
    return "\n".join(out)


if __name__ == "__main__":
    r = collect(float(sys.argv[1]) if len(sys.argv) > 1 else 120)
    print(show(r))
