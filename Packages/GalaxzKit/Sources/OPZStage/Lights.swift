import DotKit

/// A DMX rig as the lights track sets it: a truss of moving heads, two strobes, pars washing the back wall, haze, and the universe of
/// channels it all goes out on. With the lights track silent it listens to the song instead, as a desk's sound-to-light does.
struct Rig {
    /// The gels, one a key: the note's name picks the colour.
    static let gels: [DotColor] = [DotColor(0xF4F1E8), DotColor(0xFF3B2F), DotColor(0xFF7A1F), DotColor(0xFFB13B), DotColor(0xFFE14D), DotColor(0x8DFF5A),
                                   DotColor(0x2FE6A8), DotColor(0x35D3FF), DotColor(0x3D6BFF), DotColor(0x8A5CFF), DotColor(0xE04CFF), DotColor(0xFF4F9A)]
    static let programs = ["SWEEP", "FAN", "WAVE", "CROSS"]

    var colour = gels[7], other = gels[10]     // the heads' gel, the wash's
    var dimmer = 0.3, strobe = 0.0, hit = 0.0
    var program = 0
    var phase = 0.0                            // where in its movement
    var zoom = 0.4                             // how wide the beams are
    var own = false                            // the lights track plays it
}

extension Stage {
    /// What the rig is set to now: by the lights track if it plays, else by the song.
    func rigNow(_ values: [Double]? = nil) -> Rig {
        var g = Rig()
        let p1 = values?[0] ?? knobs[14][0].value, p2 = values?[1] ?? knobs[14][1].value
        let tempo = Double(max(40, input.tempo ?? 120))
        g.own = grid.noteCount[14] > 0 || strikes[14].last.map { time - $0 < 6 } == true
        if g.own {
            let note = lastNote[14]
            g.colour = Rig.gels[((note % 12) + 12) % 12]
            // the wash takes the note before, if it was another
            var before = (note + 7) % 12
            for n in trail.notes.reversed().prefix(48) where n.track == 14 && n.note % 12 != note % 12 { before = n.note % 12; break }
            g.other = Rig.gels[(before + 12) % 12]
            let held = trail.notes.reversed().prefix(48).contains { $0.track == 14 && ($0.end ?? .infinity) > time }
            g.dimmer = max(held ? 0.5 + 0.5 * lastVelocity[14] : 0.16, 0.16 + 0.84 * levels[14].level)
            g.strobe = note >= 72 ? hitFlashes[14].level : 0
            g.hit = hitFlashes[14].level
            g.program = max(0, note / 12 - 3) % 4
            g.phase = time * (0.03 + 0.4 * p1) * tempo / 120
            g.zoom = 0.15 + 0.85 * p2
        } else {
            g.colour = keyColour(4..<8)
            g.other = keyColour(4..<8, second: true)
            g.dimmer = 0.45 + 0.55 * max(levels[0].level, levels[4].level * 0.6, pulse.level * 0.5)
            g.strobe = max(0, hitFlashes[1].level - 0.45) / 0.55
            g.hit = hitFlashes[0].level
            g.program = playhead.playing ? Int(beat / 16) % 4 : Int(time / 14) % 4
            g.phase = playhead.playing ? beat / 8 : time * 0.04
            g.zoom = 0.35
        }
        return g
    }

    /// The colour of what the chords or the lead last played: its key round the circle of fifths, so near keys are near colours.
    func keyColour(_ tracks: Range<Int>, second: Bool = false) -> DotColor {
        var latest = -1.0, next = -1.0, a = tracks.lowerBound, b = tracks.lowerBound + 1
        for t in tracks { if let s = strikes[t].last { if s > latest { (next, b) = (latest, a); (latest, a) = (s, t) } else if s > next { (next, b) = (s, t) } } }
        guard latest > 0 else { return DotColor.hue(0.55 + (second ? 0.3 : 0) + time * 0.004, 0.75, 1) }
        func hue(_ n: Int) -> Double { Double(((n * 7) % 12 + 12) % 12) / 12 }
        // the second: what played before, or the first's colour a third of the way round if that is near it
        var h = hue(lastNote[a])
        if second { let o = next > 0 ? hue(lastNote[b]) : h; h = abs(o - h) < 0.15 || abs(o - h) > 0.85 ? h + 0.33 : o }
        return DotColor.hue(h, 0.78, 1)
    }

    /// The rig, in a box. `universe`: the channels it sends, underneath.
    func rig(_ c: DotCanvas, _ r: DotRect, _ g: Rig, universe: Bool = true, crowd: Bool = false) {
        guard r.w > 20, r.h > 16 else { return }
        let w = Double(r.w), uniH = universe && r.h > 54 ? 10 : 0
        let floorY = Double(r.maxY - uniH - (crowd ? 12 : 2)), trussY = Double(r.y) + (crowd ? 12 : 3)
        let n = max(3, min(6, r.w / 34)), t = time
        // haze: what the room holds, lit a little by everything
        field.drift(c, DotRect(r.x, r.y + 6, r.w, Int(floorY) - r.y - 6), g.colour.mixed(.white, 0.3), t, density: r.w * r.h / 160, speed: 0.015, seed: 21, spread: 1.1)
        // the pars on the floor, washing the back wall
        let pars = max(2, n - 2), washH = min(110, (floorY - trussY) * 0.85), widest = w / Double(pars) * 0.55
        for p in 0..<pars {
            let px = Double(r.x) + w * (Double(p) + 0.5) / Double(pars), colour = p % 2 == 0 ? g.other : g.colour
            let a = g.dimmer * (0.55 + 0.45 * g.hit) * 0.6
            for dy in stride(from: 0.0, to: washH, by: 2) {
                let f = dy / washH, half = min(widest, 3 + dy * 0.55)
                for dx in stride(from: -half, through: half, by: 2) { c.add(Int(px + dx), Int(floorY - dy), colour, a * (1 - f) * (1 - abs(dx) / (half + 1))) }
            }
            c.pill(DotRect(Int(px) - 2, Int(floorY) - 1, 5, 2), colour, 0.4 + 0.6 * g.dimmer, radius: 1)
        }
        c.rule(r.x, Int(floorY) + 1, r.w, Palette.ink, 0.22, step: 2)
        // the beams
        for i in 0..<n {
            let f = (Double(i) + 0.5) / Double(n), hx = Double(r.x) + w * f, hy = trussY + 5
            let pan = beamAngle(g, i, n, f), colour = i % 2 == 0 ? g.colour : g.other
            let d = Turn.of(pan), dx = d.x, dy = -d.y, length = (floorY - hy) / max(0.3, dy)
            let a = g.dimmer * (0.5 + 0.5 * g.hit), widen = 0.05 + 0.17 * g.zoom
            let along = max(1.5, length / 110)          // a long beam in fewer, brighter rows
            for s in stride(from: 2.0, to: length, by: along) {
                // across it no more than nine points, each the brighter the further apart
                let half = 0.6 + s * widen, fall = 1 - 0.6 * s / length, x0 = hx + dx * s, y0 = hy + dy * s, step = max(1.3, half / 4)
                let smoke = 0.65 + 0.35 * Turn.sine(s * 0.031 + t * 0.07 + Double(i) * 0.37), each = a * fall * smoke * 0.55 * min(2.2, step / 1.2) * along / 1.5
                // each row's points a little aside of the last's, so a wide beam is a haze, not rays
                for o in stride(from: -half + step * frac(s * 0.618), through: half, by: step) {
                    let e = o / half
                    c.glow(x0 - dy * o, y0 + dx * o, colour, each * (1 - e * e))
                }
                c.glow(x0, y0, colour.mixed(.white, 0.5), a * fall * 0.45)
            }
            // where it lands
            let lx = hx + dx * length, spot = 0.6 + length * widen
            c.arc(lx, floorY, spot, colour.mixed(.white, 0.3), a * 0.8, squash: 0.28)
            c.arc(lx, floorY, spot * 0.55, colour, a * 0.5, squash: 0.28)
            // the head: a yoke, and its lens
            c.rule(Int(hx) - 3, Int(trussY) + 3, 7, Palette.ink, 0.5)
            c.pill(DotRect(Int(hx) - 2, Int(trussY) + 3, 5, 4), Palette.ink, 0.3, radius: 1)
            c.disc(hx + dx * 2, hy + dy * 2, 1.8, colour.mixed(.white, 0.3 + 0.5 * g.hit), 0.6 + 0.4 * g.dimmer)
        }
        // the truss: two chords and the lattice between
        c.rule(r.x, Int(trussY), r.w, Palette.ink, 0.55)
        c.rule(r.x, Int(trussY) + 3, r.w, Palette.ink, 0.4)
        for x in stride(from: r.x, to: r.maxX - 3, by: 4) { c.set(x + 1, Int(trussY) + 1, Palette.ink, 0.3); c.set(x + 3, Int(trussY) + 2, Palette.ink, 0.3) }
        // the strobes, between the heads
        for s in 0..<2 {
            let sx = r.x + Int(w * Double(s == 0 ? 1 : n - 1) / Double(n)) - 3
            c.pill(DotRect(sx, Int(trussY) + 4, 7, 3), g.strobe > 0.05 ? .white : Palette.ink, 0.25 + 0.75 * g.strobe, radius: 1)
        }
        if g.strobe > 0.05 { c.fill(DotRect(r.x, Int(trussY) + 6, r.w, Int(floorY) - Int(trussY) - 5), DotColor(0xE8F0FF), g.strobe * 0.3) }
        if crowd { audience(c, r, floorY, g) }
        if uniH > 0 { dmx(c, DotRect(r.x, r.maxY - uniH + 2, r.w, uniH - 2), g, n) }
    }

    /// How far from straight down head `i` of `n` points, in turns.
    private func beamAngle(_ g: Rig, _ i: Int, _ n: Int, _ f: Double) -> Double {
        let p = g.phase
        switch g.program {
        case 1: return (f - 0.5) * 0.3 * (0.35 + 0.65 * (0.5 + 0.5 * Turn.sine(p)))
        case 2: return 0.09 * Turn.sine(p + f * 0.8)
        case 3: return 0.1 * Turn.sine(p) * (i % 2 == 0 ? 1 : -1) + (f - 0.5) * 0.04
        default: return 0.1 * Turn.sine(p) + (f - 0.5) * 0.05
        }
    }

    /// Heads and hands in front, black against the light coming off the floor.
    private func audience(_ c: DotCanvas, _ r: DotRect, _ floorY: Double, _ g: Rig) {
        let top = Int(floorY) - 14
        for y in top..<r.maxY {
            let f = Double(y - top) / Double(max(1, r.maxY - top)), a = (0.15 + 0.5 * g.dimmer) * max(0, 1 - abs(f - 0.45) * 1.8)
            for x in r.x..<r.maxX { c.add(x, y, g.colour.mixed(g.other, 0.5 + 0.5 * Turn.sine(Double(x) * 0.006 + time * 0.02)), a) }
        }
        var rnd = DotRandom(5)
        let n = r.w / 11, bounce = levels[0].level
        for i in 0..<n {
            let x = Double(r.x) + (Double(i) + rnd.range(0.1, 0.9)) * Double(r.w) / Double(n), jump = bounce * rnd.range(0.5, 3)
            let y = Double(r.maxY) - rnd.range(11, 17) - jump
            c.glow(x - 1.5, y - 3.2, g.colour.mixed(.white, 0.4), 0.5 * g.dimmer)          // a rim of light on each head
            silhouette(c, x, y, 3.6)
            c.pill(DotRect(Int(x) - 6, Int(y) + 4, 13, r.maxY - Int(y) - 4), .black, 1, radius: 4)
            guard rnd.unit() < 0.4 else { continue }
            let side = rnd.unit() < 0.5 ? -1.0 : 1
            for k in 0..<11 {
                let ax = Int(x + side * (4 + Double(k) * 0.3)), ay = Int(y + 4 - Double(k) * 1.2 - jump * 0.4)
                c.set(ax, ay, .black); c.set(ax + 1, ay, .black)
            }
        }
    }

    /// A disc of black over what is there.
    func silhouette(_ c: DotCanvas, _ cx: Double, _ cy: Double, _ r: Double) {
        for y in Int(cy - r - 1)...Int(cy + r + 1) { for x in Int(cx - r - 1)...Int(cx + r + 1) {
            let dx = Double(x) - cx, dy = Double(y) - cy, cover = min(1, max(0, r + 0.5 - (dx * dx + dy * dy).squareRoot()))
            if cover > 0 { c.set(x, y, .black, cover) }
        } }
    }

    /// The universe: each head's dimmer, pan, tilt and colour as the levels its channels send.
    private func dmx(_ c: DotCanvas, _ r: DotRect, _ g: Rig, _ heads: Int) {
        let label = r.w > 150 ? "DMX" : "", lw = label.isEmpty ? 0 : DotFont.tiny.width(label) + 4
        if !label.isEmpty { c.text(label, r.x, r.y + 1, Palette.ink, 0.5, font: .tiny) }
        // what plays it, and how the heads move
        let words = (g.own ? Palette.note(lastNote[14]) : "AUTO") + " · " + Rig.programs[g.program], ww = DotFont.tiny.width(words)
        let pitch = 3, perHead = 6, channels = min(heads * perHead, (r.w - lw - ww - 6) / pitch - heads)
        if channels > 6 { c.text(words, r.maxX, r.y + 1, g.own ? g.colour : Palette.yellow, 0.75, font: .tiny, align: .right) }
        for k in 0..<max(0, channels) {
            let i = k / perHead, f = (Double(i) + 0.5) / Double(heads), colour = i % 2 == 0 ? g.colour : g.other
            let pan = beamAngle(g, i, heads, f)
            let (v, tint): (Double, DotColor) = switch k % perHead {
            case 0: (g.dimmer, .white)
            case 1: (0.5 + pan * 3, Palette.ink)
            case 2: (0.6 + 0.3 * Turn.sine(g.phase * 0.5 + f), Palette.ink)
            case 3: (Double(colour.r) / 255, Palette.red)
            case 4: (Double(colour.g) / 255, Palette.green)
            default: (Double(colour.b) / 255, Palette.blue)
            }
            let x = r.x + lw + k * pitch + (k / perHead), h = max(1, Int((min(1, max(0, v)) * Double(r.h - 1)).rounded()))
            c.column(x, r.y, r.h, Palette.ink, 0.07)
            c.fill(DotRect(x, r.maxY - h, 2, h), tint, 0.35 + 0.5 * min(1, max(0, v)))
        }
    }
}
