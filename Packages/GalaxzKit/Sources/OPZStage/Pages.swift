import DotKit
import OPZModel
import OPZPlay

extension Stage {
    // MARK: TRACK: the selected track, its sound alive, its four dials, its steps

    func trackPage(_ c: DotCanvas, _ r: DotRect, _ dt: Double) {
        let t = track, colour = Palette.track(t), sound = input.sounds[t], hit = hitFlashes[t].level
        let portrait = r.h > r.w
        // who
        let number = pad(t + 1)
        c.text(number, r.x, r.y, colour, 0.5 + 0.5 * hit, font: .big)
        let nx = r.x + DotFont.big.width(number) + 6
        c.text(OPZ.trackNames[t].uppercased(), nx, r.y, Palette.ink, 0.95)
        let detail = t < 12 ? (sound.map { origin($0) } ?? "") + (input.slots[t].map { " · KEY \($0)" } ?? "") : ""
        c.text(detail, nx, r.y + 9, Palette.ink, 0.45, font: .tiny)
        if let why = deaf(t) { c.text(DotFont.tiny.fitted(why, r.w), r.x, r.y + 15, Palette.yellow, 0.9, font: .tiny) }
        if grid.muted[t] { chip(c, grid.audioMuted[t] ? "AUDIO MUTE" : "MUTE", nx + 8 + DotFont.small.width(OPZ.trackNames[t].uppercased()), r.y - 1, Palette.red) }
        let name = t < 12 ? sound?.name ?? (t < 10 ? "EMPTY" : OPZ.trackNames[t].uppercased()) : OPZ.trackNames[t].uppercased()
        let nameFont: DotFont = DotFont.big.width(name) < r.w / 2 ? .big : .small
        c.text(nameFont.fitted(name, r.w / 2), r.maxX, r.y + (nameFont.height == 14 ? 0 : 4), colour, 1, font: nameFont, align: .right)

        let stepsH = portrait ? 62 : max(44, min(58, r.h / 4)), dialsH = portrait ? 42 : 0
        let top = r.y + 20
        let steps = DotRect(r.x, r.maxY - stepsH, r.w, stepsH)
        let dialsW = portrait ? r.w : max(96, r.w * 30 / 100)
        let dials = portrait ? DotRect(r.x, steps.y - dialsH - 4, r.w, dialsH) : DotRect(r.maxX - dialsW, top, dialsW, steps.y - top - 4)
        let glass = portrait ? DotRect(r.x, top, r.w, dials.y - top - 4) : DotRect(r.x, top, r.w - dialsW - 8, steps.y - top - 4)

        // its sound, alive
        c.frame(glass, Palette.ink, 0.16, radius: 2)
        c.clipped(glass.inset(2, 2)) {
            if let what = machinePage, let m = input.machines { machine(what, c, glass.inset(4, 4), m); return }
            if let red = redPage { groovePicture(c, glass.inset(4, 4), red); return }
            let kind = VisualKind(track: t, sound: sound)
            let values = (0..<18).map { knobs[t][$0].value }
            let sends = t == 8 || t == 9 ? sent(to: t - 8) : nil          // an effect moves with what is sent to it
            draw(kind, c, glass.inset(3, 3), VisualInput(values: values, colour: colour, hit: max(hit, sends?.level ?? 0), level: max(levels[t].level, sends?.level ?? 0),
                                                         note: lastNote[t], velocity: lastVelocity[t],
                                                         strikes: (sends?.strikes ?? strikes[t]).map { time - $0 }, seed: t), dt)
        }
        if hit > 0.02 { c.frame(glass, colour, hit * 0.9, radius: 2) }
        if levels[t].level > 0.05, t < 8 {
            c.text(Palette.note(lastNote[t]), glass.x + 5, glass.maxY - 10, colour, min(1, levels[t].level * 1.6))
        }

        dialRow(c, dials, t, portrait)
        stepRow(c, steps, t)
    }

    /// The red page, if it is the one that is on for this track.
    var redPage: RedPage? {
        guard let r = input.red, r.track == track, input.machines?.page == RedPage.page, input.machines?.track == track else { return nil }
        return r
    }
    func reading(_ r: RedPage, _ k: Int) -> String { r.reading(k, grooves: Groove.library.map(\.name), progressions: Progressions.all.map(\.name)) }

    /// The groove as sixteen bars, its accents tall, the step that plays white; the chords it goes through.
    private func groovePicture(_ c: DotCanvas, _ r: DotRect, _ red: RedPage) {
        let i = red.which(0, of: Groove.library.count), g = Groove.masks(Groove.library[min(i, Groove.library.count - 1)].steps), w = max(2, r.w / 16)
        for s in 0..<16 {
            let bit = UInt16(1) << UInt16(s), h = g.accent & bit != 0 ? 1.0 : g.ghost & bit != 0 ? 0.3 : g.hit & bit != 0 ? 0.65 : 0.06, tall = Int(Double(r.h - 26) * h), here = red.step == s
            c.pill(DotRect(r.x + s * w, r.maxY - 12 - tall, w - 2, max(2, tall)), here ? .white : Palette.lime, here ? 1 : red.notes.isEmpty ? 0.35 : 0.8, radius: 1)
        }
        c.text(Groove.library[min(i, Groove.library.count - 1)].name, r.x + 2, r.y + 1, Palette.lime, 1)
        let p = red.track < 4 ? 0 : red.which(4, of: Progressions.all.count + 1)
        let line = p > 0 ? Progressions.all[p - 1].chords.prefix(8).map { $0.name(tonic: red.which(5, of: 12)) }.joined(separator: " ")
            : red.notes.isEmpty ? "PLAY A KEY ON THE GREEN PAGE" : red.notes.map(Palette.note).joined(separator: " ")
        c.text(DotFont.tiny.fitted(line, r.w - 4), r.midX, r.maxY - 8, Palette.ink, 0.8, font: .tiny, align: .center)
    }

    /// Why a track's notes do not come, if they do not.
    func deaf(_ t: Int) -> String? {
        guard let m = input.midi else { return nil }
        if !m.outgoing { return "MIDI OUT IS OFF: TEMPO + SCREEN, KEY 3" }
        if !m.enabled[t] { return "THIS TRACK'S MIDI IS OFF: TEMPO + SCREEN, TRACK \(t + 1)" }
        return nil
    }

    func origin(_ s: Sound) -> String {
        switch s.origin {
        case .community: "OP-FREE ENGINE"
        case .teenageEngineering: "TE SOUND"
        case .samples: "SAMPLE PACK"
        case .unknown: "SOUND"
        }
    }

    func chip(_ c: DotCanvas, _ s: String, _ x: Int, _ y: Int, _ colour: DotColor) {
        let w = DotFont.tiny.width(s) + 6
        c.frame(DotRect(x, y, w, 9), colour, 0.9, radius: 2)
        c.text(s, x + 3, y + 2, colour, font: .tiny)
    }

    /// The page's four dials, and the other pages small.
    private func dialRow(_ c: DotCanvas, _ r: DotRect, _ t: Int, _ wide: Bool) {
        let sound = input.sounds[t], pages = Palette.pages(t, samples: sound?.origin == .samples)
        if let what = machinePage, let m = input.machines {                // the pink page or the teal one
            c.text(what == .tumbler ? "TUMBLER" : m.more ? "EUCLID MORE" : "EUCLID", r.x + 2, r.y, what == .tumbler ? Palette.pink : Palette.teal, 0.9, font: .tiny)
            if !wide { pageDots(c, r, t, pages, on: what == .tumbler ? 4 : 5) }
            for i in 0..<4 {
                machineDial(c, wide ? DotRect(r.x + r.w * i / 4, r.y, r.w / 4, r.h)
                            : DotRect(r.x + (i & 1) * r.w / 2, r.y + 8 + (i >> 1) * (r.h - 8) / 2, r.w / 2, (r.h - 8) / 2), what, i, m)
            }
            return
        }
        if let red = redPage {
            c.text(red.more ? "GROOVE MORE" : "GROOVE", r.x + 2, r.y, Palette.lime, 0.9, font: .tiny)
            if !wide { pageDots(c, r, t, pages, on: 6) }
            for i in 0..<4 {
                let k = (red.more ? 4 : 0) + i, box = wide ? DotRect(r.x + r.w * i / 4, r.y, r.w / 4, r.h) : DotRect(r.x + (i & 1) * r.w / 2, r.y + 8 + (i >> 1) * (r.h - 8) / 2, r.w / 2, (r.h - 8) / 2)
                gauge(c, box, Double(red.dials[k]) / 255, "", RedPage.dialNames[k], Palette.lime)
                c.text(DotFont.tiny.fitted(reading(red, k), box.w), box.midX, box.midY - 8, Palette.ink, 0.95, font: .tiny, align: .center)
            }
            return
        }
        let on = min((input.machines.flatMap { $0.track == t ? $0.page : nil } ?? input.panel.page) & 3, pages.count - 1), page = pages[on]
        if wide {
            for i in 0..<4 { dial(c, DotRect(r.x + r.w * i / 4, r.y, r.w / 4, r.h), t, page, i, sound) }
            return
        }
        c.text(page.name, r.x + 2, r.y, page.colour, 0.9, font: .tiny)
        pageDots(c, r, t, pages, on: on)
        let inner = DotRect(r.x, r.y + 8, r.w, r.h - 8)
        // two by two, then the rest of the sound as meters if there is room
        let meters = inner.h > 110
        let dh = meters ? (inner.h - 40) / 2 : inner.h / 2
        for i in 0..<4 { dial(c, DotRect(inner.x + (i & 1) * inner.w / 2, inner.y + (i >> 1) * dh, inner.w / 2, dh), t, page, i, sound) }
        guard meters else { return }
        let y = inner.maxY - 34, n = pages.count * 4, pitch = max(5, inner.w / max(16, n))
        for k in 0..<n {
            let p = pages[k / 4], x = inner.x + k * pitch, v = min(1, max(0, knobs[t][p.params[k % 4]].value))
            c.column(x + 1, y, 28, p.colour, 0.14, step: 2)
            let h = Int((v * 28).rounded())
            c.fill(DotRect(x, y + 28 - h, 3, h), p.colour, k / 4 == on ? 0.95 : 0.4)
        }
    }

    /// A dot a page at the top right, the one on bigger: TE's pages, then on tracks 1-8 Galax-z OS's TUMBLER, EUCLID and GROOVE when the
    /// OP-Z tells of them.
    private func pageDots(_ c: DotCanvas, _ r: DotRect, _ t: Int, _ pages: [Palette.ParamPage], on: Int) {
        var colours = pages.map(\.colour)
        if t < 8, input.machines != nil || input.red != nil { colours += [Palette.pink, Palette.teal, Palette.lime] }
        for (k, colour) in colours.enumerated() {
            c.disc(Double(r.maxX - 4 - (colours.count - 1 - k) * 7), Double(r.y) + 2, k == on ? 2 : 1.1, colour, k == on ? 1 : 0.4)
        }
    }

    func dial(_ c: DotCanvas, _ r: DotRect, _ t: Int, _ page: Palette.ParamPage, _ i: Int, _ sound: Sound?) {
        let index = page.params[i], v = min(1, max(0, knobs[t][index].value))
        let label = page.labels[i] ?? (index == 0 ? (sound?.p1 ?? "P1").uppercased() : index == 1 ? (sound?.p2 ?? "P2").uppercased() : Palette.paramNames[index])
        touches.append((r, .grip(.sound(t, index, across: false))))
        gauge(c, r, v, index == 10 ? pan(v) : "\(Int((v * 255).rounded()))", label, page.colour)
    }

    func gauge(_ c: DotCanvas, _ r: DotRect, _ value: Double, _ text: String, _ label: String, _ colour: DotColor) {
        let v = min(1, max(0, value))
        let radius = Double(max(7, min(r.w / 2 - 5, (r.h - 18) / 2, 24)))
        let cx = Double(r.x) + Double(r.w) / 2, cy = Double(r.y) + radius + 3
        let ticks = Int(radius * 4.2)
        for i in 0...ticks {
            let f = Double(i) / Double(ticks), p = Turn.of(-0.375 + 0.75 * f), lit = f <= v + 0.001
            c.glow(cx + p.x * radius, cy + p.y * radius, lit ? colour : Palette.ink, lit ? 1 : 0.13)
            if lit, radius > 11 { c.glow(cx + p.x * (radius - 1.4), cy + p.y * (radius - 1.4), colour, 0.55) }
        }
        let p = Turn.of(-0.375 + 0.75 * v)
        c.disc(cx + p.x * radius, cy + p.y * radius, radius > 12 ? 2.4 : 1.6, .white, 1)
        let big = radius > 17
        if radius < 10 {                            // too small to hold it: beside it, if there is room
            if r.w / 2 > Int(radius) + 4 + DotFont.tiny.width("255") { c.text(text, Int(cx + radius) + 4, Int(cy) - 2, Palette.ink, 0.95, font: .tiny) }
        } else { c.text(text, Int(cx), Int(cy) - (big ? 3 : 2), Palette.ink, 0.95, font: big ? .small : .tiny, align: .center) }
        c.text(DotFont.tiny.fitted(label, r.w), Int(cx), Int(cy + radius) + 4, colour, 0.75, font: .tiny, align: .center)
    }

    private func pan(_ v: Double) -> String {
        let n = Int(((v - 0.5) * 200).rounded())
        return abs(n) < 2 ? "MID" : n < 0 ? "L\(-n)" : "R\(n)"
    }

    /// One track's sixteen steps as a small piano roll, with where it is.
    private func stepRow(_ c: DotCanvas, _ r: DotRect, _ t: Int) {
        let colour = Palette.track(t), notes = grid.notes[t], head = playhead(t)
        let lo = (notes.map(\.note.note).min() ?? 60) - 1, hi = max((notes.map(\.note.note).max() ?? 64) + 1, lo + 6)
        let gap = 4, w = (r.w - gap * 3) / 16, left = r.x + (r.w - w * 16 - gap * 3) / 2
        let rows = r.h - 14
        func x(_ s: Int) -> Int { left + s * w + (s / 4) * gap }
        for s in 0..<16 {
            let box = DotRect(x(s), r.y, w - 2, rows), used = s < grid.lengths[t], cell = grid[t, s]
            c.pill(box, Palette.ink, used ? (head == s ? 0.2 : 0.06) : 0.02, radius: 2)
            if head == s { c.fill(DotRect(box.x, box.y, box.w, 1), colour, 0.9) }
            if input.panel.heldStep == s { c.frame(box, Palette.yellow, 0.9, radius: 2) }
            let y = r.y + rows + 4
            c.pill(DotRect(box.x + box.w / 2 - 4, y, 8, 6), cell.notes > 0 ? colour : Palette.ink, cell.notes > 0 ? 0.35 + 0.65 * Double(cell.velocity) / 127 : used ? 0.14 : 0.05, radius: 2)
            if cell.component { c.fill(DotRect(box.x + box.w / 2 + 6, y, 2, 2), Palette.yellow) }
            if cell.lock { c.fill(DotRect(box.x + box.w / 2 + 6, y + 4, 2, 2), Palette.purple) }
        }
        for (s, n) in notes {
            let nx = Double(x(s)) + 1, len = min(Double(r.w), max(2, Double(n.duration) / 6200 * Double(w) - 2))
            let y = r.y + 2 + Int((1 - Double(n.note - lo) / Double(hi - lo)) * Double(rows - 5))
            let playing = head == s
            c.fill(DotRect(Int(nx), y, Int(min(len, Double(r.maxX) - nx)), 2), playing ? .white : colour, playing ? 1 : 0.4 + 0.6 * Double(n.velocity) / 127)
        }
        if notes.isEmpty { c.text("NO NOTES", r.midX, r.y + rows / 2 - 3, Palette.ink, 0.28, align: .center) }
    }

    // MARK: GRID: all sixteen tracks

    func gridPage(_ c: DotCanvas, _ r: DotRect, _ dt: Double) {
        let names = r.w > 250 ? 62 : 34, gap = 4
        let w = (r.w - names - gap * 3) / 16, h = Double(r.h - 8) / 16
        func x(_ s: Int) -> Int { r.x + names + s * w + (s / 4) * gap }
        for s in 0..<16 where w > 13 || s % 4 == 0 { c.text("\(s + 1)", x(s) + w / 2, r.y, Palette.ink, s % 4 == 0 ? 0.6 : 0.25, font: .tiny, align: .center) }
        trackY.target = Double(r.y) + 8 + h * Double(track)
        if trackY.value == 0 { trackY.jump(trackY.target) }
        trackY.step(dt)
        c.pill(DotRect(r.x - 2, Int(trackY.value.rounded()), r.w + 4, Int(h)), Palette.ink, 0.08, radius: 2)
        for t in 0..<16 {
            let y = r.y + 8 + Int(h * Double(t)), row = Int(h) - 1, colour = Palette.track(t), dim = grid.muted[t] ? 0.3 : 1.0
            let hit = hitFlashes[t].level
            c.fill(DotRect(r.x, y + 1, 2, row - 2), colour, dim * (0.5 + 0.5 * hit))
            let textY = y + (row - 5) / 2
            c.text(String(OPZ.trackNames[t].uppercased().prefix(names > 40 ? 7 : 4)), r.x + 5, textY, t == track ? .white : Palette.ink, dim * (t == track ? 1 : 0.6), font: .tiny)
            if names > 40 {
                let v = Int(levels[t].level * 18)
                for i in 0..<18 { c.set(r.x + 38 + i, textY + 2, i < v ? colour : Palette.ink, i < v ? 1 : 0.08) }
            }
            let head = playhead(t)
            for s in 0..<16 {
                let cell = grid[t, s], used = s < grid.lengths[t]
                let box = DotRect(x(s), y, w - 1, row)
                if cell.notes > 0 {
                    let v = 0.3 + 0.7 * Double(cell.velocity) / 127
                    c.pill(box, colour, dim * v * (used ? 1 : 0.3), radius: 2)
                    if head == s { c.pill(box, .white, 0.25 + 0.75 * hit, radius: 2) }
                    if cell.notes > 1, row > 7 {
                        for k in 0..<min(Int(cell.notes), 4) { c.set(box.x + 2 + k * 2, box.maxY - 2, .black, 0.7) }
                    }
                } else if used {
                    c.pill(box, Palette.ink, head == s ? (grid.noteCount[t] > 0 ? 0.24 : 0.1) : 0.05, radius: 2)
                    if head != s { c.set(box.midX, box.midY, Palette.ink, 0.2) }
                }
                if cell.component { c.set(box.maxX - 2, box.y + 1, Palette.yellow); c.set(box.maxX - 3, box.y + 1, Palette.yellow) }
                if cell.lock { c.rule(box.x + 2, box.maxY - 1, 4, .white, 0.9) }
            }
            touches.append((DotRect(r.x - 2, y, r.w + 4, Int(h)), .track(t)))
        }
    }

    // MARK: MIX: levels, sends, pan, mutes

    func mixPage(_ c: DotCanvas, _ r: DotRect, _ dt: Double) {
        let n = 12, w = r.w / n, top = r.y + 20, bottom = r.maxY - 34
        for t in 0..<n {
            let x = r.x + t * w, colour = Palette.track(t), dim = grid.muted[t] ? 0.25 : 1.0, mid = x + w / 2
            c.text(w > 34 ? OPZ.trackNames[t].uppercased() : w > 23 ? String(OPZ.trackNames[t].uppercased().prefix(4)) : Palette.shortNames[t], mid, r.y, t == track ? .white : Palette.ink, t == track ? 1 : 0.6, font: .tiny, align: .center)
            if let s = input.sounds[t], w > 30 { c.text(DotFont.tiny.fitted(s.name, w - 4), mid, r.y + 8, colour, 0.7, font: .tiny, align: .center) }
            for k in 0..<18 { if t != track { knobs[t][k].step(dt) } }
            let level = gain(t)
            let h = bottom - top
            // the fader
            let fx = mid - 6
            c.column(fx, top, h, Palette.ink, 0.2, step: 2)
            let fy = bottom - Int(level * Double(h))
            c.fill(DotRect(fx - 4, fy - 1, 9, 3), .white, dim)
            for y in stride(from: bottom - 1, to: fy, by: -2) { c.set(fx, y, colour, dim * 0.8) }
            // what it plays
            let m = levels[t].level * level, rows = h / 3
            for i in 0..<rows {
                let f = Double(i) / Double(rows), on = f < m
                c.fill(DotRect(mid + 2, bottom - 2 - i * 3, 6, 2), f > 0.85 ? Palette.red : f > 0.7 ? Palette.yellow : colour, on ? dim : 0.07)
            }
            // sends and pan
            for (k, index) in [6, 7].enumerated() where t < 8 || t >= 10 {
                let v = knobs[t][index].value, y = bottom + 6 + k * 6
                c.rule(x + 4, y, w - 8, Palette.ink, 0.15, step: 2)
                c.rule(x + 4, y, Int(v * Double(w - 8)), Palette.track(8 + k), dim)
            }
            let p = knobs[t][10].value
            c.rule(x + 4, bottom + 18, w - 8, Palette.ink, 0.15, step: 2)
            c.fill(DotRect(x + 4 + Int(p * Double(w - 10)), bottom + 17, 2, 3), Palette.yellow, dim)
            c.text(grid.muted[t] ? (w > 23 ? (grid.audioMuted[t] ? "AUD" : "MUTE") : "M") : "\(Int(level * 100))", mid, r.maxY - 8, grid.muted[t] ? Palette.red : Palette.ink, grid.muted[t] ? 1 : 0.7, font: .tiny, align: .center)
            touches.append((DotRect(x, r.y, w, r.h), .track(t)))
            touches.append((DotRect(x, top - 4, w, h + 6), .grip(.gain(t))))
            for (k, index) in [6, 7].enumerated() where t < 8 || t >= 10 { touches.append((DotRect(x, bottom + 4 + k * 6, w, 6), .grip(.sound(t, index, across: true)))) }
            touches.append((DotRect(x, bottom + 16, w, 7), .grip(.sound(t, 10, across: true))))
            touches.append((DotRect(x, r.maxY - 12, w, 9), .grip(.mute(t))))
        }
    }

    // MARK: SONG: the project's patterns, its tempo

    func songPage(_ c: DotCanvas, _ r: DotRect, _ dt: Double) {
        guard let bank = input.bank else { return }
        let wide = r.w > r.h, side = wide ? max(88, r.w * 28 / 100) : r.w
        let tiles = wide ? DotRect(r.x, r.y, r.w - side - 8, r.h) : DotRect(r.x, r.y + 64, r.w, r.h - 64)
        let w = tiles.w / 4, h = tiles.h / 4
        for p in 0..<16 {
            let box = DotRect(tiles.x + p % 4 * w, tiles.y + p / 4 * h, w - 4, h - 4)
            let active = p == input.address?.pattern, used = bank.patternInUse(p)
            c.frame(box, active ? Palette.yellow : Palette.ink, active ? 1 : used ? 0.35 : 0.1, radius: 2)
            touches.append((box, .grip(.pattern(p))))
            if active { c.frame(box.inset(1, 1), Palette.yellow, 0.25 + 0.6 * pulse.level, radius: 1) }
            c.text(pad(p + 1), box.x + 4, box.y + 4, active ? Palette.yellow : Palette.ink, used || active ? 0.9 : 0.25)
            // its notes, a dot each
            thumbnail(p, bank, in: box.inset(4, 13), c, active)
        }
        let s = wide ? DotRect(r.maxX - side, r.y, side, r.h) : DotRect(r.x, r.y, r.w, 60)
        c.text("PROJECT", s.x, s.y, Palette.ink, 0.45, font: .tiny)
        c.text(input.address.map { pad($0.project + 1) } ?? "--", s.x, s.y + 8, Palette.ink, 1, font: .huge)
        let bx = wide ? s.x : s.x + s.w / 3, by = wide ? s.y + 46 : s.y
        c.text("TEMPO", bx, by, Palette.ink, 0.45, font: .tiny)
        c.text(input.tempo.map(String.init) ?? "---", bx, by + 8, Palette.yellow, 0.75 + 0.25 * pulse.level, font: .huge)
        let px = wide ? s.x : s.x + s.w * 2 / 3, py = wide ? s.y + 92 : s.y
        c.text("STEP", px, py, Palette.ink, 0.45, font: .tiny)
        for i in 0..<16 {
            let on = playhead.playing && playhead.step == i
            c.pill(DotRect(px + (i % 8) * 9, py + 8 + (i / 8) * 9, 7, 7), on ? Palette.green : Palette.ink, on ? 1 : i % 4 == 0 ? 0.28 : 0.12, radius: 2)
        }
        if wide, s.h > 150 {
            let notes = grid.noteCount.reduce(0, +), tracks = grid.noteCount.filter { $0 > 0 }.count
            c.text("\(tracks) TRACKS", s.x, py + 36, Palette.ink, 0.7)
            c.text("\(notes) NOTES", s.x, py + 46, Palette.ink, 0.7)
            let patterns = (0..<16).filter { bank.patternInUse($0) }.count
            c.text("\(patterns) OF 16 IN USE", s.x, py + 58, Palette.ink, 0.45, font: .tiny)
            if let sw = input.swing, sw != 127 { c.text("SWING \(sw > 127 ? "+" : "-")\(abs(sw - 127))", s.x, py + 66, Palette.ink, 0.45, font: .tiny) }
        }
    }

    private func thumbnail(_ p: Int, _ bank: Bank, in r: DotRect, _ c: DotCanvas, _ active: Bool) {
        let g = thumbnails.grid(p, bank, input.revision, active: p == input.address?.pattern ? grid : nil)
        guard r.w > 15, r.h > 7 else { return }
        for t in 0..<10 {
            let y = r.y + t * r.h / 10, hh = max(1, r.h / 10 - 1)
            for s in 0..<16 where g.cells[t * 16 + s].notes > 0 {
                let x = r.x + s * r.w / 16, w = max(1, r.w / 16 - 1), here = active && playhead(t) == s
                c.fill(DotRect(x, y, w, hh), here ? .white : Palette.track(t), here ? 1 : active ? 0.95 : 0.55)
            }
        }
    }

    // MARK: NOTES: what was played, going by

    func notesPage(_ c: DotCanvas, _ r: DotRect, _ dt: Double) {
        let keysH = 34, roll = DotRect(r.x, r.y, r.w, r.h - keysH - 3), keys = DotRect(r.x, r.maxY - keysH, r.w, keysH)
        let octaves = max(3, min(7, r.w / 49)), low = 60 - (octaves / 2) * 12
        let white = r.w / (octaves * 7), left = r.x + (r.w - white * octaves * 7) / 2
        func x(_ note: Int) -> (Int, Int, Bool) {     // left, width, black
            let n = note - low, o = n >= 0 ? n / 12 : (n - 11) / 12, k = n - o * 12
            let whites = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6][k], black = [1, 3, 6, 8, 10].contains(k)
            let base = left + (o * 7 + whites) * white
            return black ? (base + white - white / 3 - 1, max(2, white * 2 / 3), true) : (base, white - 1, false)
        }
        for o in 0...octaves { c.column(left + o * 7 * white - 1, roll.y, roll.h, Palette.ink, 0.12, step: 3) }
        for k in 1...8 { c.rule(roll.x, roll.maxY - k * roll.h / 8, roll.w, Palette.ink, 0.06, step: 4) }
        c.clipped(roll) {
            let perSecond = Double(roll.h) / 4
            for n in trail.notes {
                let newest = time - n.start, oldest = time - (n.end ?? time)
                guard oldest < 4 else { continue }
                let y0 = roll.maxY - Int(newest * perSecond), y1 = roll.maxY - Int(oldest * perSecond)
                let (nx, nw, _) = x(n.note), colour = Palette.track(n.track), live = oldest <= 0
                let fade = max(0, 1 - oldest / 4)
                c.pill(DotRect(nx, y0, nw, max(2, y1 - y0)), colour, (0.3 + 0.7 * n.velocity) * fade, radius: 2)
                if live { c.fill(DotRect(nx, roll.maxY - 2, nw, 2), .white) }
            }
        }
        let sounding = trail.sounding(time)
        for o in 0..<octaves { for k in 0..<12 {
            let note = low + o * 12 + k, (nx, nw, black) = x(note)
            guard !black else { continue }
            let on = sounding.last { $0.note == note }
            c.pill(DotRect(nx, keys.y, nw, keys.h), on.map { Palette.track($0.track) } ?? Palette.ink, on == nil ? 0.16 : 1, radius: 2)
            if k == 0 { c.text("C\(note / 12 - 1)", nx + nw / 2, keys.maxY - 7, on == nil ? Palette.ink : .black, 0.6, font: .tiny, align: .center) }
        } }
        for o in 0..<octaves { for k in [1, 3, 6, 8, 10] {
            let note = low + o * 12 + k, (nx, nw, _) = x(note)
            let on = sounding.last { $0.note == note }
            c.pill(DotRect(nx - 1, keys.y, nw + 2, keys.h * 6 / 10), .black, 1, radius: 1)
            c.pill(DotRect(nx, keys.y, nw, keys.h * 6 / 10 - 1), on.map { Palette.track($0.track) } ?? Palette.ink, on == nil ? 0.05 : 1, radius: 1)
        } }
        let held = Set(sounding.filter { $0.track >= 4 && $0.track < 8 }.map { $0.note }).sorted()
        if let name = Chord.name(held) { c.text(name, r.maxX - 2, r.y + 2, .white, 0.95, font: .big, align: .right) }
        else if trail.notes.isEmpty { c.text("PLAY SOMETHING", r.midX, r.y + roll.h / 2, Palette.ink, 0.3, align: .center) }
    }

    // MARK: LOAD: Galax-z's load meter

    func loadPage(_ c: DotCanvas, _ r: DotRect, _ dt: Double) {
        guard let l = input.load else {
            let y = r.midY - 34
            c.text("LOAD METER", r.midX, y, Palette.ink, 0.95, font: .big, align: .center)
            for (i, s) in ["ON GALAX-Z V8 OR NEWER:", "SHIFT + TEMPO SHOWS THE METER ON THE KEYS", "THEN PLAY, WITH THE MIDI SWITCH ON HOST",
                           "SHIFT + SCREEN SENDS THE FIGURES HERE"].enumerated() {
                c.text(s, r.midX, y + 26 + i * 12, i == 0 ? Palette.yellow : Palette.ink, i == 0 ? 0.9 : 0.6, font: r.w > 260 ? .small : .tiny, align: .center)
            }
            for i in 0..<24 {
                let f = Double(i) / 24, v = 0.25 + 0.2 * Turn.sine(time * 0.12 + f) + 0.15 * Turn.sine(time * 0.31 - f * 2)
                c.fill(DotRect(r.midX - 96 + i * 8, r.maxY - 6 - Int(v * 40), 6, 2), Palette.green, 0.5)
            }
            return
        }
        let w = r.w * 62 / 100
        func bar(_ y: Int, _ name: String, _ mean: Int, _ top: Int, _ of: Int) {
            let m = Double(mean) / Double(of), k = Double(top) / Double(of), cells = 32, cw = (w - 4) / cells
            c.text(name, r.x, y, Palette.ink, 0.8, font: .tiny)
            for i in 0..<cells {
                let f = Double(i) / Double(cells), colour = f >= 0.8 ? Palette.red : f >= 0.62 ? Palette.yellow : Palette.green
                let on = f < m, peak = f < k
                c.pill(DotRect(r.x + i * cw, y + 8, cw - 1, 22), on || peak ? colour : Palette.ink, on ? 1 : peak ? 0.32 : 0.08, radius: 1)
            }
            c.text("\(Int((k * 100).rounded()))%", r.x + w + 8, y + 8, k >= 0.8 ? Palette.red : Palette.ink, 1, font: .big)
            c.text("MEAN \(Int((m * 100).rounded()))%", r.x + w + 8, y + 25, Palette.ink, 0.5, font: .tiny)
        }
        bar(r.y + 2, "INSTRUMENTS, OF THE OS'S LIMIT", l.instrumentsMean, l.instrumentsTop, LoadReport.line)
        bar(r.y + 44, "ALL AUDIO, OF THE WHOLE BLOCK", l.totalMean, l.totalTop, LoadReport.block)
        let y = r.y + 88
        for (i, (name, value, bad)) in [("NOTES CUT", "\(l.notesCut)", l.notesCut > 0), ("MOST NOTES", "\(l.notesTop)", false),
                                        (r.w > 290 ? "SLOWEST FRAME" : "FRAME", "\(l.longestFrame) MS", l.longestFrame > 40), ("MEASURED", "\(Int(l.seconds)) S", false)].enumerated() {
            let x = r.x + i * r.w / 4
            c.text(name, x, y, Palette.ink, 0.5, font: .tiny)
            c.text(value, x, y + 9, bad ? Palette.red : Palette.ink, 1, font: .big)
        }
        let h = DotRect(r.x, y + 34, r.w, max(20, r.maxY - y - 36))
        for k in 0...4 { c.rule(h.x, h.y + k * (h.h - 1) / 4, h.w, Palette.ink, 0.12, step: 3) }
        let left = max(0, (LoadReport.line - l.instrumentsTop) / 10_250)
        c.text("ROOM FOR ABOUT \(left) MORE PIANO NOTES", h.x + 3, h.y + 3, Palette.green, 0.8, font: .tiny)
        for (i, v) in loads.enumerated() {
            let bw = max(3, h.w / 48)
            c.fill(DotRect(h.x + i * bw, h.maxY - Int(min(1, v) * Double(h.h)), bw - 1, 2), v > 0.8 ? Palette.red : Palette.green)
        }
    }
}

/// The sixteen patterns small, made once per change.
struct Thumbnails {
    private var made: [Int: (Int, PatternGrid)] = [:]
    mutating func grid(_ p: Int, _ bank: Bank, _ revision: Int, active: PatternGrid?) -> PatternGrid {
        if let active { return active }
        if let (r, g) = made[p], r == revision { return g }
        let g = PatternGrid(bank, p)
        made[p] = (revision, g)
        return g
    }
}

enum Chord {
    private static let shapes: [([Int], String)] = [
        ([0, 4, 7], ""), ([0, 3, 7], "M"), ([0, 4, 7, 11], "MAJ7"), ([0, 3, 7, 10], "M7"), ([0, 4, 7, 10], "7"),
        ([0, 3, 6], "DIM"), ([0, 4, 8], "AUG"), ([0, 5, 7], "SUS4"), ([0, 2, 7], "SUS2"), ([0, 4, 7, 9], "6"),
        ([0, 3, 7, 9], "M6"), ([0, 3, 6, 10], "M7B5"), ([0, 3, 6, 9], "DIM7"), ([0, 2, 4, 7], "ADD9"), ([0, 2, 3, 7], "M ADD9"),
        ([0, 2, 4, 7, 10], "9"), ([0, 2, 4, 7, 11], "MAJ9"), ([0, 2, 3, 7, 10], "M9"),
    ]
    /// The chord these notes are, if they are one (the lowest is tried as the root first).
    static func name(_ notes: [Int]) -> String? {
        let set = Set(notes.map { $0 % 12 })
        guard set.count >= 3, let bass = notes.min().map({ $0 % 12 }) else { return nil }
        for root in [bass] + (0..<12).filter({ $0 != bass && set.contains($0) }) {
            let shape = set.map { (($0 - root) % 12 + 12) % 12 }.sorted()
            if let (_, n) = shapes.first(where: { $0.0 == shape }) {
                return Palette.noteNames[root] + n + (root == bass ? "" : "/" + Palette.noteNames[bass])
            }
        }
        return nil
    }
}
