import DotKit
import OPZModel

/// A galaxy, its arms as bright as the tracks, a star thrown out by each note.
struct Sky {
    struct Star { var angle, radius, speed, age, life: Double; var track: Int }
    private(set) var thrown: [Star] = []
    private var rnd = DotRandom(42)

    mutating func hit(_ t: Int, _ velocity: Double) {
        thrown.append(Star(angle: Double(t) / 16 + rnd.range(-0.03, 0.03), radius: 0.06, speed: 0.22 + 0.4 * velocity, age: 0, life: 1.4 + velocity, track: t))
        if thrown.count > 160 { thrown.removeFirst(40) }
    }

    mutating func step(_ dt: Double) {
        for i in thrown.indices {
            thrown[i].age += dt
            thrown[i].radius += thrown[i].speed * dt
            thrown[i].angle += dt * 0.05 / max(0.15, thrown[i].radius)
        }
        thrown.removeAll { $0.age > $0.life }
    }
}

extension Stage {
    func skyPage(_ c: DotCanvas, _ r: DotRect, _ dt: Double) {
        sky.step(dt)
        let cx = Double(r.x) + Double(r.w) / 2, cy = Double(r.y) + Double(r.h) / 2, R = Double(min(r.w * 10 / 16, r.h)) * 0.78
        galaxy(c, cx, cy, R, time, 1)
        for s in sky.thrown {
            let f = s.age / s.life, colour = Palette.track(s.track)
            for tail in 0..<7 {
                let p = Turn.of(s.angle - Double(tail) * 0.004 / max(0.15, s.radius)), rr = (s.radius - Double(tail) * 0.012) * R
                c.glow(cx + p.x * rr, cy + p.y * rr * 0.62, tail == 0 ? .white : colour, (1 - f) * (1 - Double(tail) / 7))
            }
        }
        c.disc(cx, cy, 3 + 5 * pulse.level, Palette.yellow, 0.8)
        // who sounds, round the edge
        for t in 0..<16 where levels[t].level > 0.04 {
            let p = Turn.of(Double(t) / 16)
            c.text(OPZ.trackNames[t].uppercased(), Int(cx + p.x * R * 0.9), Int(cy + p.y * R * 0.6) - 2, Palette.track(t), min(1, levels[t].level * 1.4), font: .tiny, align: .center)
        }
    }

    func galaxy(_ c: DotCanvas, _ cx: Double, _ cy: Double, _ R: Double, _ t: Double, _ amount: Double) {
        var rnd = DotRandom(7)
        // a bright middle
        for _ in 0..<220 {
            let f = rnd.unit(), p = Turn.of(rnd.unit() + t * 0.03), rr = f * f * 0.16
            c.glow(cx + p.x * rr * R, cy + p.y * rr * R * 0.62, Palette.ink.mixed(Palette.yellow, 0.5), amount * (0.9 - 0.6 * f))
        }
        // four arms, turning as one (arms that turn faster inside would wind up into a haze)
        for i in 0..<1500 {
            let arm = i % 4, f = rnd.unit(), rr = 0.05 + 0.95 * f.squareRoot()
            let off = (rnd.unit() + rnd.unit() + rnd.unit() - 1.5) * 0.085 * (1.25 - 0.7 * rr), a = Double(arm) / 4 + rr * 0.62 + off + t * 0.012
            let p = Turn.of(a), phase = rnd.unit(), tw = 0.6 + 0.4 * Turn.sine(t * 0.35 * (0.4 + phase) + phase)
            let track = (arm * 4 + Int(rr * 3.99)) & 15, lit = levels[track].level
            let colour = Palette.ink.mixed(Palette.track(track), 0.45 + 0.55 * lit)
            c.glow(cx + p.x * rr * R, cy + p.y * rr * R * 0.62, colour, min(1, amount * (0.28 + 0.6 * (1 - rr) + 0.6 * lit) * tw))
        }
    }

    /// Darker towards the middle of an oval, with no edge to be seen.
    private func dim(_ c: DotCanvas, _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ most: Double) {
        for y in Int(cy - ry)...Int(cy + ry) {
            for x in Int(cx - rx)...Int(cx + rx) {
                let u = (Double(x) + 0.5 - cx) / rx, v = (Double(y) + 0.5 - cy) / ry, f = min(1, max(0, 1 - (u * u + v * v).squareRoot()) * 1.35)
                c.set(x, y, .black, most * f * f * (3 - 2 * f))
            }
        }
    }

    // MARK: no OP-Z yet

    func connect(_ c: DotCanvas, _ dt: Double) {
        let cx = Double(c.width) / 2, cy = Double(c.height) / 2, amount = 1 - linkFade.value
        let R = Double(min(c.width * 10 / 16, c.height)) * 0.82
        galaxy(c, cx, cy - 8, R, time, amount)
        // a wave going out, looking
        if input.link == .searching {
            for k in 0..<3 {
                let f = (time * 0.28 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                c.arc(cx, cy - 8, f * R, Palette.yellow, (1 - f) * (1 - f) * 0.7 * amount, squash: 0.62)
            }
        }
        // the name, with the galaxy showing through
        let font: DotFont = DotFont.huge.width("GALAX-Z") < c.width - 24 ? .huge : .big
        let w = font.width("GALAX-Z"), x = Int(cx) - w / 2, y = Int(cy) - font.height - 2
        // the galaxy's bright middle, dimmed behind the second A: an oval that feathers out to nothing
        dim(c, cx, cy - 10, Double(font.height) * 1.45, Double(font.height) * 0.95, 0.8)
        c.text("GALAX-Z", x, y, Palette.ink, amount, font: font)
        let line: String = switch input.link {
        case .loading(let n): "READING THE PROJECT · \(n)"
        case .hello: "OP-Z FOUND"
        default: input.linkLine
        }
        let lf: DotFont = DotFont.small.width(line) < c.width - 12 ? .small : .tiny
        c.text(line, Int(cx), Int(cy) + 15, Palette.yellow, amount, font: lf, align: .center)
        if !input.linkHint.isEmpty {
            c.text(input.linkHint, Int(cx), Int(cy) + 30, Palette.ink, 0.6 * amount, font: .tiny, align: .center)
        }
        let buttons = (showsPairing ? [("PAIR", Action.pair)] : []) + [("SETTINGS", .settings)]
        var bx = Int(cx) - (buttons.reduce(-8) { $0 + DotFont.tiny.width($1.0) + 20 }) / 2
        let y2 = c.height - 26
        for (name, a) in buttons {
            let w = DotFont.tiny.width(name) + 12, box = DotRect(bx, y2, w, 13)
            c.fill(box, .black, 0.7)
            c.frame(box, a == .pair ? Palette.yellow : Palette.ink, 0.6 * amount, radius: 2)
            c.text(name, box.midX, box.y + 4, a == .pair ? Palette.yellow : Palette.ink, 0.95 * amount, font: .tiny, align: .center)
            touches.append((box.inset(-3, -5), .action(a)))
            bx += w + 8
        }
    }
}
