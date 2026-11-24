import DotKit

/// What the motion track shows, as a photo booth and a video lab would: photographs drawn from code, dot by dot, and small 3D films.
enum Slide: Int, CaseIterable {
    case sunset, city, horizon, waves, tunnel, peaks, stars
    var name: String { ["SUNSET", "CITY", "HORIZON", "WAVES", "TUNNEL", "PEAKS", "STARS"][rawValue] }
    var film: Bool { self == .horizon || self == .tunnel || self == .stars }
}

/// What is done to a photograph on its way to the screen: a note's name picks one.
enum Lens: Int, CaseIterable {
    case plain, zoom, tint, scan, poster, mirror
    var name: String { ["PLAIN", "ZOOM", "TINT", "SCAN", "POSTER", "KALEIDO"][rawValue] }
    /// Whether it does anything to this: a film only takes a tint and scan lines.
    func shows(on s: Slide) -> Bool { self != .plain && (!s.film || self == .tint || self == .scan) }
}

extension DotColor {
    /// `mixed` in whole numbers, for what is done once a dot.
    @inline(__always) func blend(_ o: DotColor, _ t: Double) -> DotColor {
        let k = Int(min(max(t, 0), 1) * 256)
        @inline(__always) func m(_ a: UInt8, _ b: UInt8) -> UInt8 { UInt8(Int(a) + ((Int(b) - Int(a)) * k) >> 8) }
        return DotColor(m(r, o.r), m(g, o.g), m(b, o.b))
    }
}

@inline(__always) func frac(_ x: Double) -> Double { x - x.rounded(.down) }
@inline(__always) private func cell(_ x: Double) -> Int { Int(x.rounded(.down)) }
/// The same number for the same two, between 0 and 1.
@inline(__always) func hash(_ i: Int, _ j: Int = 0) -> Double {
    var x = UInt64(bitPattern: Int64((i &* 73_856_093) ^ (j &* 19_349_663))) &* 0x9E37_79B9_7F4A_7C15
    x ^= x >> 31; x = x &* 0xBF58_476D_1CE4_E5B9; x ^= x >> 29
    return Double(x >> 11) / 9_007_199_254_740_992
}

extension Stage {
    /// On to the next picture: at each note of the motion track, or with it silent every two bars (six seconds, stopped).
    func reelOn() {
        if let s = strikes[15].last, s > show.seen {
            show.seen = s
            show.slide += 1
            show.slideAt = time
            show.lens = Lens(rawValue: (((lastNote[15] % 12) + 12) % 12) % Lens.allCases.count) ?? .plain
            show.shake = lastVelocity[15]
            return
        }
        guard grid.noteCount[15] == 0, strikes[15].last.map({ time - $0 > 6 }) ?? true else { return }
        let k = playhead.playing ? cell(beat / 8) : cell(time / 6)
        guard k != show.tick else { return }
        if show.tick != .min {
            show.slide += 1
            show.slideAt = time
            show.lens = Lens.allCases[(show.slide / 2) % Lens.allCases.count]
            show.shake = 0.3
        }
        show.tick = k
    }

    /// The picture on now, in a box: P1 how far the camera goes in, P2 the tint's hue. `caption`: its name and lens.
    func reel(_ c: DotCanvas, _ whole: DotRect, p1: Double, p2: Double, caption: Bool) {
        guard whole.w > 8, whole.h > 8 else { return }
        // a box taller than four by three: the picture across its middle, on film, its sprocket holes above and below
        let tall = whole.h > whole.w * 3 / 4 + 24, r = tall ? DotRect(whole.x, whole.midY - whole.w * 3 / 8, whole.w, whole.w * 3 / 4) : whole
        if tall {
            for x in stride(from: whole.x + 3, to: whole.maxX - 4, by: 9) {
                c.pill(DotRect(x, r.y - 9, 5, 5), Palette.ink, 0.22, radius: 1)
                c.pill(DotRect(x, r.maxY + 4, 5, 5), Palette.ink, 0.22, radius: 1)
            }
        }
        let slide = Slide.allCases[((show.slide % Slide.allCases.count) + Slide.allCases.count) % Slide.allCases.count], age = time - show.slideAt, lens = show.lens
        let flash = max(0, 1 - age / 0.3), jolt = max(0, 1 - age / 0.35) * show.shake * 3.5
        let dx = jolt * Turn.sine(age * 23), dy = jolt * Turn.sine(age * 17 + 0.25)
        let tint = DotColor.hue(p2 + 0.02, 0.75, 1)
        if slide.film {
            c.clipped(r) {
                let w = Double(r.w), h = Double(r.h), speed = playhead.playing ? Double(max(40, input.tempo ?? 120)) / 120 : 0.35
                let colour = lens == .tint ? tint : keyColour(4..<8)
                switch slide {
                case .horizon: terrain(c, r, colour, speed: speed * 0.9, swell: 0.4 + 0.6 * levels[4].level, sun: DotColor(0xFFC23D))
                case .tunnel: tunnel(c, Double(r.x) + w / 2 + dx, Double(r.y) + h / 2 + dy, max(w, h) * 0.7, colour, speed: speed * 0.22, punch: levels[0].level, sides: 4 + show.slide % 3)
                default: starfield(c, r, colour, speed: 0.08 + 0.2 * speed * (0.5 + p1), count: r.w * r.h / 70)
                }
                if lens == .scan { for y in stride(from: r.y + 1, to: r.maxY, by: 2) { c.rule(r.x, y, r.w, .black, 0.55) } }
                if flash > 0 { c.fill(r, .white, flash * 0.6) }
            }
        } else {
            photo(c, r, slide, lens, age: age, flash: flash, shift: (dx, dy), tint: tint, p1: p1)
        }
        guard caption, whole.w > 90, whole.h > 30 else { return }
        let words = "\(pad(slide.rawValue + 1)) \(slide.name)" + (lens.shows(on: slide) ? " · \(lens.name)" : "")
        let tw = DotFont.tiny.width(words)
        c.fill(DotRect(whole.x, whole.maxY - 9, tw + 6, 9), .black, 0.7)
        c.text(words, whole.x + 3, whole.maxY - 7, .white, 0.85, font: .tiny)
        for i in 0..<Slide.allCases.count { c.fill(DotRect(whole.maxX - 4 - (Slide.allCases.count - 1 - i) * 4, whole.maxY - 5, 2, 2), i == slide.rawValue ? .white : Palette.ink, i == slide.rawValue ? 1 : 0.3) }
    }

    /// A photograph, dot by dot, through a lens, the camera creeping in on it.
    private func photo(_ c: DotCanvas, _ r: DotRect, _ s: Slide, _ lens: Lens, age: Double, flash: Double, shift: (Double, Double), tint: DotColor, p1: Double) {
        let w = Double(r.w), h = Double(r.h), aspect = w / h, life = Ease.inOut(min(1, age / 10))
        let zoom = 1 + (lens == .zoom ? 0.2 + 0.6 * p1 : 0.1) * life, side = show.slide % 2 == 0 ? 1.0 : -1
        let panX = side * 0.05 * life, panY = -0.025 * life
        let dark = tint.scaled(0.12), light = tint.blend(.white, 0.6), t = time
        let turn = Turn.of(t * 0.02), roll = frac(t * 0.23) * h
        // a big one is worked out a square of four dots at a time
        let b = r.w * r.h > 26_000 ? 2 : 1, half = Double(b) / 2
        for y in stride(from: r.y, to: r.maxY, by: b) {
            let row = Double(y - r.y), band = lens == .scan && abs(row - roll) < 3 ? 1.0 : 0
            let vy = 0.5 + ((row + half + shift.1) / h - 0.5) / zoom + panY
            let dim = lens == .scan ? (y & 1 == 1 ? 0.45 : 1) : 1
            for x in stride(from: r.x, to: r.maxX, by: b) {
                var u = 0.5 + ((Double(x - r.x) + half + shift.0 + band * 3) / w - 0.5) / zoom + panX, v = vy
                if lens == .mirror {                 // turned, folded into eight
                    let a = (u - 0.5) * aspect, b = v - 0.5
                    var p = abs(a * turn.y - b * turn.x), q = abs(a * turn.x + b * turn.y)
                    if q > p { (p, q) = (q, p) }
                    u = 0.3 + p / aspect * 1.2; v = 0.32 + q * 1.2
                }
                var k = picture(s, u, v, aspect, t)
                switch lens {
                case .tint: k = dark.blend(light, (0.3 * Double(k.r) + 0.59 * Double(k.g) + 0.11 * Double(k.b)) / 255)
                case .poster: k = DotColor(UInt8(Int(k.r) >> 6 * 85), UInt8(Int(k.g) >> 6 * 85), UInt8(Int(k.b) >> 6 * 85))
                case .scan: k = DotColor.black.blend(k, dim + band * 0.3)
                default: break
                }
                if flash > 0 { k = k.blend(.white, flash * 0.85) }
                c.set(x, y, k)
                guard b > 1 else { continue }
                c.set(x + 1, y, k)
                let under = lens == .scan ? DotColor.black.blend(k, 0.45) : k
                c.set(x, y + 1, under); c.set(x + 1, y + 1, under)
            }
        }
    }

    /// The colour of one point of a photograph: `u` across, `v` down, 0 to 1 (beyond, as the camera goes).
    private func picture(_ s: Slide, _ u: Double, _ v: Double, _ aspect: Double, _ t: Double) -> DotColor {
        let du = (u - 0.5) * aspect
        switch s {
        case .sunset:
            let horizon = 0.64
            if v < horizon {
                let k = max(0, v) / horizon
                var col = k < 0.55 ? DotColor(0x1B0C45).blend(DotColor(0x8E2A7E), k / 0.55) : DotColor(0x8E2A7E).blend(DotColor(0xFF8A3D), (k - 0.55) / 0.45)
                let sy = horizon - 0.1, dy = v - sy, R = 0.27, d = (du * du + dy * dy).squareRoot()
                if d < R {
                    let cut = dy > 0 && frac(v * 24) < dy / R * 0.6       // the sun's lower half in bands
                    if !cut { col = DotColor(0xFFE66B).blend(DotColor(0xFF4F6E), (v - sy + R) / (2 * R)) }
                } else { col = col.blend(DotColor(0xFFB25A), max(0, 0.3 - (d - R)) * 1.6) }
                if k < 0.45, hash(cell(u * 160), cell(v * 90)) > 0.993 { col = col.blend(.white, 0.7) }
                return col
            }
            let k = (v - horizon) / (1 - horizon), road = 0.08 + 0.3 * k
            var col = DotColor(0x3A1A5E).blend(DotColor(0x07061A), k)
            let ripple = Turn.sine(1.4 / (k + 0.1) - t * 0.2 + du * 0.7)
            if abs(du) < road * (0.7 + 0.3 * ripple), ripple > 0.2 { col = col.blend(DotColor(0xFFA14A), (1 - abs(du) / road) * 0.95) }
            else if ripple > 0.85 { col = col.blend(DotColor(0xB04A9A), 0.35) }
            return col
        case .city:
            var col = DotColor(0x0A0E2C).blend(DotColor(0x4A2368), v / 0.8)
            if v < 0.6, hash(cell(u * 170), cell(v * 110)) > 0.991 { col = col.blend(.white, 0.4 + 0.4 * Turn.sine(t * 0.4 + u * 9)) }
            let mx = (u - 0.8) * aspect, my = v - 0.18, mx2 = mx - 0.035
            if mx * mx + my * my < 0.0049, mx2 * mx2 + my * my > 0.0036 { col = DotColor(0xFFF2C8) }
            let far = cell(u * 26), farTop = 0.42 + 0.22 * hash(far, 1)
            if v > farTop {
                col = DotColor(0x2A2050)
                if frac(u * 26 * 3) > 0.5, frac(v * 50) > 0.5, hash(cell(u * 78), cell(v * 50)) > 0.8 { col = DotColor(0x8C6FD0) }
            }
            let near = cell(u * 11 + 0.37), nearTop = 0.5 + 0.32 * hash(near, 2)
            if v > nearTop {
                col = DotColor(0x0D0B1A)
                let lx = frac((u * 11 + 0.37) * 5), ly = frac(v * 42)
                if lx > 0.22, lx < 0.72, ly > 0.3, ly < 0.78, hash(cell((u * 11 + 0.37) * 5), cell(v * 42) &+ near) > 0.48 {
                    col = hash(near, 7) > 0.7 ? DotColor(0x7FE3FF) : DotColor(0xFFC66A)
                }
            }
            if v > 0.93 {
                col = DotColor(0x121022)
                let car = frac(u * 5 - t * 0.12 * (v > 0.965 ? -1 : 1))
                if car < 0.04 { col = v > 0.965 ? DotColor(0xFF3B2F) : DotColor(0xFFF4D0) }
            }
            return col
        case .waves:
            let horizon = 0.38, shore = 0.8 + 0.025 * Turn.sine(u * 0.9 + t * 0.04) + 0.018 * Turn.sine(t * 0.13)
            if v < horizon {
                var col = DotColor(0x7FCBEF).blend(DotColor(0xFFE2B8), max(0, v) / horizon)
                let cloud = 0.5 * Turn.sine(u * 1.3 + t * 0.008) + 0.3 * Turn.sine(u * 3.1 + 0.2)
                if abs(v - 0.14 - 0.03 * cloud) < 0.02 + 0.03 * max(0, cloud) { col = col.blend(.white, 0.75) }
                return col
            }
            if v < shore {
                let k = (v - horizon) / (shore - horizon), z = 1 / (k + 0.12)
                var col = DotColor(0x17698F).blend(DotColor(0x35C6C9), k)
                let f = frac(z * 0.9 - t * 0.16 + 0.06 * Turn.sine(u * 2.5 + z * 0.3))
                if f < 0.14 * (k + 0.25) { col = col.blend(.white, 0.85 * (1 - f / (0.14 * (k + 0.25)))) }
                if hash(cell(u * 200), cell(v * 120)) > 0.985, Turn.sine(t * 0.6 + u * 40) > 0.6 { col = col.blend(.white, 0.8) }
                return col
            }
            if v - shore < 0.012 { return DotColor(0xF4FBFF) }
            return v - shore < 0.05 ? DotColor(0xB89468) : DotColor(0xEFCF9C).blend(DotColor(0xD9B47E), hash(cell(u * 300), cell(v * 200)))
        default:            // peaks
            var col = DotColor(0x7BB3D8).blend(DotColor(0xF6C7A0), min(1, max(0, v) / 0.62))
            let sx = (u - 0.3) * aspect, sy = v - 0.3, d = sx * sx + sy * sy
            col = d < 0.006 ? DotColor(0xFFF4DC) : col.blend(DotColor(0xFFF0D0), max(0, 0.25 - d * 4))
            let bases = [0.6, 0.74, 0.9], amps = [0.34, 0.26, 0.2], tones = [DotColor(0x8C93B8), DotColor(0x4E5A86), DotColor(0x1A2038)]
            for k in 0..<3 {
                let ph = Double(k) * 0.37, hgt = 0.6 * (1 - abs(Turn.sine(u * 0.45 + ph))) + 0.3 * (1 - abs(Turn.sine(u * 1.15 + ph * 2))) + 0.1 * Turn.sine(u * 3.7)
                let top = bases[k] - amps[k] * hgt
                guard v > top else { continue }
                col = tones[k].blend(.black, min(0.5, (v - top) * 0.8))
                if k == 0, v < top + 0.035 + 0.02 * Turn.sine(u * 11), hgt > 0.55 { col = DotColor(0xF2F4FF) }
                else if v < top + 0.05 { col = col.blend(DotColor(0xF6C7A0), 0.25 * (1 - (v - top) / 0.05)) }
            }
            return col
        }
    }

    // MARK: the films, which SHOW uses too

    /// A wire tunnel coming at you: rings of `sides` corners, rails along it, a kick widening it.
    func tunnel(_ c: DotCanvas, _ cx: Double, _ cy: Double, _ R: Double, _ colour: DotColor, speed: Double, punch: Double, sides: Int, rings: Int = 14) {
        let t = time, twist = 0.08 * Turn.sine(t * 0.03), turn = t * 0.015
        let ox = Turn.sine(t * 0.05) * R * 0.12, oy = Turn.sine(t * 0.037 + 0.2) * R * 0.08
        for j in 0..<sides {            // rails: from far in the middle out past the edge
            let a = Turn.of(turn + Double(j) / Double(sides) + twist)
            c.line(cx + ox + a.x * R * 0.03, cy + oy + a.y * R * 0.03, cx + a.x * R * 1.6, cy + a.y * R * 1.6, colour, 0.12)
        }
        for i in 0..<rings {
            let d = frac(Double(i) / Double(rings) + t * speed), scale = 0.045 / (1.045 - d) * (1 + 0.12 * punch)
            let rr = R * scale, a = d * d * (d > 0.9 ? (1 - d) * 10 : 1) * (0.5 + 0.5 * punch)
            guard rr > 1.5, a > 0.01 else { continue }
            let rx = cx + ox * (1 - d), ry = cy + oy * (1 - d), spin = turn + twist * (1 - d) * 3
            let k = i % 2 == 0 ? colour : colour.blend(.white, 0.45)
            var last = Turn.of(spin)
            for j in 1...sides {
                let p = Turn.of(spin + Double(j) / Double(sides))
                c.line(rx + last.x * rr, ry + last.y * rr, rx + p.x * rr, ry + p.y * rr, k, min(1, a * 1.3))
                last = p
            }
        }
    }

    /// A wire landscape going by under a banded sun, the hills by the side swelling with `swell`.
    func terrain(_ c: DotCanvas, _ r: DotRect, _ colour: DotColor, speed: Double, swell: Double, sun: DotColor) {
        let w = Double(r.w), h = Double(r.h), cx = Double(r.x) + w / 2, horizon = Double(r.y) + h * 0.44, t = time
        // the sun, its lower half cut in bands, sitting on the horizon
        let R = min(h * 0.26, w * 0.2), sy = horizon - R * 0.35
        for y in max(r.y, Int(sy - R))..<min(Int(horizon), r.maxY) {
            let dy = Double(y) - sy, half = (max(0, R * R - dy * dy)).squareRoot(), f = (dy + R) / (2 * R)
            if dy > 0, frac(Double(y) * 0.16) < dy / R * 0.7 { continue }
            for x in Int(cx - half)...Int(cx + half) { c.add(x, y, sun.blend(DotColor(0xFF3D8B), f), 0.85) }
        }
        for k in 0..<3 { c.arc(cx, sy, R + 2 + Double(k) * 3, from: 0.75, to: 1.25, sun, 0.18 - Double(k) * 0.05) }
        c.rule(r.x, Int(horizon), r.w, colour, 0.7)
        let travel = t * speed, near = frac(travel), rows = 15
        func height(_ wx: Double, _ wz: Double) -> Double {
            let side = max(0, abs(wx) - 1.2)
            return side * (0.5 + 0.35 * Turn.sine(wz * 0.09 + wx * 0.17) + 0.25 * Turn.sine(wz * 0.23 - wx * 0.4)) * (0.6 + 0.8 * swell)
        }
        func at(_ xi: Int, _ k: Int) -> (Double, Double, Double)? {
            let z = Double(k) + 1 - near
            guard z > 0.3 else { return nil }
            let wx = Double(xi) * 0.55, wz = Double(k) + 1 + travel.rounded(.down)
            return (cx + wx / z * w * 0.42, horizon + (1.1 - height(wx, wz)) / z * min(h, w * 0.7) * 0.42, max(0, 1 - z / Double(rows + 1)))
        }
        for k in 0..<rows {
            for xi in -11..<11 {
                guard let a = at(xi, k), let b = at(xi + 1, k), a.1 < Double(r.maxY) || b.1 < Double(r.maxY) else { continue }
                c.line(a.0, min(a.1, Double(r.maxY + 20)), b.0, b.1, colour, a.2 * 0.8)
                if let n = at(xi, k + 1) { c.line(a.0, a.1, n.0, n.1, colour, a.2 * 0.55) }
            }
        }
    }

    /// Stars coming at you, drawn out into streaks the faster they go.
    func starfield(_ c: DotCanvas, _ r: DotRect, _ colour: DotColor, speed: Double, count: Int, streak: Double = 0.25) {
        var rnd = DotRandom(31)
        let cx = Double(r.x) + Double(r.w) / 2, cy = Double(r.y) + Double(r.h) / 2, scale = Double(max(r.w, r.h)) * 0.5
        for i in 0..<count {
            let sx = rnd.range(-1, 1), sy = rnd.range(-0.7, 0.7), ph = rnd.unit()
            let z = 1.02 - frac(ph + time * speed), z2 = min(1.02, z + speed * streak)
            let a = (1 - z) * (1 - z) * 1.4, k = i % 5 == 0 ? colour : colour.blend(.white, 0.7)
            c.line(cx + sx / z2 * scale * 0.25, cy + sy / z2 * scale * 0.25, cx + sx / z * scale * 0.25, cy + sy / z * scale * 0.25, k, min(1, a))
        }
    }
}
