import Foundation

/// Where the OP-Z's 51 LEDs sit (Firmware/galaxy/layout.json): x 0 (left) … 1 (right) along the keys, y 0 (the
/// dial LEDs) … 1 (the bottom row), and the true-proportion distance from the middle.
public struct LEDLayout: Sendable {
    public struct Point: Sendable { public let x, y, aspectY: Double }   // aspectY: y in x's units (true shape)
    public let points: [Int: Point]

    public static let ledCount = 53

    public init(pixels: [Int: (Double, Double)]) {
        let xs = pixels.values.map(\.0), ys = pixels.values.map(\.1)
        let x0 = xs.min() ?? 0, x1 = xs.max() ?? 1, y0 = ys.min() ?? 0, y1 = ys.max() ?? 1
        let w = max(x1 - x0, 1), h = max(y1 - y0, 1)
        points = pixels.mapValues { Point(x: ($0.0 - x0) / w, y: ($0.1 - y0) / h, aspectY: ($0.1 - y0) / w) }
    }

    public static func load(_ url: URL) throws -> LEDLayout {
        struct File: Decodable { let leds: [String: [Double]] }
        let f = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        return LEDLayout(pixels: Dictionary(uniqueKeysWithValues: f.leds.compactMap { k, v in
            Int(k).map { ($0, (v[0], v[1])) } }))
    }

    public static func bundled() throws -> LEDLayout {
        guard let url = Catalog.bundledRoot?.appending(path: "layout.json") else {
            throw PatchError(description: "no LED layout in the app")
        }
        return try load(url)
    }
}

/// One LED's colour, R G B W, 0…1.
public typealias RGBW = SIMD4<Double>

/// What moves: for each LED and time, how lit it is and where in the palette it sits. No colour of its own, so every
/// pattern takes every style.
public struct LEDPattern: Sendable, Identifiable {
    public struct Spot: Sendable {
        public let led: Int
        public let x, y: Double        // 0…1 along the keys, 0…1 from the encoder LEDs down to the bottom row
        public let r, theta: Double    // from the middle of the keys, true proportions (r 0…1)
        public let seed: Double        // 0…1, fixed per LED: for the stars
        /// The key's column (0…16) and row (0 the encoders, 1 the top keys, 2 the middle, 3 the bottom).
        public var column: Int { Int((x * 16).rounded()) }
        public var row: Int { y < 0.16 ? 0 : y < 0.5 ? 1 : y < 0.83 ? 2 : 3 }
    }
    public struct Light: Sendable { let level, tone: Double }   // 0…1 lit, 0…1 along the style's colours

    public let id, name, blurb: String
    public var isTest = false                                   // not a show: no fade, no style, plain white
    let draw: @Sendable (Spot, Double) -> Light                 // at time u, 0…1

    public static func named(_ id: String) -> LEDPattern? { all.first { $0.id == id } }

    static func spots(_ layout: LEDLayout) -> [Int: Spot] {
        let ay = layout.points.values.map(\.aspectY)
        let cx = 0.5, cy = ((ay.min() ?? 0) + (ay.max() ?? 0)) / 2
        let reach = layout.points.values.map { hypot($0.x - cx, $0.aspectY - cy) }.max() ?? 1
        return Dictionary(uniqueKeysWithValues: layout.points.map { i, p in
            (i, Spot(led: i, x: p.x, y: p.y, r: hypot(p.x - cx, p.aspectY - cy) / reach,
                     theta: atan2(-(p.aspectY - cy), p.x - cx), seed: hash(i)))
        })
    }

    static func hash(_ i: Int) -> Double {
        var x = UInt32(truncatingIfNeeded: i &* 2_654_435_761 &+ 0x9E37)
        x ^= x >> 15; x = x &* 0x2C1B_3C6D; x ^= x >> 12
        return Double(x % 10_000) / 10_000
    }
}

/// What a pattern looks like: three colours it runs through, or black and white, and how strong each layer is.
public struct LEDStyle: Codable, Equatable, Hashable, Sendable {
    public var colors: [UInt32]          // three, 0xRRGGBB
    public var mono: Bool                // black and white: the colour LEDs use their white too
    public var colorOpacity: Double      // the top row and the encoders
    public var bedOpacity: Double        // the two white rows

    public init(_ a: UInt32, _ b: UInt32, _ c: UInt32, mono: Bool = false, colorOpacity: Double = 1, bedOpacity: Double = 1) {
        colors = [a, b, c]; self.mono = mono; self.colorOpacity = colorOpacity; self.bedOpacity = bedOpacity
    }

    func color(_ tone: Double) -> RGBW {
        let c = (0..<3).map { i -> RGBW in
            let v = i < colors.count ? colors[i] : 0xFFFFFF
            return RGBW(Double(v >> 16 & 0xFF), Double(v >> 8 & 0xFF), Double(v & 0xFF), 0) / 255
        }
        let t = min(1, max(0, tone)) * 2
        return t < 1 ? mix(c[0], c[1], t) : mix(c[1], c[2], t - 1)
    }
}

/// A boot animation: a pattern in a style. 240 frames for the OP-Z's keys, ending in an even fade; the OP-Z plays them
/// right after it starts, paced by its clock (Firmware/galaxy/galaxy_boot.S). Codable, so your own can be kept.
public struct LEDAnimation: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id, name, pattern: String
    public var style: LEDStyle

    public init(id: String, name: String, pattern: String, style: LEDStyle) {
        self.id = id; self.name = name; self.pattern = pattern; self.style = style
    }

    public var blurb: String { LEDPattern.named(pattern)?.blurb ?? "" }
    public var isTest: Bool { LEDPattern.named(pattern)?.isTest ?? false }

    public static let frameCount = 240       // 4 s at 60 a second
    /// Every LED fades together over this last stretch; the last frame is dark.
    static let fadeFrom = 0.82, fadeTo = 0.99

    /// Which LEDs have real colour (seen on the unit 2026-11-21): the top row (TRACK and the 16 steps) and the four
    /// encoder LEDs. The two lower rows are a bed of white. TRACK is 44 by guess (the Key check settles it), so it gets
    /// its colour and the white: it lights either way.
    public static let rgb = Set(0...15).union(40...43), trackGuess = 44

    /// Full or off: a steep step, with a short ramp so motion is not jagged.
    static func contrast(_ level: Double) -> Double { smooth(0.34, 0.56, level) }

    /// One LED at one moment: the pattern's light in the style, on the LED that is there (colour on the RGB ones; plain
    /// white, W only, as TE's own code whitens the keyboard, on the rest).
    static func shown(_ l: LEDPattern.Light, _ style: LEDStyle, led: Int) -> RGBW {
        let lit = contrast(l.level), c = style.color(l.tone)
        let bed = RGBW(0, 0, 0, lit * style.bedOpacity)
        let top = (style.mono ? RGBW(0, 0, 0, 1) : c) * (lit * style.colorOpacity)
        if rgb.contains(led) { return top }
        return led == trackGuess && !style.mono ? RGBW(top[0], top[1], top[2], bed[3]) : bed
    }

    public func frames(_ layout: LEDLayout) -> [[RGBW]] {
        guard let p = LEDPattern.named(pattern) else { return Array(repeating: Array(repeating: .zero, count: LEDLayout.ledCount), count: Self.frameCount) }
        let spots = LEDPattern.spots(layout)
        return (0..<Self.frameCount).map { f in
            let u = Double(f) / Double(Self.frameCount - 1)
            let fade = u >= 1 ? 0 : p.isTest ? 1 : 1 - smooth(Self.fadeFrom, Self.fadeTo, u)
            return (0..<LEDLayout.ledCount).map { i in
                guard let s = spots[i], fade > 0 else { return .zero }
                let l = p.draw(s, u)
                return p.isTest ? RGBW(0, 0, 0, l.level) : Self.shown(l, style, led: i) * fade
            }
        }
    }

    /// 240 frames × 53 LEDs × R G B W bytes (gamma 1.6), what galaxy_boot.S plays.
    public func bytes(_ layout: LEDLayout) -> [UInt8] {
        frames(layout).flatMap { $0.flatMap { c in (0..<4).map { UInt8((pow(min(1, max(0, c[$0])), 1.6) * 255).rounded()) } } }
    }
}

func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = min(1, max(0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
}

func mix(_ a: RGBW, _ b: RGBW, _ t: Double) -> RGBW { a + (b - a) * t }

private func gauss(_ d: Double, _ w: Double) -> Double { exp(-(d / w) * (d / w)) }
private func fract(_ v: Double) -> Double { v - v.rounded(.down) }

// MARK: - the patterns

extension LEDPattern {
    public static let all: [LEDPattern] = [galaxy, spiral, comet, aurora, starfield, sunrise, rain, pulse,
                                           scanner, wave, stripes, checker, bars, radar, curtain, snake, keyCheck]

    static let galaxy = LEDPattern(id: "galaxy", name: "Galaxy", blurb: "A bright front sweeps left to right, bands rolling behind it") { s, u in
        let front = -0.15 + 1.35 * smooth(0, 0.55, u), d = s.x - front       // crosses in the first ~2.2 s
        let band = smooth(0, 0.1, -d) * (0.5 + 0.5 * sin(20 * s.x + 3 * s.y - 26 * u)), edge = gauss(d, 0.08)
        return Light(level: max(band, edge), tone: edge > band ? 0 : min(1, max(0.15, -d / 0.8)))
    }
    static let spiral = LEDPattern(id: "spiral", name: "Spiral", blurb: "Two arms open from the middle and spin out") { s, u in
        let radius = 1.25 * (1 - pow(1 - min(1, u * 1.3), 2))
        let arms = pow(0.5 + 0.5 * sin(2 * s.theta + 9 * s.r + 8 * .pi * u), 2)
        let inside = smooth(0, 0.15, radius - s.r) * max(arms, gauss(s.r, 0.16)), edge = gauss(s.r - radius, 0.12)
        return Light(level: max(inside, edge), tone: s.r)
    }
    static let comet = LEDPattern(id: "comet", name: "Comet", blurb: "A comet weaves left to right, its tail behind") { s, u in
        let dx = s.x - (-0.1 + 1.4 * u), dy = s.y - (0.55 + 0.45 * sin(5 * .pi * u))
        let head = exp(-(dx * dx) / 0.006 - (dy * dy) / 0.09), tail = dx < 0 ? exp(dx / 0.3) * exp(-(dy * dy) / 0.12) : 0
        return Light(level: max(head, tail), tone: min(1, max(0, -dx / 0.3)))
    }
    static let aurora = LEDPattern(id: "aurora", name: "Aurora", blurb: "Curtains of light drift across the keys") { s, u in
        Light(level: smooth(0, 0.1, u) * (0.5 + 0.5 * sin(13 * s.x + 2 * s.y - 14 * u + 1.2 * sin(5 * s.x + 6 * u))), tone: s.x)
    }
    static let starfield = LEDPattern(id: "starfield", name: "Starfield", blurb: "Every key a star coming and going at its own pace") { s, u in
        Light(level: pow(max(0, sin(2 * .pi * (u * (2 + 3 * s.seed) + s.seed))), 4), tone: hash(s.led + 100))
    }
    static let sunrise = LEDPattern(id: "sunrise", name: "Sunrise", blurb: "A dome of light grows from the bottom") { s, u in
        let level = 1.4 * min(1, u / 0.78) - hypot((s.x - 0.5) * 1.8, (1 - s.y) * 0.5)
        return Light(level: smooth(0, 0.15, level), tone: min(1, max(0, level)))
    }
    static let rain = LEDPattern(id: "rain", name: "Rain", blurb: "Drops fall down the key columns") { s, u in
        let c = s.column, speed = 1.5 + hash(c) * 1.5
        let behind = fract(u * speed * 1.4 + hash(c + 7)) * 1.6 - 0.3 - s.y  // > 0: the drop has passed this key
        return Light(level: max(behind >= 0 ? exp(-behind / 0.25) : 0, gauss(behind, 0.12)), tone: min(1, max(0, behind / 0.3)))
    }
    static let pulse = LEDPattern(id: "pulse", name: "Pulse", blurb: "A heartbeat: two rings a beat, dark between") { s, u in
        let beat = fract(u * 3.3)
        func ring(_ t: Double) -> Double { t < 0 ? 0 : gauss(s.r - t * 1.9, 0.15) }
        let lub = ring(beat), dub = ring(beat - 0.2)
        return Light(level: max(lub, dub), tone: lub > dub ? 0 : 1)
    }
    static let scanner = LEDPattern(id: "scanner", name: "Scanner", blurb: "A bar of light runs end to end and back") { s, u in
        let t = fract(u * 2.5), d = abs(s.x - (t < 0.5 ? 2 * t : 2 - 2 * t))
        return Light(level: gauss(d, 0.13), tone: d / 0.13)
    }
    static let wave = LEDPattern(id: "wave", name: "Sine wave", blurb: "A sine line rolls across the rows") { s, u in
        Light(level: gauss(s.y - (0.55 + 0.45 * sin(2 * .pi * (1.5 * s.x - 3 * u))), 0.24), tone: s.x)
    }
    static let stripes = LEDPattern(id: "stripes", name: "Stripes", blurb: "Diagonal stripes march to the right") { s, u in
        Light(level: 0.5 + 0.5 * sin(2 * .pi * (4 * s.x + 0.8 * s.y - 5 * u)), tone: fract(2 * s.x + 0.4 * s.y - 2.5 * u))
    }
    static let checker = LEDPattern(id: "checker", name: "Checker", blurb: "Blocks of keys flip on and off in turn") { s, u in
        let on = (s.column / 2 + s.row + Int(u * 9)) % 2 == 0
        return Light(level: on ? 1 : 0, tone: s.x)
    }
    static let bars = LEDPattern(id: "bars", name: "Bars", blurb: "Level bars jump up and down, a column per key") { s, u in
        let c = Double(s.column), h = 0.5 + 0.35 * sin(1.7 * c + 22 * u) + 0.3 * sin(0.6 * c - 13 * u)
        return Light(level: 1 - s.y < h ? 1 : 0, tone: 1 - s.y)
    }
    static let radar = LEDPattern(id: "radar", name: "Radar", blurb: "A beam turns around the middle, its trail fading") { s, u in
        let angle = atan2(0.6 - s.y, (s.x - 0.5) * 2) / (2 * .pi), behind = fract(angle + 3 * u)
        return Light(level: exp(-behind / 0.3), tone: behind / 0.25)
    }
    static let curtain = LEDPattern(id: "curtain", name: "Curtain", blurb: "Opens from the middle, closes, opens again") { s, u in
        let away = abs(s.x - 0.5) * 2
        return Light(level: away > 0.5 - 0.6 * cos(2 * .pi * 2 * u) ? 1 : 0, tone: away)
    }
    static let snake = LEDPattern(id: "snake", name: "Snake", blurb: "A line of light winds through every row") { s, u in
        let at = s.row == 2 ? 3 - s.x : Double(s.row) + s.x                  // left to right, the middle row right to left
        let behind = -0.2 + 5 * u / 0.8 - at
        return Light(level: behind > 0 && behind < 0.9 ? 1 : 0, tone: behind / 0.9)
    }
    /// A test: the seven function keys (LEDs 44–50) one at a time, while the first n step keys count which one it is.
    static let keyCheck = LEDPattern(id: "keycheck", name: "Key check",
        blurb: "A test: one function key at a time; the lit step keys count 1 to 7. Which count is TRACK?", isTest: true) { s, u in
        let n = min(6, Int(u * 7))
        return Light(level: s.led == 44 + n || s.led <= n ? 1 : 0, tone: 0)
    }
}

// MARK: - the library

extension LEDAnimation {
    public static let library: [LEDAnimation] = [
        galaxy, preset("spiral", LEDStyle(0xFFFFFF, 0xB030FF, 0x2060FF)), preset("comet", LEDStyle(0xE0F0FF, 0xFF7A10, 0xA020E0)),
        preset("aurora", LEDStyle(0x20FF90, 0x10C0E0, 0x9020FF)), preset("starfield", LEDStyle(0xFFFFFF, 0x80C0FF, 0x4060FF)),
        preset("sunrise", LEDStyle(0xFF2000, 0xFFA000, 0xFFF0B0)), preset("rain", LEDStyle(0xC0FFD0, 0x20FF50, 0x00A030)),
        preset("pulse", LEDStyle(0xFF001A, 0xFF2060, 0xFF50A0)), preset("scanner", LEDStyle(0xFF1010, 0xFF1010, 0xA00000)),
        preset("wave", LEDStyle(0x00E0FF, 0x4060FF, 0xFF20C0)), preset("stripes", LEDStyle(0xFFD020, 0xFF4020, 0xFF20A0)),
        preset("checker", LEDStyle(0x30FFC0, 0x30A0FF, 0xA040FF)), preset("bars", LEDStyle(0x20FF40, 0xFFD000, 0xFF2010)),
        preset("radar", LEDStyle(0x60FF60, 0x10D040, 0x008030)), preset("curtain", LEDStyle(0xFFFFFF, 0xFF8030, 0xFF1050)),
        preset("snake", LEDStyle(0xFFFFFF, 0x40FF80, 0x10B060)), keyCheck,
    ]
    public static let galaxy = preset("galaxy", LEDStyle(0x80E6FF, 0xFF10B0, 0x2050FF))
    public static let keyCheck = preset("keycheck", LEDStyle(0xFFFFFF, 0xFFFFFF, 0xFFFFFF, mono: true))

    private static func preset(_ id: String, _ style: LEDStyle) -> LEDAnimation {
        LEDAnimation(id: id, name: LEDPattern.named(id)!.name, pattern: id, style: style)
    }
}
