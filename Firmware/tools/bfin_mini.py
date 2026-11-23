"""A tiny Blackfin interpreter, only for the instructions our own leaf routines use, so they can be run against fake OP-Z
memory before they meet the unit. It runs binutils' disassembly of the assembled bytes (what will be flashed), and stops
with an error at any instruction, memory or register it does not know. Not a model of the OP-Z: no cycles, no OS."""

import os
import re
import subprocess
import tempfile

BIN = os.path.expanduser("~/opt/bfin-elf/bin")
M32 = 0xFFFFFFFF


def disassemble(code: bytes, base: int) -> dict:
    with tempfile.NamedTemporaryFile(suffix=".bin") as f:
        f.write(code)
        f.flush()
        out = subprocess.run([f"{BIN}/bfin-elf-objdump", "-D", "-b", "binary", "-m", "bfin", f"--adjust-vma=0x{base:x}", f.name],
                             capture_output=True, text=True, check=True).stdout
    ins = {}
    for line in out.splitlines():
        m = re.match(r"\s*([0-9a-f]+):\t([0-9a-f ]+)\t(.*)", line)
        if m:
            text = re.sub(r"/\*.*?\*/", "", m.group(3)).strip().rstrip(";").strip()
            ins[int(m.group(1), 16)] = (text, len(m.group(2).split()))
    return ins


class Machine:
    def __init__(self, code: bytes, base: int, memory: dict):
        self.ins, self.mem, self.reg, self.cc = disassemble(code, base), dict(memory), {}, False
        self.mem.update({base + i: b for i, b in enumerate(code)})
        self.writes, self.steps = set(), 0

    def load(self, a, n):
        missing = [x for x in range(a, a + n) if x not in self.mem]
        if missing:
            raise RuntimeError(f"reads unknown memory 0x{missing[0]:08x}")
        return sum(self.mem[a + i] << 8 * i for i in range(n))

    def get(self, r):
        if r not in self.reg:
            raise RuntimeError(f"reads {r}, never set")
        return self.reg[r]

    def run(self, pc, limit=10_000):
        """Until a JUMP (Pn): the address it goes to."""
        num = lambda s: int(s, 0)
        while True:
            self.steps += 1
            if self.steps > limit:
                raise RuntimeError("does not end")
            text, size = self.ins[pc]
            nxt, R = pc + size, r"([RP]\d)"
            def m(p):
                return re.fullmatch(p, text)
            if x := m(R + r"\.L = (0x[0-9a-f]+)"):
                self.reg[x[1]] = self.reg.get(x[1], 0) & 0xFFFF0000 | num(x[2])
            elif x := m(R + r"\.H = (0x[0-9a-f]+)"):
                self.reg[x[1]] = self.reg.get(x[1], 0) & 0xFFFF | num(x[2]) << 16
            elif x := m(R + r" = (-?0x[0-9a-f]+) \([XZ]\)"):
                self.reg[x[1]] = num(x[2]) & M32
            elif x := m(R + r" = \[" + R + r"(?: \+ (0x[0-9a-f]+))?\]"):
                a = self.get(x[2]) + (num(x[3]) if x[3] else 0)
                if a % 4:
                    raise RuntimeError(f"misaligned load 0x{a:x}")
                self.reg[x[1]] = self.load(a, 4)
            elif x := m(R + r" = B\[" + R + r"(?: \+ (0x[0-9a-f]+))?\] \(Z\)"):
                self.reg[x[1]] = self.load(self.get(x[2]) + (num(x[3]) if x[3] else 0), 1)
            elif x := m(r"B\[" + R + r"(?: \+ (0x[0-9a-f]+))?\] = " + R):
                a = self.get(x[1]) + (num(x[2]) if x[2] else 0)
                self.mem[a] = self.get(x[3]) & 0xFF
                self.writes.add(a)
            elif x := m(R + r" = " + R + r" ([+|]) " + R):
                a, b = self.get(x[2]), self.get(x[4])
                self.reg[x[1]] = (a + b) & M32 if x[3] == "+" else a | b
            elif x := m(R + r" = " + R):
                self.reg[x[1]] = self.get(x[2])
            elif x := m(R + r" \+= (-?0x[0-9a-f]+)"):
                self.reg[x[1]] = (self.get(x[1]) + num(x[2])) & M32
            elif x := m(R + r" \*= " + R):
                self.reg[x[1]] = self.get(x[1]) * self.get(x[2]) & M32
            elif x := m(R + r" >>= (0x[0-9a-f]+)"):
                self.reg[x[1]] = self.get(x[1]) >> num(x[2])
            elif x := m(r"CC = " + R + r" == (?:" + R + r"|(0x[0-9a-f]+))"):
                self.cc = self.get(x[1]) == (self.get(x[2]) if x[2] else num(x[3]))
            elif x := m(r"CC = BITTST \(" + R + r", (0x[0-9a-f]+)\)"):
                self.cc = bool(self.get(x[1]) >> num(x[2]) & 1)
            elif x := m(r"IF (!?)CC JUMP (?:0x)+([0-9a-f]+)(?: \(BP\))?"):
                if self.cc != bool(x[1]):
                    nxt = int(x[2], 16)
            elif x := m(r"JUMP(?:\.S)? (?:0x)+([0-9a-f]+)"):
                nxt = int(x[1], 16)
            elif x := m(r"JUMP \(" + R + r"\)"):
                return self.get(x[1])
            elif text not in ("NOP", "MNOP"):
                raise RuntimeError(f"unknown instruction at 0x{pc:08x}: {text}")
            pc = nxt
