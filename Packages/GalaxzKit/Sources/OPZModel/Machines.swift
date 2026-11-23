import Foundation

/// What the OP-Z's pink and teal pages are doing: the tumbler's balls and EUCLID's rings, as Galax-z OS v10 tells them
/// (`Firmware/tell/tell.c`, `$70` and `$71`; `docs/PROTOCOL.md`).
public struct Machines: Equatable, Sendable {
    public struct Ball: Equatable, Sendable {
        public var x, y, vx, vy: Double
        public var note: Int
        /// 1 at a bounce, gone in 0.2 s.
        public var flash: Double
        public init(x: Double, y: Double, vx: Double, vy: Double, note: Int, flash: Double = 0) {
            (self.x, self.y, self.vx, self.vy, self.note, self.flash) = (x, y, vx, vy, note, flash)
        }
    }

    public struct Ring: Equatable, Sendable {
        public var key, steps, pulses, rotation: Int
        public init(key: Int, steps: Int, pulses: Int, rotation: Int) { (self.key, self.steps, self.pulses, self.rotation) = (key, steps, pulses, rotation) }
    }

    public static let dialNames = ["GRAVITY", "BOUNCE", "SPIN", "SCATTER", "STEPS", "PULSES", "ROTATE", "RATE", "GATE", "ACCENT", "CHANCE", "OCTAVES"]
    public static let tumblerPage = 4, euclidPage = 5

    /// The parameter page the OP-Z shows, 0–5 (4 pink, 5 teal), and the track it has selected.
    public var page = 0, track = 0
    /// Tracks with balls, and with EUCLID notes: a bit each.
    public var tumbling: UInt8 = 0, latched: UInt8 = 0
    /// EUCLID's second layer of dials; it waits for the first step; the drum ring its dials turn.
    public var more = false, waiting = false
    public var pick = 0
    /// The selected track's twelve dials, 0–255, as `dialNames` has them.
    public var dials = [Int](repeating: 0, count: 12)
    public var rings: [Ring] = []
    public var balls: [Ball] = []
    /// How far round the hexagon is, 0 ..< 1, and EUCLID's steps since it started.
    public var turn = 0.0
    public var steps = 0
    /// Counts the `$71`s: where the balls are is new.
    public var told = 0

    public init() {}

    /// Take a message's payload in; false if it is not one of these or not whole.
    public mutating func receive(_ id: UInt8, _ p: [UInt8]) -> Bool {
        func signed(_ b: UInt8) -> Double { Double(Int8(bitPattern: b)) }
        switch id {
        case 0x70 where p.count >= 20 && p[0] == 1 && p[7] <= 8 && p.count == 20 + Int(p[7]) * 4:
            if Int(p[2]) != track { balls = [] }
            page = Int(p[1])
            track = Int(min(p[2], 15))
            (tumbling, latched) = (p[3], p[4])
            more = p[5] & 1 != 0
            waiting = p[5] & 2 != 0
            pick = Int(p[6])
            dials = p[8..<20].map(Int.init)
            rings = (0..<Int(p[7])).map { i in
                let r = p[(20 + i * 4)..<(24 + i * 4)].map(Int.init), n = max(1, min(16, r[1]))
                return Ring(key: r[0], steps: n, pulses: min(r[2], n), rotation: r[3] % n)
            }
            if tumbling >> min(track, 7) & 1 == 0 || track > 7 { balls = [] }
        case 0x71 where p.count >= 8 && p[1] <= 8 && p.count == 8 + Int(p[1]) * 6:
            guard Int(p[0]) == track else { return true }           // of the track before
            turn = Double(Int(p[2]) | Int(p[3]) << 8) / 65536
            steps = (0..<4).reduce(0) { $0 | Int(p[4 + $1]) << (8 * $1) }
            balls = (0..<Int(p[1])).map { i in
                let b = Array(p[(8 + i * 6)..<(14 + i * 6)])
                return Ball(x: signed(b[0]) / 128, y: signed(b[1]) / 128, vx: signed(b[2]) / 16, vy: signed(b[3]) / 16, note: Int(b[4]), flash: Double(b[5]) / 255)
            }
            told &+= 1
        default:
            return false
        }
        return true
    }

    /// As they are sent, for the demo and the pretend OP-Z.
    public var messages: [[UInt8]] {
        func byte(_ v: Double) -> UInt8 { UInt8(bitPattern: Int8(max(-127, min(127, v.rounded())))) }
        var a: [UInt8] = [1, UInt8(page), UInt8(track), tumbling, latched, (more ? 1 : 0) | (waiting ? 2 : 0), UInt8(pick), UInt8(rings.count)]
        a += dials.map { UInt8(max(0, min(255, $0))) }
        for r in rings { a += [UInt8(r.key), UInt8(r.steps), UInt8(r.pulses), UInt8(r.rotation)] }
        let t = Int((turn - turn.rounded(.down)) * 65536) & 0xFFFF
        var b: [UInt8] = [UInt8(track), UInt8(balls.count), UInt8(t & 255), UInt8(t >> 8)] + (0..<4).map { UInt8(steps >> (8 * $0) & 255) }
        for k in balls { b += [byte(k.x * 128), byte(k.y * 128), byte(k.vx * 16), byte(k.vy * 16), UInt8(k.note & 127), UInt8(max(0, min(255, k.flash * 255)))] }
        return [a, b]
    }

    /// Whether step `i` of `n` sounds, with `k` pulses as even as they go, turned by `rotation` (the OS's own `is_pulse`).
    public static func isPulse(_ i: Int, _ n: Int, _ k: Int, _ rotation: Int) -> Bool { n > 0 && ((i + rotation) % n) * k % n < k }

    /// A melodic track's ring, from its dials (the OS's `e_steps`, `e_pulses`, `e_rot`).
    public var ring: Ring {
        let n = 2 + ((dials[4] * 3852) >> 16)
        return Ring(key: 0, steps: n, pulses: min(n, 1 + ((dials[5] * n) >> 8)), rotation: min(n - 1, (dials[6] * n) >> 8))
    }

    /// A dial as a person reads it.
    public func reading(_ k: Int) -> String {
        let r = track < 4 && rings.indices.contains(pick) ? rings[pick] : ring
        switch k {
        case 4: return "\(r.steps)"
        case 5: return "\(r.pulses)"
        case 6: return "\(r.rotation)"
        case 7: return ["1/4", "1/4T", "1/8", "1/8T", "1/16", "1/16T", "1/32"][(dials[7] * 1796) >> 16]
        case 10: return "\(dials[10] * 100 / 255)%"
        case 11: return "\((dials[11] * 1025) >> 16)"
        default: return "\(dials[k])"
        }
    }

    /// How far a dial is turned, 0–1 (a drum ring's are its own).
    public func turned(_ k: Int) -> Double {
        guard track < 4, (4...6).contains(k) else { return Double(dials[k]) / 255 }
        guard rings.indices.contains(pick) else { return 0 }
        let r = rings[pick]
        return k == 4 ? Double(r.steps - 2) / 14 : Double(k == 5 ? r.pulses - 1 : r.rotation) / Double(max(1, r.steps - 1))
    }
}

/// The tumbler's physics between two tellings: the OS's (`Firmware/pages/pages.c`), in floating point, 256 steps a second, without its
/// scatter (which is chance, and the next telling has it).
public struct Tombola: Equatable, Sendable {
    public static let wall = 0.86, radius = 0.075
    public var balls: [Machines.Ball] = []
    public var turn = 0.0
    private var left = 0.0

    public init() {}

    public mutating func step(_ dt: Double, dials: [Int], bounced: (Machines.Ball, Double) -> Void = { _, _ in }) {
        left += min(max(dt, 0), 0.1)
        while left >= 1.0 / 256 {
            left -= 1.0 / 256
            once(gravity: Double(dials[0]) / 255, bounce: Double(dials[1]) / 255, spin: Double(dials[2]) / 255, bounced)
        }
    }

    private mutating func once(gravity: Double, bounce: Double, spin: Double, _ bounced: (Machines.Ball, Double) -> Void) {
        let h = 1.0 / 256, e = 0.3 + 0.62 * bounce, w = 2.2 * spin, reach = Self.wall * 0.86602540378 - Self.radius
        turn += w * h / (2 * .pi)
        turn -= turn.rounded(.down)
        for i in balls.indices {
            var b = balls[i]
            b.vy += (1.5 + 10 * gravity) * h
            b.x += b.vx * h
            b.y += b.vy * h
            b.flash = max(0, b.flash - h / 0.2)
            for k in 0..<6 {
                let a = (turn + 1.0 / 12 + Double(k) / 6) * 2 * .pi
                let ox = cos(a), oy = sin(a), pen = b.x * ox + b.y * oy - reach
                guard pen > 0 else { continue }
                let nx = -ox, ny = -oy, cx = b.x + Self.radius * ox, cy = b.y + Self.radius * oy
                let wvx = -w * cy, wvy = w * cx, rvx = b.vx - wvx, rvy = b.vy - wvy, vn = rvx * nx + rvy * ny
                b.x += pen * nx
                b.y += pen * ny
                guard vn < 0 else { continue }
                if -vn > 0.35 {
                    let x = rvx - vn * (1 + e) * nx, y = rvy - vn * (1 + e) * ny
                    let tx = -ny, ty = nx, vt = (x * tx + y * ty) * 0.88, out = x * nx + y * ny
                    b.vx = wvx + out * nx + vt * tx
                    b.vy = wvy + out * ny + vt * ty
                    if b.flash < 0.9 { bounced(b, -vn) }
                    b.flash = 1
                } else {
                    b.vx = wvx + (rvx - vn * nx) * 0.998
                    b.vy = wvy + (rvy - vn * ny) * 0.998
                }
            }
            let speed = (b.vx * b.vx + b.vy * b.vy).squareRoot()
            if speed > 5 { b.vx *= 5 / speed; b.vy *= 5 / speed }
            balls[i] = b
        }
        for i in balls.indices.dropLast() { for j in (i + 1)..<balls.count {
            let dx = balls[j].x - balls[i].x, dy = balls[j].y - balls[i].y, d = (dx * dx + dy * dy).squareRoot()
            guard d < 2 * Self.radius, d > 1e-4 else { continue }
            let nx = dx / d, ny = dy / d, apart = (2 * Self.radius - d) / 2
            balls[i].x -= apart * nx; balls[i].y -= apart * ny
            balls[j].x += apart * nx; balls[j].y += apart * ny
            let vn = (balls[j].vx - balls[i].vx) * nx + (balls[j].vy - balls[i].vy) * ny
            guard vn < 0 else { continue }
            let imp = -(1 + e * 0.9) * vn / 2
            balls[i].vx -= imp * nx; balls[i].vy -= imp * ny
            balls[j].vx += imp * nx; balls[j].vy += imp * ny
        } }
    }
}
