import DotKit
import OPZModel

/// How a sound looks: one way for each kind of engine.
enum VisualKind: Equatable {
    case wave, fm, string, bars, vowel, chip, piano, drum, hats, snap, sample
    case space, echo, grain, swirl, filter, dist, comp, tape, master, punch, module, lights, motion

    init(track: Int, sound: Sound?) {
        let n = (sound?.engine?.dir ?? sound?.name ?? "").lowercased()
        func any(_ words: String...) -> Bool { words.contains { n.contains($0) } }
        switch track {
        case 10: self = .tape
        case 11: self = .master
        case 12: self = .punch
        case 13: self = .module
        case 14: self = .lights
        case 15: self = .motion
        case 8, 9:
            self = any("ott", "glue") ? .comp : any("filter", "resonator") ? .filter : any("dist", "crush", "lofi", "fold") ? .dist
                : any("cloud", "repeat", "harmon") ? .grain : any("swirl", "chorus", "shift") ? .swirl
                : any("echo", "delay", "tape") ? .echo : .space
        default:
            self = any("dx", "fm2", "fmperc", "fm003", "oper") ? .fm : any("pluck", "string") ? .string : any("modal", "mallet", "kalimba") ? .bars
                : any("vowel") ? .vowel : any("chip", "8bit", "digital") ? .chip : any("piano", "electric", "organ", "grand") || n == "ep" ? .piano
                : any("hat", "cymbal") ? .hats : any("snap", "clap") ? .snap
                : sound?.origin == .samples ? (track < 3 ? .drum : .sample) : track < 4 ? .drum : .wave
        }
    }
}

struct VisualInput {
    let values: [Double]
    let colour: DotColor
    let hit, level: Double
    let note: Int
    let velocity: Double
    /// Seconds since each strike, oldest first.
    let strikes: [Double]
    let seed: Int
    var p1: Double { values[0] }
    var p2: Double { values[1] }
}

extension Stage {
    func draw(_ kind: VisualKind, _ c: DotCanvas, _ r: DotRect, _ v: VisualInput, _ dt: Double) {
        guard r.w > 8, r.h > 8 else { return }
        let cx = Double(r.x) + Double(r.w) / 2, cy = Double(r.y) + Double(r.h) / 2
        let w = Double(r.w), h = Double(r.h), t = time, k = v.colour
        let pulse = 0.35 + 0.65 * v.level

        /// A curve across the glass; `f` from -1 (bottom) to 1 (top).
        func curve(_ colour: DotColor, _ amount: Double, _ f: (Double) -> Double) {
            var last: Double?
            for x in 0..<r.w {
                let y = cy - f(Double(x) / w) * h * 0.42
                if let l = last, abs(y - l) > 1 { c.line(Double(r.x + x - 1), l, Double(r.x + x), y, colour, amount) }
                else { c.glow(Double(r.x + x), y, colour, amount) }
                last = y
            }
        }
        func rings(_ reach: Double, life: Double = 0.8, squash: Double = 1, from: Double = 4) {
            for age in v.strikes where age < life {
                let f = Ease.out(age / life)
                c.arc(cx, cy, from + reach * f, k, (1 - age / life) * 0.9, squash: squash)
            }
        }

        switch kind {
        case .wave:     // a wave that bends with P1, folds with P2, its ghosts behind it
            for g in stride(from: 4, through: 0, by: -1) {
                let d = Double(g) * 0.05, a = g == 0 ? 1 : 0.22 - Double(g) * 0.035
                curve(g == 0 ? k : k.mixed(.white, 0.2), a) { x in
                    let phase = x * 2.2 + t * 0.22 - d
                    let saw = 2 * (phase - phase.rounded(.down)) - 1, sine = Turn.sine(phase), square = sine > 0 ? 1.0 : -1
                    let m = v.p1 < 0.5 ? sine + (saw - sine) * v.p1 * 2 : saw + (square - saw) * (v.p1 - 0.5) * 2
                    let fold = Turn.sine(m * (0.25 + v.p2 * 0.9))
                    return fold * (0.3 + 0.7 * pulse) * (1 - 0.5 * abs(2 * x - 1))
                }
            }
        case .fm:       // operators going round, the modulator's wake
            let R = min(w, h) * 0.3, ratio = 1 + (v.p1 * 6).rounded(.down), depth = 0.2 + v.p2
            c.arc(cx, cy, R * (0.55 + 0.25 * v.level), k, 0.9)
            c.arc(cx, cy, R * (0.55 + 0.25 * v.level) - 1.2, k, 0.4)
            rings(R * 1.6, from: R * 0.6)
            for i in 0..<Int(90 + 120 * depth) {
                let f = Double(i) / Double(Int(90 + 120 * depth)), a = t * 0.09 + f
                let mod = Turn.sine(a * ratio + t * 0.05) * depth
                let p = Turn.of(a), rr = R * (1.1 + 0.5 * mod) + 3
                c.glow(cx + p.x * rr * 1.35, cy + p.y * rr * 0.86, k.mixed(.white, 0.5 + 0.5 * mod), 0.15 + 0.85 * pulse * (1 - f * 0.5))
            }
            for o in 0..<3 {
                let p = Turn.of(t * (0.11 + 0.05 * Double(o)) * (o == 1 ? -1 : 1) + Double(o) / 3), rr = R * (1.35 + 0.12 * Double(o))
                c.disc(cx + p.x * rr * 1.35, cy + p.y * rr * 0.86, 2.6 + 2.5 * v.hit, o == 0 ? .white : k, 0.9)
            }
        case .string:   // strings, plucked where P1 says
            let n = 6
            for i in 0..<n {
                let y = Double(r.y) + h * (Double(i) + 0.8) / (Double(n) + 0.6)
                let mine = ((v.note % n) + n) % n == i
                let age = mine ? v.strikes.last ?? 9 : 9, amp = mine ? h * 0.07 * max(0, 1 - age / 1.6) * (0.4 + v.velocity) : 0
                let at = 0.1 + 0.8 * v.p1
                for x in 0..<r.w {
                    let f = Double(x) / w, shape = f < at ? f / at : (1 - f) / (1 - at)
                    let ring = amp * shape * Turn.sine(age * 14) + amp * 0.5 * Turn.sine(f * 2 + age * 9) * (1 - shape)
                    c.glow(Double(r.x + x), y + ring, mine ? k : Palette.ink, mine ? 0.5 + 0.5 * max(0, 1 - age) : 0.22)
                }
                if mine, age < 0.5 { c.disc(Double(r.x) + at * w, y, 2 + 4 * age, .white, 1 - age * 2) }
            }
        case .bars:     // struck bars: each its own length, ringing
            let n = 9
            for i in 0..<n {
                let mine = ((v.note - 48) % n + n) % n == i, age = mine ? v.strikes.last ?? 9 : 9
                let bh = h * (0.86 - 0.055 * Double(i)), bw = w / Double(n) * 0.56, bx = Double(r.x) + w * (Double(i) + 0.5) / Double(n)
                let shake = mine ? Turn.sine(age * 18) * 2.2 * max(0, 1 - age / 1.2) : 0
                let box = DotRect(Int(bx - bw / 2 + shake), Int(cy - bh / 2), Int(bw), Int(bh))
                c.pill(box, mine ? k : Palette.ink, mine ? 0.25 + 0.75 * max(0, 1 - age / (0.4 + v.p2 * 2)) : 0.1 + 0.03 * Double(i % 2), radius: 3)
                c.set(box.midX, box.y + 4, .black); c.set(box.midX, box.maxY - 5, .black)
                if mine { for a in v.strikes where a < 0.6 { c.arc(bx, cy, 3 + a * h * 0.8, k, (1 - a / 0.6) * 0.6) } }
            }
        case .vowel:    // a mouth, and the formants it makes
            let open = 0.12 + 0.75 * v.level * (0.4 + 0.6 * v.p1), wide = 0.5 + 0.4 * v.p2
            for ring in 0..<4 {
                let f = 1 - Double(ring) * 0.16
                c.arc(cx, cy, w * 0.17 * wide * f + 4, ring == 0 ? .white : k, 1 - Double(ring) * 0.2, squash: max(0.08, open * 1.2))
            }
            for i in 0..<5 {
                let fx = Double(r.x) + w * (0.1 + 0.2 * Double(i)), peak = h * (0.1 + 0.3 * abs(Turn.sine(v.p1 * 0.8 + Double(i) * 0.31))) * pulse
                for y in 0..<Int(peak) { c.add(Int(fx), r.maxY - 2 - y, k, 0.8 - 0.6 * Double(y) / peak); c.add(Int(fx) + 1, r.maxY - 2 - y, k, 0.5) }
            }
        case .chip:     // big square pixels marching
            let cell = 8, cols = r.w / cell, rows = r.h / cell, duty = [0.125, 0.25, 0.5, 0.75][min(3, Int(v.p1 * 4))]
            for x in 0..<cols {
                let phase = (Double(x) / 9 + t * 0.9).truncatingRemainder(dividingBy: 1), high = phase < duty
                let y = high ? rows / 4 : rows * 3 / 4
                c.pill(DotRect(r.x + x * cell, r.y + y * cell, cell - 1, cell - 1), k, pulse, radius: 1)
                let next = (Double(x + 1) / 9 + t * 0.9).truncatingRemainder(dividingBy: 1) < duty
                if next != high { for j in rows / 4...max(rows / 4, rows * 3 / 4) { c.pill(DotRect(r.x + x * cell, r.y + j * cell, cell - 1, cell - 1), k, pulse * 0.6, radius: 1) } }
            }
            var rnd = DotRandom(UInt64(v.strikes.count + 7))
            for a in v.strikes where a < 0.5 { for _ in 0..<10 {
                let dx = rnd.range(-1, 1), dy = rnd.range(-1, 1)
                c.pill(DotRect(Int(cx + dx * a * w), Int(cy + dy * a * h), 4, 4), .white, 1 - a * 2, radius: 1)
            } }
        case .piano:    // hammers on strings: each note lifts its own, light running up
            let n = max(12, r.w / 9), low = 36
            for i in 0..<n {
                let x = r.x + 4 + i * (r.w - 8) / n
                let bend = Double(i) / Double(n)
                let top = r.y + 3 + Int(h * 0.42 * (1 - (1 - bend) * (1 - bend)))
                c.column(x, top, r.maxY - top - 12, Palette.ink, 0.16, step: 2)
            }
            for n2 in trail.notes where n2.track == v.seed && time - n2.start < 3 {
                let age = time - n2.start, i = min(n - 1, max(0, (n2.note - low) * n / 61)), x = r.x + 4 + i * (r.w - 8) / n
                let bend = Double(i) / Double(n), top = r.y + 3 + Int(h * 0.42 * (1 - (1 - bend) * (1 - bend)))
                let fade = max(0, 1 - age / 3) * (n2.end.map { $0 < time ? 0.35 : 1 } ?? 1)
                for y in stride(from: r.maxY - 14, to: top, by: -1) {
                    let f = Double(r.maxY - 14 - y) / Double(max(1, r.maxY - 14 - top))
                    let wob = Turn.sine(f * 2 + age * 11) * 1.8 * fade * n2.velocity
                    c.glow(Double(x) + wob, Double(y), f < age * 5 ? k : Palette.ink, f < age * 5 ? fade * (1 - 0.5 * f) : 0)
                }
                let lift = max(0, 1 - age * 7)
                c.pill(DotRect(x - 2, r.maxY - 10 - Int(lift * 5), 5, 7), .white, 0.4 + 0.6 * fade, radius: 1)
            }
            c.rule(r.x + 2, r.maxY - 3, r.w - 4, k, 0.4 + 0.6 * v.hit)
        case .drum:     // a head from above, a skin that moves
            let R = min(w * 0.46, h * 0.95) * 0.5
            let bend = (v.strikes.last.map { max(0, 1 - $0 * 4) } ?? 0)
            c.arc(cx, cy, R + 2, Palette.ink, 0.5, squash: 0.92)
            for ring in 1...6 {
                let f = Double(ring) / 6, wob = Turn.sine((v.strikes.last ?? 9) * 6 - f * 0.9) * bend * 5
                c.arc(cx, cy, max(1, R * f + wob), ring == 6 ? .white : k, 0.18 + 0.75 * bend * (1 - f * 0.6) + (ring == 6 ? 0.4 : 0.06), squash: 0.92)
            }
            rings(R * 1.4, life: 0.5, squash: 0.92, from: R)
            c.disc(cx, cy, 3 + 9 * bend * (0.4 + v.velocity), k, 0.5 + 0.5 * bend)
        case .hats:     // two plates, and what flies off
            let gap = 2 + 14 * (v.strikes.last.map { max(0, 1 - $0 * 3) } ?? 0) * (0.3 + 0.7 * v.p2)
            for (side, y) in [(-1.0, cy - gap), (1.0, cy + gap)] {
                for x in -r.w * 2 / 5...r.w * 2 / 5 {
                    let f = Double(x) / (w * 0.4)
                    c.glow(cx + Double(x), y + side * (1 - f * f) * h * 0.1 * -1 + side * 3, k, 0.9)
                }
            }
            var rnd = DotRandom(UInt64(v.seed + 3))
            for (i, a) in v.strikes.enumerated() where a < 0.7 { for _ in 0..<40 {
                let p = Turn.of(rnd.unit() + Double(i)), s = rnd.range(0.2, 1) * a * w * 0.9
                c.glow(cx + p.x * (20 + s), cy + p.y * (4 + s * 0.6), .white, (1 - a / 0.7) * rnd.unit())
            } }
        case .snap:     // hands: bursts
            var rnd = DotRandom(UInt64(v.seed + 11))
            for (i, a) in v.strikes.enumerated() where a < 0.6 {
                for b in 0..<3 {
                    let late = a - Double(b) * 0.03
                    guard late > 0 else { continue }
                    for _ in 0..<22 {
                        let p = Turn.of(rnd.unit() * 0.9 + Double(i) * 0.3), s = (8 + late * w * 0.7) * rnd.range(0.5, 1)
                        c.line(cx + p.x * s * 0.8, cy + p.y * s * 0.8, cx + p.x * s, cy + p.y * s, b == 0 ? .white : k, (1 - a / 0.6) * 0.5)
                    }
                }
            }
            for i in 0..<24 { let p = Turn.of(Double(i) / 24 + t * 0.01); c.glow(cx + p.x * 12, cy + p.y * 12, k, 0.4 + 0.6 * v.hit) }
        case .sample:   // a recording, its head going by at each strike
            var rnd = DotRandom(UInt64(v.seed * 31 + Int(v.p1 * 40)))
            let age = v.strikes.last ?? 9, head = min(1, age / 0.9)
            for x in stride(from: 0, to: r.w, by: 2) {
                let f = Double(x) / w, env = (f < 0.06 ? f / 0.06 : 1) * (1 - f) * (1 - f) + 0.1 * Turn.sine(f * 9) * (1 - f)
                let a = max(1, abs(env) * (0.4 + 0.6 * rnd.unit()) * h * 0.46), on = f < head && age < 1.1
                for y in stride(from: -Int(a), through: Int(a), by: 1) { c.add(r.x + x, Int(cy) + y, on ? k : Palette.ink, on ? 0.9 : 0.2) }
            }
            if age < 0.9 { c.column(r.x + Int(head * w), r.y, r.h, .white, 0.9) }
        case .space:    // a room: light going out and coming back from its walls
            let size = 0.4 + 0.6 * v.p1
            for d in 0..<6 {
                let f = Double(d) / 6 + (t * 0.06).truncatingRemainder(dividingBy: 1.0 / 6), bw = w * 0.5 * f * size * 1.8, bh = h * 0.5 * f * size * 1.8
                let a = 0.5 * (1 - f) * (0.4 + 0.6 * v.p2) + 0.1
                c.line(cx - bw, cy - bh, cx + bw, cy - bh, k, a); c.line(cx - bw, cy + bh, cx + bw, cy + bh, k, a)
                c.line(cx - bw, cy - bh, cx - bw, cy + bh, k, a); c.line(cx + bw, cy - bh, cx + bw, cy + bh, k, a)
            }
            field.drift(c, r, k, t, density: 60 + Int(160 * v.p2), speed: 0.02 + 0.05 * v.p1, seed: v.seed)
        case .echo:     // the same thing again, smaller, further
            let n = 3 + Int(v.p2 * 7)
            for i in (0..<n).reversed() {
                let f = Double(i) / Double(n), x = Double(r.x) + w * (0.1 + 0.8 * f), hh = h * 0.4 * (1 - f) * (1 - f) + 3
                let flick = max(0, Turn.sine(t * (0.6 + 1.2 * (1 - v.p1)) - f * 1.2))
                for y in stride(from: -hh, through: hh, by: 1) { c.glow(x, cy + y, k, (0.15 + 0.85 * flick) * (1 - f * 0.7)) }
                c.disc(x, cy - hh, 1.8, .white, flick * (1 - f))
                c.disc(x, cy + hh, 1.8, .white, flick * (1 - f))
            }
        case .grain:    // a cloud of pieces
            field.drift(c, r, k, t, density: 120 + Int(260 * v.p2), speed: 0.05 + 0.4 * v.p1, seed: v.seed + 9, spread: 0.35 + 0.6 * v.p1)
        case .swirl:    // arms turning
            for arm in 0..<4 { for i in 0..<90 {
                let f = Double(i) / 90, p = Turn.of(t * (0.04 + 0.2 * v.p1) + Double(arm) / 4 + f * (0.4 + 0.9 * v.p2))
                c.glow(cx + p.x * f * w * 0.48, cy + p.y * f * h * 0.48, arm % 2 == 0 ? k : k.mixed(.white, 0.5), 0.9 * (1 - f))
            } }
        case .filter:   // the curve of it, sweeping
            let cut = 0.08 + 0.84 * v.p1, q = v.p2
            curve(k, 1) { x in
                let d = (x - cut) * 9
                return 0.35 + q * 0.6 * max(0, 1 - d * d * 1.6) - (d > 0 ? min(1.3, d * d * 0.35) : 0)
            }
            for x in stride(from: 0, to: r.w, by: 3) {
                let f = Double(x) / w, pass = f < cut ? 1 : max(0, 1 - (f - cut) * 6)
                let n = 0.5 + 0.5 * Turn.sine(f * 13 + t * 0.7) * Turn.sine(f * 5 - t * 0.31)
                let hh = Int(n * pass * h * 0.4)
                c.column(r.x + x, r.maxY - hh, hh, Palette.ink, 0.3)
            }
        case .dist:     // a wave meeting its ceiling
            let drive = 1 + 7 * v.p1
            c.rule(r.x, Int(cy - h * 0.34), r.w, Palette.red, 0.5, step: 3)
            c.rule(r.x, Int(cy + h * 0.34), r.w, Palette.red, 0.5, step: 3)
            curve(k, 1) { x in
                let y = Turn.sine(x * 3 + t * 0.3) * drive * 0.4, steps = 2 + (1 - v.p2) * 60
                return (max(-0.8, min(0.8, y)) * steps).rounded() / steps
            }
        case .comp:     // three bands, squeezed from both sides
            for b in 0..<3 {
                let bx = Double(r.x) + w * (0.16 + 0.34 * Double(b)), bw = Int(w * 0.17), x0 = Int(bx) - bw / 2
                let raw = 0.5 + 0.45 * Turn.sine(t * (0.5 + 0.23 * Double(b)) + Double(b) * 0.4) * Turn.sine(t * 0.17 + Double(b))
                let squeezed = raw + (0.55 - raw) * v.p1, rows = r.h / 4
                for i in 0..<rows {
                    let f = Double(i) / Double(rows), y = r.maxY - 3 - i * 4
                    let on = f < squeezed, was = f < raw
                    c.fill(DotRect(x0, y, bw, 2), on ? k : Palette.ink, on ? 0.9 : was ? 0.3 : 0.07)
                }
                let top = r.maxY - 3 - Int(0.72 * Double(rows)) * 4, bottom = r.maxY - 3 - Int(0.38 * Double(rows)) * 4
                c.rule(x0 - 4, top + Int((1 - v.p1) * -8), bw + 8, Palette.red, 0.9, step: 2)
                c.rule(x0 - 4, bottom + Int((1 - v.p1) * 8), bw + 8, Palette.green, 0.9, step: 2)
            }
        case .tape:     // two reels
            let speed = playhead.playing ? 0.35 : 0.02
            for (i, x) in [cx - w * 0.2, cx + w * 0.2].enumerated() {
                let R = min(w * 0.16, h * 0.4)
                c.arc(x, cy, R, k, 0.9); c.arc(x, cy, R - 1.5, k, 0.4)
                for s in 0..<3 {
                    let p = Turn.of(t * speed + Double(s) / 3 + Double(i) * 0.1)
                    c.line(x + p.x * 4, cy + p.y * 4, x + p.x * (R - 4), cy + p.y * (R - 4), Palette.ink, 0.8)
                }
                for g in 0..<5 { c.arc(x, cy, R * (0.45 + 0.1 * Double(g)), k, 0.12, dash: 2) }
                c.disc(x, cy, 3, .white, 0.9)
            }
            c.line(cx - w * 0.2 - min(w * 0.16, h * 0.4), cy + 2, cx - 8, cy + h * 0.46, k, 0.5)
            c.line(cx + w * 0.2 + min(w * 0.16, h * 0.4), cy + 2, cx + 8, cy + h * 0.46, k, 0.5)
        case .master:   // everything at once
            let bars = min(32, r.w / 6)
            for i in 0..<bars {
                let tr = i * 12 / bars, a = levels[tr].level
                let jitter = 0.75 + 0.25 * Turn.sine(t * 2.3 + Double(i) * 0.37), rows = r.h / 4, n = Int(a * jitter * Double(rows))
                for j in 0..<rows { c.fill(DotRect(r.x + i * r.w / bars, r.maxY - 3 - j * 4, r.w / bars - 2, 2), Palette.track(tr), j < n ? 1 : 0.06) }
            }
        case .punch:    // pads
            for i in 0..<16 {
                let bx = r.x + (i % 8) * r.w / 8, by = r.y + (i / 8) * r.h / 2, on = hitFlashes[i % 12].level
                c.pill(DotRect(bx + 2, by + 2, r.w / 8 - 4, r.h / 2 - 4), k, 0.1 + 0.9 * on, radius: 3)
            }
        case .module:   // a patch bay
            for i in 0..<6 {
                let x0 = Double(r.x) + w * (0.1 + 0.16 * Double(i)), x1 = Double(r.x) + w * (0.1 + 0.16 * Double((i * 5 + 2) % 6))
                let sag = h * 0.25 + 4 * Turn.sine(t * 0.15 + Double(i) * 0.2)
                for s in 0...60 {
                    let f = Double(s) / 60
                    c.glow(x0 + (x1 - x0) * f, Double(r.y) + h * 0.22 + h * 0.5 * f + sag * 4 * f * (1 - f) * 0.5, Palette.track(i), 0.8)
                }
                c.arc(x0, Double(r.y) + h * 0.22, 4, Palette.ink, 0.9); c.arc(x1, Double(r.y) + h * 0.72, 4, Palette.ink, 0.9)
            }
        case .lights:   // a DMX rig: the note's name its gel, its octave how the heads move, P1 how fast, P2 how wide
            rig(c, r, rigNow(v.values))
        case .motion:   // a reel: each note the next picture, the note's name its lens, P1 the camera, P2 the tint
            reelOn()
            reel(c, r, p1: v.p1, p2: v.p2, caption: true)
        }
    }
}

/// Specks in a box, the same ones every frame.
struct Field {
    func drift(_ c: DotCanvas, _ r: DotRect, _ k: DotColor, _ t: Double, density: Int, speed: Double, seed: Int, spread: Double = 1) {
        var rnd = DotRandom(UInt64(seed + 77))
        for _ in 0..<density {
            let x = rnd.unit(), y = rnd.unit(), s = rnd.range(0.3, 1), phase = rnd.unit()
            let life = (t * speed * s + phase), f = life - life.rounded(.down)
            let wob = Turn.sine(phase + t * 0.07 * s) * 0.05
            let px = 0.5 + (x - 0.5) * spread + wob, py = 0.5 + (y - 0.5) * spread + (f - 0.5) * 0.35
            c.glow(Double(r.x) + px * Double(r.w), Double(r.y) + py * Double(r.h), k.mixed(.white, rnd.unit() * 0.6), Turn.sine(f * 0.5) * s * 0.9)
        }
    }
}
