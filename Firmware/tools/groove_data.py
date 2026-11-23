#!/usr/bin/env python3
"""groove_data — pages/groove_data.h (the red page's grooves and progressions) from the app's own tables, which are TO-2's:
Packages/GalaxzKit/Sources/OPZPlay/Groove.swift and Chords.swift.   groove_data.py [--check]"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
PLAY = os.path.join(ROOT, "Packages/GalaxzKit/Sources/OPZPlay")
OUT = os.path.join(os.path.dirname(HERE), "pages", "groove_data.h")
QUALITY = ["major", "minor", "dim", "dom7", "maj7", "min7", "sus4", "add9", "min9", "maj9", "dom9", "sus2", "aug"]
STEPS = {"major": [0, 4, 7], "minor": [0, 3, 7], "dim": [0, 3, 6], "dom7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "min7": [0, 3, 7, 10], "sus4": [0, 5, 7],
         "add9": [0, 4, 7, 14], "min9": [0, 3, 7, 10, 14], "maj9": [0, 4, 7, 11, 14], "dom9": [0, 4, 7, 10, 14], "sus2": [0, 2, 7], "aug": [0, 4, 8]}


def grooves():
    with open(os.path.join(PLAY, "Groove.swift")) as f:
        s = f.read()
    return re.findall(r'Pattern\(name: "([^"]+)", family: \d+, steps: "([Xxo.]{16})"\)', s)


def progressions():
    with open(os.path.join(PLAY, "Chords.swift")) as f:
        s = f.read()
    out = []
    for m in re.finditer(r'(?:Progression\(name: |\bp\()"([^"]+)"', s):
        # to its chords: the bracket after its line
        at = s.index("[", m.end())
        depth, k = 0, at
        while True:
            depth += {"[": 1, "]": -1}.get(s[k], 0)
            k += 1
            if depth == 0:
                break
        chords = []
        for c in re.finditer(r"\bc\((\d)(?:, \.(\w+))?(?:, flat: (true))?\)", s[at:k]):
            chords.append((int(c[1]), c[2] or "major", bool(c[3])))
        if chords:
            out.append((m[1], chords))
    return out


def text():
    g, p = grooves(), progressions()
    out = ["/* made by tools/groove_data.py from OPZPlay (TO-2's tables): do not edit */", f"#define GROOVES {len(g)}",
           "static const struct { unsigned short hit, accent, ghost; } groove[GROOVES] = {"]
    for name, steps in g:
        bits = [sum(1 << i for i, c in enumerate(steps) if c in which) for which in ("Xxo", "X", "o")]
        out.append("    { 0x%04x, 0x%04x, 0x%04x },    /* %s */" % (*bits, name))
    out += ["};", f"#define PROGS {len(p)}", "/* a chord: bit 7 a half step down, bits 3-6 its kind, bits 0-2 its degree 1-7 */"]
    flat, at = [], [0]
    for name, chords in p:
        flat += [(f << 7) | QUALITY.index(q) << 3 | d for d, q, f in chords]
        at.append(len(flat))
    out.append("static const unsigned char prog[%d] = {" % len(flat))
    for (name, chords), a, b in zip(p, at, at[1:]):
        out.append("    " + ", ".join("0x%02x" % x for x in flat[a:b]) + f",    /* {name} */")
    out += ["};", "static const unsigned short prog_at[PROGS + 1] = { " + ", ".join(map(str, at)) + " };",
            "static const unsigned char chord_notes[%d][5] = {     /* 255: no more */" % len(QUALITY)]
    for q in QUALITY:
        out.append("    { " + ", ".join(map(str, (STEPS[q] + [255] * 5)[:5])) + " }," + f"    /* {q} */")
    return "\n".join(out + ["};"]) + "\n"


if __name__ == "__main__":
    t = text()
    if "--check" in sys.argv:
        sys.exit(0 if open(OUT).read() == t else "groove_data.h is not what OPZPlay has")
    open(OUT, "w").write(t)
    print(OUT, len(grooves()), "grooves", len(progressions()), "progressions")
