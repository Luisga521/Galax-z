"""An in-memory OP-Z update-mode console for flash.py's tests, modelled byte for byte on what the bootloader's parser
(0x11a025b0) and command handler (0x11a02932) do (notes/update-write.md):

- every C0 restarts the parser; 7D escapes the next byte (XOR 0x20) everywhere, payload included;
- header: routing, type, length u32 BE; 0x00 runs on the header (pong), 0x19 collects a name to its zero byte;
- 0x11: size u32 BE, then a name to its zero byte, which opens /yaffs2/<name> with "w+b" (empties it); the byte
  counter starts at 4 + name + 1 and every data byte counts until it equals the header's length; every 2,048 data
  bytes are written and answered with an empty 0x12; the last byte writes the rest, closes, and answers 0x13 "01 00";
- any other type is recorded in `forbidden` (the real one would act on it).

Like the real port, the first frame after the port opens is lost.
"""

START, ESCAPE = 0xC0, 0x7D


def reply(mtype: int, payload: bytes = b"") -> bytes:
    body = bytes((0x1E, mtype)) + len(payload).to_bytes(4, "big") + payload
    out = bytearray((START,))
    for b in body:
        out += bytes((ESCAPE, b ^ 0x20)) if b in (START, ESCAPE) else bytes((b,))
    return bytes(out)


class FakeConsole:
    def __init__(self, files=None, ack=True, corrupt_at=None, drop_reply_after=None):
        self.files = dict(files or {})
        self.ack, self.corrupt_at, self.drop_reply_after = ack, corrupt_at, drop_reply_after
        self.out = bytearray()
        self.types, self.forbidden = [], []
        self.eat_first = True
        self._esc = False
        self._reset()
        self.upload = None  # [name, buffer, counter, length, pieces answered]

    # pyserial-like transport
    @property
    def in_waiting(self):
        return len(self.out)

    def read(self, n):
        data, self.out = bytes(self.out[:n]), self.out[n:]
        return data

    def flush(self):
        pass

    def reset_input_buffer(self):
        self.out.clear()

    def close(self):
        pass

    def write(self, data):
        for b in data:
            if b == START:
                self._reset()
                self._esc = False
                continue
            if self._esc:
                b, self._esc = b ^ 0x20, False
            elif b == ESCAPE:
                self._esc = True
                continue
            self._byte(b)

    # the bootloader
    def _reset(self):
        self.state, self.hdr, self.name = "routing", bytearray(), bytearray()
        self.upload = None if not hasattr(self, "upload") else self.upload

    def _byte(self, b):
        if self.state == "data":
            return self._data(b)
        if self.state == "routing":
            self.hdr, self.state = bytearray((b,)), "header"
            return
        if self.state == "header":
            self.hdr.append(b)
            if len(self.hdr) == 6:
                self.mtype, self.length = self.hdr[1], int.from_bytes(self.hdr[2:6], "big")
                self.types.append(self.mtype)
                if self.mtype == 0x00:
                    self.state = "idle"
                    self._send(reply(0x01))
                elif self.mtype == 0x19:
                    self.state = "name"
                elif self.mtype == 0x11:
                    self.state, self.size = "size", bytearray()
                else:
                    self.forbidden.append(self.mtype)
                    self.state = "idle"
            return
        if self.state == "size":
            self.size.append(b)
            if len(self.size) == 4:
                self.state = "name"
            return
        if self.state == "name":
            if b:
                self.name.append(b)
                return
            name = self.name.decode()
            if self.mtype == 0x19:
                self.state = "idle"
                if name in self.files:
                    self._send(reply(0x20, self.files[name]))
            else:
                self.files[name] = b""                       # "w+b"
                self.upload = [name, bytearray(), 4 + len(name) + 1, self.length, 0]
                self.state = "data"
                if self.upload[2] == self.length:
                    self._finish()
            return

    def _data(self, b):
        up = self.upload
        if self.corrupt_at is not None and up[2] - (4 + len(up[0]) + 1) == self.corrupt_at:
            b ^= 0xFF
        up[1].append(b)
        up[2] += 1
        if up[2] == up[3]:
            return self._finish()
        if len(up[1]) == 2048:
            self.files[up[0]] += bytes(up[1])
            up[1].clear()
            up[4] += 1
            if self.ack and (self.drop_reply_after is None or up[4] <= self.drop_reply_after):
                self._send(reply(0x12))

    def _finish(self):
        up = self.upload
        self.files[up[0]] += bytes(up[1])
        self.upload, self.state = None, "idle"
        if self.ack:
            self._send(reply(0x13, b"\x01\x00"))

    def _send(self, data):
        if self.eat_first:
            self.eat_first = False
            return
        self.out += data
