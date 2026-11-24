import DotKit
import OPZModel
import OPZPlay

extension Stage {
    /// A choice: its name small, what it is, a mark each side where a tap goes back or on, three dots where the middle opens them all.
    func chooser(_ c: DotCanvas, _ r: DotRect, _ what: Choice, _ name: String, _ value: String, _ colour: DotColor, on: Bool = false) {
        let held = grips.values.contains { $0.grip == .choose(what) }, marked = (what.scrubs || what == .kit) && r.w >= 34, more = what.long && marked
        c.frame(r, on || held ? colour : Palette.ink, held ? 1 : on ? 0.8 : 0.22, radius: 2)
        c.text(DotFont.tiny.fitted(name, r.w - (more ? 11 : 6)), r.x + 4, r.y + 3, Palette.ink, 0.45, font: .tiny)
        c.text(DotFont.tiny.fitted(value, r.w - (marked ? 12 : 8)), r.x + (marked ? 6 : 4), r.y + 10, colour, on || held ? 1 : 0.85, font: .tiny)
        if marked {
            func mark(_ x: Int, _ tip: Int) { c.set(x, r.y + 11, colour, 0.55); c.set(tip, r.y + 12, colour, 0.55); c.set(x, r.y + 13, colour, 0.55) }
            mark(r.x + 3, r.x + 2)
            mark(r.maxX - 4, r.maxX - 3)
        }
        if more { for k in 0..<3 { c.set(r.maxX - 4, r.y + 3 + k * 2, Palette.ink, 0.5) } }
        // going through them: where it is among them
        if held, what.scrubs, let (names, at) = values(what), names.count > 1 {
            let w = r.w - 8
            c.rule(r.x + 4, r.maxY - 3, w, Palette.ink, 0.3, step: 2)
            c.fill(DotRect(r.x + 4 + (w - 3) * at / (names.count - 1), r.maxY - 3, 3, 1), colour)
        }
        touches.append((r, .grip(.choose(what))))
    }
    private func row(_ c: DotCanvas, _ r: DotRect, _ all: [(Choice, String, String, DotColor, Bool)]) {
        let w = r.w / max(1, all.count)
        for (i, a) in all.enumerated() { chooser(c, DotRect(r.x + i * w, r.y, w - 3, r.h), a.0, a.1, a.2, a.3, on: a.4) }
    }

    // MARK: PLAY: the selected track under your fingers

    func playPage(_ c: DotCanvas, _ r: DotRect, _ dt: Double) {
        let s = player.settings, colour = Palette.track(track), tall = r.h > r.w
        // the tracks
        let per = tall ? 8 : 16, th = 12, tw = r.w / per
        for t in 0..<16 {
            let box = DotRect(r.x + (t % per) * tw, r.y + (t / per) * (th + 2), tw - 2, th), on = t == track
            c.pill(box, Palette.track(t), (on ? 0.6 : 0.12) + 0.4 * hitFlashes[t].level, radius: 2)
            c.text(Palette.shortNames[t], box.midX, box.y + 4, on ? .white : Palette.ink, on ? 1 : 0.6, font: .tiny, align: .center)
            touches.append((box, .track(t)))
        }
        var y = r.y + (16 / per) * (th + 2) + 2
        let drums = track < 4
        let first: [(Choice, String, String, DotColor, Bool)] = drums ? [(.hold, "HOLD", s.hold.name, Palette.yellow, s.hold != .off), (.groove, "GROOVE", s.groove ?? "OFF", Palette.teal, s.groove != nil),
                                                                         (.octave, "OCTAVE", octave > 0 ? "+\(octave)" : "\(octave)", Palette.ink, octave != 0), (.panic, "NOTES", "ALL OFF", Palette.red, false)]
            : [(.key, "KEY", Palette.noteNames[s.tonic], Palette.yellow, false), (.scale, "SCALE", s.scale.name, Palette.yellow, s.scale != .off), (.tool, "CHORD", s.tool.name, Palette.green, s.tool != .off),
               (.hold, "HOLD", s.hold.name, Palette.yellow, s.hold != .off), (.octave, "OCTAVE", octave > 0 ? "+\(octave)" : "\(octave)", Palette.ink, octave != 0), (.panic, "NOTES", "ALL OFF", Palette.red, false)]
        row(c, DotRect(r.x, y, r.w, 19), first)
        y += 21
        if !drums {
            var second: [(Choice, String, String, DotColor, Bool)] = [(.groove, "GROOVE", s.groove ?? "OFF", Palette.teal, s.groove != nil)]
            if s.groove != nil { second.append((.order, "ORDER", s.order.name, Palette.teal, false)) }
            if s.tool == .progression { second += [(.progression, "PROGRESSION", s.progression, Palette.pink, true), (.vary, "VARY", "\(Int(s.vary * 100))", Palette.pink, s.vary > 0)] }
            if s.tool != .off { second.append((.strum, "STRUM", s.strum == 0 ? "OFF" : "\(Int(s.strum * 1000)) MS", Palette.green, s.strum > 0)) }
            row(c, DotRect(r.x, y, r.w, 19), second)
            y += 21
        }
        // the pads
        let body = DotRect(r.x, y + 1, r.w, r.maxY - y - 1), cols = drums ? 6 : tall ? 5 : 8, rows = drums ? 4 : tall ? 6 : 4
        guard body.h > 24 else { return }
        let pw = body.w / cols, ph = body.h / rows, steps = s.scale.steps.count, base = drums ? 53 + octave * 12 : 48 + s.tonic - (s.tonic > 6 ? 12 : 0) + octave * 12
        let sounding = Set(trail.sounding(time).filter { $0.track == track }.map(\.note))
        for i in 0..<cols * rows {
            let note = drums ? base + i : s.scale.note(i, base: base)
            guard (0...127).contains(note) else { continue }
            let box = DotRect(body.x + (i % cols) * pw, body.y + (rows - 1 - i / cols) * ph, pw - 2, ph - 2), lit = player.isLit(i), heard = sounding.contains(note)
            let root = !drums && i % steps == 0 && s.scale != .off || s.scale == .off && !drums && ((note - s.tonic) % 12 + 12) % 12 == 0
            c.pill(box, lit || heard ? .white : colour, lit ? 0.95 : heard ? 0.6 : root ? 0.42 : 0.17, radius: 3)
            let label = drums ? "\(i + 1)" : s.tool == .numbers ? Progressions.keyChords[((note % 12) + 12) % 12].label.replacingFlat : Palette.note(note)
            c.text(label, box.x + 4, box.maxY - 8, lit ? .black : Palette.ink, lit ? 1 : 0.65, font: .tiny)
            touches.append((box, .grip(.key(i, note))))
        }
        // what is played
        if let ch = player.chord, let name = Optional(ch.name(tonic: s.tonic)) {
            c.text(name, body.maxX - 4, body.y + 3, .white, 0.9, font: .big, align: .right)
            if s.tool == .progression { c.text("NEXT " + player.upNext, body.maxX - 4, body.y + 20, Palette.pink, 0.8, font: .tiny, align: .right) }
        }
    }

    // MARK: PERFORM: sixteen moves

    static func family(_ m: Move) -> DotColor { [Palette.red, Palette.track(4), Palette.green, Palette.pink, Palette.yellow, Palette.track(3), Palette.purple][Move.families.firstIndex(of: m.family) ?? 0] }

    func performPage(_ c: DotCanvas, _ r: DotRect, _ dt: Double) {
        let tall = r.h > r.w, m = bay.slots[pad], side = tall ? 0 : max(96, r.w * 34 / 100), foot = tall ? r.h * 2 / 5 : 0
        let pads = DotRect(r.x, r.y, r.w - side, r.h - foot), w = pads.w / 4, h = pads.h / 4
        let active = performer.active
        for p in 0..<16 {
            let box = DotRect(pads.x + p % 4 * w, pads.y + p / 4 * h, w - 3, h - 3), on = active.contains(p)
            guard let mv = bay.slots[p] else {
                c.frame(box, Palette.ink, p == pad ? 0.6 : 0.14, radius: 3)
                c.text("EMPTY", box.midX, box.midY - 2, Palette.ink, 0.3, font: .tiny, align: .center)
                touches.append((box, .grip(.move(p))))
                continue
            }
            let k = Self.family(mv), beatNow = beat - beat.rounded(.down)
            c.pill(box, k, on ? 0.7 + 0.3 * (1 - beatNow) : 0.16, radius: 3)
            if p == pad { c.frame(box, gallery ? Palette.yellow : k, 0.9, radius: 3) }
            c.text(DotFont.tiny.fitted(mv.name, box.w - 6), box.x + 4, box.y + 4, on ? .black : .white, on ? 1 : 0.9, font: .tiny)
            c.text(mv.scope == .track ? Palette.shortNames[track] : mv.scope.name, box.x + 4, box.maxY - 8, on ? .black : k, on ? 0.8 : 0.7, font: .tiny)
            c.rule(box.x + 3, box.maxY - 2, Int(Double(box.w - 6) * mv.amount), on ? .black : k, 0.7)
            touches.append((box, .grip(.move(p))))
        }
        let s = tall ? DotRect(r.x, pads.maxY + 2, r.w, foot - 2) : DotRect(pads.maxX + 5, r.y, side - 5, r.h)
        let third = s.w / 3
        chooser(c, DotRect(s.x, s.y, third - 2, 19), .latch, "PADS", latch ? "LATCH" : "HOLD", Palette.yellow, on: latch)
        chooser(c, DotRect(s.x + third, s.y, third - 2, 19), .lights, "LIGHTS", lights ? "PLAYS" : "OFF", Palette.track(14), on: lights)
        chooser(c, DotRect(s.x + third * 2, s.y, s.w - third * 2, 19), .gallery, "GALLERY", gallery ? "CLOSE" : "OPEN", Palette.teal, on: gallery)
        var y = s.y + 22
        if gallery {
            let f = Move.families[shelf % Move.families.count], all = Move.gallery.filter { $0.family == f }
            chooser(c, DotRect(s.x, y, s.w, 19), .shelf, "SHELF \(shelf + 1)/\(Move.families.count)", f, Self.family(all[0]), on: true)
            y += 21
            let wide = s.w > 150 ? 2 : 1, cw = s.w / wide, ch = max(10, min(15, (s.maxY - y) / ((all.count + wide) / wide)))
            for (i, mv) in (all.map(Optional.init) + [nil]).enumerated() {
                let box = DotRect(s.x + i % wide * cw, y + i / wide * ch, cw - 2, ch - 2)
                guard box.maxY <= s.maxY else { break }
                let loaded = mv != nil && bay.slots.contains { $0?.id == mv?.id }, k = mv.map(Self.family) ?? Palette.red
                c.pill(box, k, loaded ? 0.3 : 0.1, radius: 2)
                c.text(DotFont.tiny.fitted(mv?.name ?? "TAKE IT OFF", box.w - 6), box.x + 3, box.midY - 2, mv == nil ? Palette.red : .white, 0.9, font: .tiny)
                touches.append((box, .grip(.load(mv?.id))))
            }
            return
        }
        guard let m else { c.text("PICK A MOVE IN THE GALLERY", s.midX, y + 10, Palette.ink, 0.5, font: .tiny, align: .center); return }
        let k = Self.family(m)
        c.text("PAD \(pad + 1)", s.x, y, Palette.ink, 0.45, font: .tiny)
        c.text(DotFont.small.fitted(m.name, s.w), s.x, y + 8, k, 1)
        c.text(DotFont.tiny.fitted(m.blurb.uppercased(), s.w), s.x, y + 19, Palette.ink, 0.5, font: .tiny)
        chooser(c, DotRect(s.x, y + 28, s.w, 19), .scope, "TAKES", m.scope == .track ? "TRACK: " + OPZ.trackNames[track].uppercased() : m.scope.name, k)
        let bar = DotRect(s.x, y + 51, s.w, 16)
        c.frame(bar, Palette.ink, 0.25, radius: 2)
        c.fill(DotRect(bar.x + 2, bar.y + 2, Int(Double(bar.w - 4) * m.amount), bar.h - 4), k, 0.7)
        c.text("AMOUNT \(Int(m.amount * 100))", bar.x + 5, bar.midY - 2, .white, 0.95, font: .tiny)
        touches.append((bar, .grip(.amount)))
        if bar.maxY + 14 < s.maxY { c.text(active.isEmpty ? "HOLD A PAD" : "\(active.count) ON", s.x, bar.maxY + 6, active.isEmpty ? Palette.ink : k, active.isEmpty ? 0.35 : 1, font: .tiny) }
    }
}

extension String {
    /// The dot type has no flat sign.
    var replacingFlat: String { map { $0 == "♭" ? "B" : $0 == "°" ? "o" : String($0) }.joined() }
}
