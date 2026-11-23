import DotKit
import OPZModel

/// FX: the two effects and what is sent to them, and the tumbler and EUCLID.
extension Stage {
    func fxPage(_ c: DotCanvas, _ r: DotRect, _ dt: Double) {
        for t in 0..<10 where t != track { for k in 0..<18 { knobs[t][k].step(dt) } }
        let portrait = r.h > r.w
        let sendsH = max(34, min(56, r.h / 4))
        if portrait {
            let effects = min(76, r.h / 4), machine = DotRect(r.x, r.y, r.w, r.h - effects - sendsH - 10)
            machines(c, machine, dt)
            for k in 0..<2 { effect(c, DotRect(r.x + k * (r.w / 2 + 2), machine.maxY + 5, r.w / 2 - 2, effects), k, dt) }
        } else {
            let top = r.h - sendsH - 6, w = r.w / 2 - 4
            machines(c, DotRect(r.x, r.y, w, top), dt)
            let x = r.x + w + 8, h = (top - 6) / 2
            for k in 0..<2 { effect(c, DotRect(x, r.y + k * (h + 6), r.maxX - x, h), k, dt) }
        }
        sends(c, DotRect(r.x, r.maxY - sendsH, r.w, sendsH))
    }

    // MARK: an effect

    /// What goes into an effect now: how loud, and when.
    func sent(to k: Int) -> (level: Double, strikes: [Double]) {
        var level = 0.0, all: [Double] = []
        for t in 0..<8 {
            let send = knobs[t][6 + k].value
            level = max(level, levels[t].level * min(1, send * 1.4))
            if send > 0.08 { all += strikes[t] }
        }
        return (level, Array(all.sorted().suffix(8)))
    }

    private func effect(_ c: DotCanvas, _ r: DotRect, _ k: Int, _ dt: Double) {
        let t = 8 + k, colour = Palette.track(t), sound = input.sounds[t], s = sent(to: k)
        let name = sound?.name ?? "EMPTY"
        let tag = "FX\(k + 1)", tw = DotFont.small.width(tag)
        c.text(tag, r.x, r.y, colour, 0.6 + 0.4 * s.level)
        c.text(DotFont.small.fitted(name, r.w - tw - 6), r.x + tw + 6, r.y, Palette.ink, sound == nil ? 0.35 : 0.95)
        let inner = DotRect(r.x, r.y + 10, r.w, r.h - 10)
        let dialsW = min(inner.w * 46 / 100, 84), glass = DotRect(inner.x, inner.y, inner.w - dialsW - 4, inner.h)
        c.frame(glass, Palette.ink, 0.16, radius: 2)
        if s.level > 0.02 { c.frame(glass, colour, s.level * 0.8, radius: 2) }
        c.clipped(glass.inset(2, 2)) {
            draw(VisualKind(track: t, sound: sound), c, glass.inset(3, 3),
                 VisualInput(values: (0..<18).map { knobs[t][$0].value }, colour: colour, hit: s.level, level: s.level, note: 60, velocity: s.level,
                             strikes: s.strikes.map { time - $0 }, seed: t), dt)
        }
        if grid.muted[t] { chip(c, "MUTE", glass.x + 4, glass.y + 4, Palette.red) }
        let d = DotRect(inner.maxX - dialsW, inner.y, dialsW, inner.h), page = Palette.pages(t)[0]
        let one = d.h < 44                                              // room for one row of two
        for i in 0..<(one ? 2 : 4) {
            dial(c, DotRect(d.x + (i & 1) * d.w / 2, d.y + (i >> 1) * d.h / 2, d.w / 2, one ? d.h : d.h / 2), t, page, i, sound)
        }
        touches.append((r, .track(t)))
    }

    /// How much of each track goes to the two.
    private func sends(_ c: DotCanvas, _ r: DotRect) {
        c.rule(r.x, r.y - 3, r.w, Palette.ink, 0.2, step: 3)
        let label = r.w > 260 ? 34 : 0, w = (r.w - label) / 8, h = r.h - 9
        if label > 0 {
            c.text("SENDS", r.x, r.y, Palette.ink, 0.5, font: .tiny)
            for k in 0..<2 { c.text("FX\(k + 1)", r.x, r.y + 10 + k * 8, Palette.track(8 + k), 0.9, font: .tiny) }
        }
        for t in 0..<8 {
            let x = r.x + label + t * w, dim = grid.muted[t] ? 0.3 : 1.0, bar = max(3, min(9, w / 4))
            for k in 0..<2 {
                let bx = x + w / 2 - bar - 1 + k * (bar + 2), v = min(1, max(0, knobs[t][6 + k].value)), lit = Int((v * Double(h)).rounded()), colour = Palette.track(8 + k)
                for y in stride(from: 0, to: h, by: 2) {
                    let on = h - y <= lit
                    c.fill(DotRect(bx, r.y + y, bar, 1), on ? colour : Palette.ink, on ? dim * (0.45 + 0.55 * levels[t].level) : 0.07)
                }
                if v > 0.02 { c.fill(DotRect(bx, r.y + h - lit, bar, 1), .white, dim) }
            }
            let name = OPZ.trackNames[t].uppercased()
            c.text(DotFont.tiny.width(name) < w - 2 ? name : Palette.shortNames[t], x + w / 2, r.maxY - 6, t == track ? .white : Palette.track(t), t == track ? 1 : dim * 0.8, font: .tiny, align: .center)
            touches.append((DotRect(x, r.y, w, r.h), .track(t)))
        }
    }

    // MARK: the machines

    enum Machine { case tumbler, euclid }

    /// The one whose page the OP-Z shows, for this track.
    var machinePage: Machine? {
        guard let m = input.machines, m.track == track, track < 8 else { return nil }
        return m.page == Machines.tumblerPage ? .tumbler : m.page == Machines.euclidPage ? .euclid : nil
    }

    private func machines(_ c: DotCanvas, _ r: DotRect, _ dt: Double) {
        c.frame(r, Palette.ink, 0.16, radius: 2)
        guard let m = input.machines else {
            hexagon(c, DotRect(r.x, r.y, r.w, r.h - 18), time * 0.02, Palette.pink, 0.22)
            for (i, s) in ["THE TUMBLER AND EUCLID", "SHOW FROM GALAX-Z V10"].enumerated() {
                c.text(s, r.midX, r.maxY - 18 + i * 8, i == 0 ? Palette.ink : Palette.yellow, i == 0 ? 0.6 : 0.8, font: .tiny, align: .center)
            }
            return
        }
        guard m.track < 8 else {
            hexagon(c, DotRect(r.x, r.y, r.w, r.h - 18), 0, Palette.ink, 0.12)
            c.text("SELECT ONE OF TRACKS 1-8", r.midX, r.maxY - 14, Palette.ink, 0.5, font: .tiny, align: .center)
            return
        }
        // which: the page that is on, else what runs, else the tumbler
        let tumbles = m.tumbling >> m.track & 1 == 1, latched = m.latched >> m.track & 1 == 1
        let both = tumbles && latched && m.page < Machines.tumblerPage
        let show: [Machine] = m.page == Machines.tumblerPage ? [.tumbler] : m.page == Machines.euclidPage ? [.euclid] : both ? [.tumbler, .euclid] : latched && !tumbles ? [.euclid] : [.tumbler]
        c.text("\(m.track + 1) " + OPZ.trackNames[m.track].uppercased(), r.x + 5, r.y + 5, Palette.track(m.track), 0.95, font: .tiny)
        let title = show.map { $0 == .tumbler ? "TUMBLER" : "EUCLID" }.joined(separator: " + ")
        c.text(title, r.maxX - 5, r.y + 5, show[0] == .tumbler ? Palette.pink : Palette.teal, 0.95, font: .tiny, align: .right)
        // every track's, small
        let dots = r.maxY - 8, gap = min(14, (r.w - 10) / 8)
        for t in 0..<8 {
            let x = Double(r.midX - gap * 4 + t * gap + gap / 2)
            c.disc(x - 2, Double(dots), 1.6, m.tumbling >> t & 1 == 1 ? Palette.pink : Palette.ink, m.tumbling >> t & 1 == 1 ? 1 : 0.12)
            c.disc(x + 2, Double(dots), 1.6, m.latched >> t & 1 == 1 ? Palette.teal : Palette.ink, m.latched >> t & 1 == 1 ? 1 : 0.12)
        }
        let box = DotRect(r.x + 4, r.y + 13, r.w - 8, r.h - 27)
        if show.count == 2 {
            let wide = box.w > box.h
            machine(.tumbler, c, wide ? DotRect(box.x, box.y, box.w / 2, box.h) : DotRect(box.x, box.y, box.w, box.h / 2), m)
            machine(.euclid, c, wide ? DotRect(box.x + box.w / 2, box.y, box.w / 2, box.h) : DotRect(box.x, box.y + box.h / 2, box.w, box.h / 2), m)
            return
        }
        // its dials, if there is room for them
        if box.w * 2 > box.h * 3, box.h > 70 {
            let w = box.w / 2
            machine(show[0], c, DotRect(box.x, box.y, box.w - w, box.h), m)
            for i in 0..<4 { machineDial(c, DotRect(box.maxX - w + (i & 1) * w / 2, box.y + (i >> 1) * box.h / 2, w / 2, box.h / 2), show[0], i, m) }
            return
        }
        let room = box.h > 96 ? 40 : 0
        machine(show[0], c, DotRect(box.x, box.y, box.w, box.h - room), m)
        if room > 0 { for i in 0..<4 { machineDial(c, DotRect(box.x + i * box.w / 4, box.maxY - room + 2, box.w / 4, room - 2), show[0], i, m) } }
    }

    func machine(_ what: Machine, _ c: DotCanvas, _ r: DotRect, _ m: Machines) {
        switch what {
        case .tumbler: tumbler(c, r, m)
        case .euclid: euclid(c, r, m)
        }
    }

    func machineDial(_ c: DotCanvas, _ r: DotRect, _ what: Machine, _ i: Int, _ m: Machines) {
        let k = what == .tumbler ? i : (m.more ? 8 : 4) + i
        gauge(c, r, machineDials[k].value, m.reading(k), Machines.dialNames[k], what == .tumbler ? Palette.pink : Palette.teal)
    }

    private func hexagon(_ c: DotCanvas, _ r: DotRect, _ turn: Double, _ colour: DotColor, _ amount: Double) {
        let R = Double(min(r.w, r.h)) / 2 - 3, cx = Double(r.x) + Double(r.w) / 2, cy = Double(r.y) + Double(r.h) / 2
        guard R > 6 else { return }
        for k in 0..<6 {
            let a = turn + Double(k) / 6, b = a + 1.0 / 6
            c.line(cx + Turn.sine(a + 0.25) * R, cy + Turn.sine(a) * R, cx + Turn.sine(b + 0.25) * R, cy + Turn.sine(b) * R, colour, amount)
        }
    }

    private func tumbler(_ c: DotCanvas, _ r: DotRect, _ m: Machines) {
        let R = Double(min(r.w, r.h)) / 2 - 3, scale = R / Tombola.wall
        let cx = Double(r.x) + Double(r.w) / 2, cy = Double(r.y) + Double(r.h) / 2
        guard R > 10 else { return }
        let flash = tombola.balls.map(\.flash).max() ?? 0
        hexagon(c, r, tombola.turn, Palette.pink, tombola.balls.isEmpty ? 0.3 : 0.6 + 0.4 * flash)
        if R > 30 { hexagon(c, r.inset(2, 2), tombola.turn, Palette.pink, 0.18 + 0.3 * flash) }
        for (i, b) in drawnBalls.enumerated() {
            let x = cx + b.x * scale, y = cy + b.y * scale, size = max(1.8, Tombola.radius * scale)
            // where it was
            for p in ballTrail where p.count > i {
                let q = p[i]
                c.glow(cx + q.x * scale, cy + q.y * scale, Palette.pink, 0.10)
            }
            let colour = Palette.pink.mixed(.white, 0.25 + 0.75 * b.flash)
            c.disc(x, y, size + 1.5 * b.flash, colour, 1)
            if b.flash > 0.05 { c.arc(x, y, size + 2 + (1 - b.flash) * 7, Palette.pink, b.flash * 0.8) }
            if R > 34, b.flash > 0.6 { c.text(Palette.note(b.note), Int(x + size) + 2, Int(y - size) - 3, .white, b.flash, font: .tiny) }
        }
        if tombola.balls.isEmpty { c.text(R > 44 ? "PLAY A KEY ON THE PINK PAGE" : "EMPTY", Int(cx), Int(cy) - 2, Palette.ink, 0.4, font: .tiny, align: .center) }
    }

    private func euclid(_ c: DotCanvas, _ r: DotRect, _ m: Machines) {
        let R = Double(min(r.w, r.h)) / 2 - 5, cx = Double(r.x) + Double(r.w) / 2, cy = Double(r.y) + Double(r.h) / 2
        guard R > 10 else { return }
        let drums = m.track < 4, on = !m.rings.isEmpty
        let rings = drums ? m.rings : [m.ring]
        let gap = rings.count > 1 ? min(11, (R - 6) / Double(rings.count)) : 0
        for (k, g) in rings.enumerated() {
            let rr = R - Double(k) * gap, picked = !drums || k == m.pick, now = on && !m.waiting ? m.steps % g.steps : -1
            for i in 0..<g.steps {
                let p = Turn.of(Double(i) / Double(g.steps)), pulse = Machines.isPulse(i, g.steps, g.pulses, g.rotation), here = i == now
                let size = (pulse ? 2.4 : 1.1) * (rings.count > 4 ? 0.7 : 1) + (here ? 1.2 : 0)
                c.disc(cx + p.x * rr, cy + p.y * rr, size, here ? .white : pulse ? Palette.teal : Palette.ink, here ? 1 : pulse ? (on ? 0.95 : 0.45) * (picked ? 1 : 0.55) : 0.22)
            }
            if rings.count == 1, R > 22 {                               // the shape of it
                let pulses = (0..<g.steps).filter { Machines.isPulse($0, g.steps, g.pulses, g.rotation) }
                for (n, i) in pulses.enumerated() where pulses.count > 1 {
                    let a = Turn.of(Double(i) / Double(g.steps)), b = Turn.of(Double(pulses[(n + 1) % pulses.count]) / Double(g.steps)), q = rr - 5
                    c.line(cx + a.x * q, cy + a.y * q, cx + b.x * q, cy + b.y * q, Palette.teal, on ? 0.35 : 0.15)
                }
            }
        }
        let inside = R - Double(rings.count) * gap
        if !on {
            c.text(R > 40 ? "LATCH KEYS" : "EMPTY", Int(cx), Int(cy) - 2, Palette.ink, 0.45, font: .tiny, align: .center)
        } else if drums {
            if inside > 12, m.rings.indices.contains(m.pick) {
                let g = m.rings[m.pick]
                c.text("\(g.pulses)/\(g.steps)", Int(cx), Int(cy) - 3, .white, 0.95, font: inside > 20 ? .small : .tiny, align: .center)
            }
        } else if R > 30 {
            let names = m.rings.map { Palette.note($0.key) }
            let rows = names.count > 4 ? 2 : 1, per = (names.count + rows - 1) / rows
            for row in 0..<rows {
                let part = names[(row * per)..<min(names.count, (row + 1) * per)].joined(separator: " ")
                c.text(DotFont.tiny.fitted(part, Int(R * 1.5)), Int(cx), Int(cy) - rows * 4 + row * 8 + 1, .white, 0.9, font: .tiny, align: .center)
            }
        }
    }
}
