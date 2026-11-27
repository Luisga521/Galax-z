import DotKit

/// What SKY and SHOW have and the other pages had not: depth. A faint field of stars behind every page, tinted by the tracks and
/// breathing with the beat, a soft light of the track in hand behind the page's middle, and sparks thrown up by every note.
/// Drawn first, under the page, so whatever a page fills (pads, panels, text) stays on top and stays readable.
/// Off in Settings › Screen (STARS), and never on SKY and SHOW, which are made of it already.
struct Ambience {
    struct Star { var x, y, size, phase, rate: Double; var track: Int }
    struct Spark { var x, y, vx, vy, age, life: Double; var track: Int }

    private(set) var stars: [Star] = []
    private(set) var sparks: [Spark] = []
    private var made = (w: 0, h: 0)
    private var rnd = DotRandom(1977)
    /// The time the field twinkles at: it runs while something plays, and stands still otherwise, so a still page is still.
    private(set) var clock = 0.0

    /// Stars for a body this size: about one in 40 dots, the same field every time for the same size.
    mutating func fit(_ w: Int, _ h: Int) {
        guard made != (w, h) else { return }
        made = (w, h)
        var r = DotRandom(UInt64(w * 7919 + h))
        stars = (0..<max(24, w * h / 40)).map { _ in
            let size = r.unit()
            return Star(x: r.unit(), y: r.unit(), size: size * size, phase: r.unit(), rate: 0.15 + 0.5 * r.unit(), track: Int(r.unit() * 16))
        }
    }

    /// A note: a few sparks up from somewhere along the bottom of the page, in the track's colour, more for a harder hit.
    mutating func hit(_ t: Int, _ velocity: Double) {
        let n = 2 + Int(velocity * 4)
        let home = (Double(t) + 0.5) / 16
        for _ in 0..<n {
            let a = rnd.range(-0.35, 0.35), speed = 0.18 + 0.32 * velocity * rnd.range(0.6, 1)
            sparks.append(Spark(x: home + rnd.range(-0.02, 0.02), y: 1, vx: a * speed * 0.5, vy: -speed, age: 0, life: 0.7 + 0.6 * velocity * rnd.unit(), track: t))
        }
        if sparks.count > 240 { sparks.removeFirst(sparks.count - 240) }
    }

    mutating func step(_ dt: Double, playing: Bool) {
        if playing { clock += dt }
        for i in sparks.indices {
            sparks[i].age += dt
            sparks[i].x += sparks[i].vx * dt
            sparks[i].y += sparks[i].vy * dt
            sparks[i].vy += 0.16 * dt              // they slow as they rise
            sparks[i].vx *= max(0, 1 - dt * 0.8)
        }
        sparks.removeAll { $0.age > $0.life }
    }

    var quiet: Bool { sparks.isEmpty }
}

extension Stage {
    /// Under the page: the field, the light of the track in hand, the sparks.
    func ambience(_ c: DotCanvas, _ r: DotRect, _ dt: Double) {
        ambient.step(dt, playing: playhead.playing)
        guard ambienceOn, page != .sky, page != .show, r.w > 8, r.h > 8 else { return }
        ambient.fit(r.w, r.h)
        let t = ambient.clock, beat = pulse.level, colour = Palette.track(track)
        let x0 = Double(r.x), y0 = Double(r.y), w = Double(r.w), h = Double(r.h)

        // the track in hand, a soft light behind the middle of the page, a little brighter on its hits
        let cx = x0 + w * 0.5, cy = y0 + h * 0.48, rx = w * 0.55, ry = h * 0.6
        let light = 0.07 + 0.08 * hitFlashes[track].level
        var y = r.y
        while y < r.maxY {
            let v = (Double(y) + 0.5 - cy) / ry, vv = v * v
            if vv < 1 {
                var x = r.x
                while x < r.maxX {
                    let u = (Double(x) + 0.5 - cx) / rx, d = u * u + vv
                    if d < 1 { let f = 1 - d; c.add(x, y, colour, light * f * f) }
                    x += 1
                }
            }
            y += 1
        }

        // the field: dim, twinkling slowly, tinted by the tracks, brighter on the beat and where a track sounds
        for s in ambient.stars {
            let tw = 0.55 + 0.45 * Turn.sine(t * s.rate + s.phase)
            let lit = levels[s.track].level
            let tint = Palette.ink.mixed(Palette.track(s.track), 0.35 + 0.5 * lit)
            let a = (0.1 + 0.4 * s.size) * tw + 0.12 * beat * s.size + 0.45 * lit * s.size
            let drift = (s.x + t * 0.004 * (0.3 + s.size)).truncatingRemainder(dividingBy: 1)
            c.glow(x0 + drift * (w - 1), y0 + s.y * (h - 1), tint, min(0.75, a))
        }

        // the sparks, each with a short tail
        for s in ambient.sparks {
            let f = s.age / s.life, fade = (1 - f) * (1 - f)
            let spark = Palette.track(s.track)
            for tail in 0..<4 {
                let back = Double(tail) * 0.012
                c.glow(x0 + (s.x - s.vx * back) * (w - 1), y0 + (s.y - s.vy * back) * (h - 1), tail == 0 ? Palette.ink.mixed(spark, 0.5) : spark,
                       0.55 * fade * (1 - Double(tail) / 4))
            }
        }
    }
}
