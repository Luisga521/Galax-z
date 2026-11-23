/// A matrix of lights. Screens draw into it, one value a dot; whatever shows it (Metal here, anything elsewhere) makes
/// each a round light. No frameworks: it is the same on every platform.
///
/// Coordinates are dots, (0, 0) at the top left; drawing outside is ignored. Alpha is mixed over what is there.
public final class DotCanvas {
    // (unchecked: a canvas is drawn on by one thread, and the check costs more than a dot)
    @exclusivity(unchecked) public private(set) var width: Int
    @exclusivity(unchecked) public private(set) var height: Int
    /// RGBA, R in the lowest byte.
    @exclusivity(unchecked) public private(set) var dots: UnsafeMutablePointer<UInt32>
    /// What drawing is limited to.
    @exclusivity(unchecked) public private(set) var clip: DotRect

    public init(width: Int, height: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
        dots = .allocate(capacity: self.width * self.height)
        dots.initialize(repeating: 0, count: self.width * self.height)
        clip = DotRect(0, 0, self.width, self.height)
    }

    deinit { dots.deallocate() }

    public var count: Int { width * height }

    public func resize(_ w: Int, _ h: Int) {
        guard w != width || h != height, w > 0, h > 0 else { return }
        dots.deallocate()
        (width, height) = (w, h)
        dots = .allocate(capacity: w * h)
        dots.initialize(repeating: 0, count: w * h)
        clip = DotRect(0, 0, w, h)
    }

    public func clear() { dots.update(repeating: 0, count: width * height) }

    /// Draw only inside `r` (and inside what is already the limit) while `body` runs.
    public func clipped(_ r: DotRect, _ body: () -> Void) {
        let before = clip
        clip = before.intersection(r)
        body()
        clip = before
    }

    public subscript(x: Int, y: Int) -> DotColor {
        guard x >= 0, y >= 0, x < width, y < height else { return .black }
        let v = dots[y &* width &+ x]
        return DotColor(UInt8(v & 255), UInt8(v >> 8 & 255), UInt8(v >> 16 & 255))
    }

    /// Mix a colour over a dot.
    @inline(__always)
    public func set(_ x: Int, _ y: Int, _ c: DotColor, _ alpha: Double = 1) {
        guard x >= clip.x, y >= clip.y, x < clip.maxX, y < clip.maxY, alpha > 0 else { return }
        let i = y &* width &+ x
        if alpha >= 1 {
            dots[i] = UInt32(c.r) | UInt32(c.g) << 8 | UInt32(c.b) << 16 | 0xFF00_0000
            return
        }
        let a = Int(alpha * 256), v = dots[i]
        let r = Int(v & 255), g = Int(v >> 8 & 255), b = Int(v >> 16 & 255)
        dots[i] = UInt32(r &+ ((Int(c.r) &- r) &* a) >> 8) | UInt32(g &+ ((Int(c.g) &- g) &* a) >> 8) << 8
            | UInt32(b &+ ((Int(c.b) &- b) &* a) >> 8) << 16 | 0xFF00_0000
    }

    /// Add light to a dot.
    @inline(__always)
    public func add(_ x: Int, _ y: Int, _ c: DotColor, _ amount: Double = 1) {
        guard x >= clip.x, y >= clip.y, x < clip.maxX, y < clip.maxY, amount > 0 else { return }
        let i = y &* width &+ x, a = Int(min(amount, 1) * 256), v = dots[i]
        let r = min(255, Int(v & 255) &+ (Int(c.r) &* a) >> 8), g = min(255, Int(v >> 8 & 255) &+ (Int(c.g) &* a) >> 8)
        let b = min(255, Int(v >> 16 & 255) &+ (Int(c.b) &* a) >> 8)
        dots[i] = UInt32(r) | UInt32(g) << 8 | UInt32(b) << 16 | 0xFF00_0000
    }

    /// Add light between dots: shared out over the four nearest, so slow motion is smooth.
    public func glow(_ x: Double, _ y: Double, _ c: DotColor, _ amount: Double = 1) {
        guard amount > 0, abs(x) < 1e6, abs(y) < 1e6 else { return }       // also what is not a number
        let fx = x.rounded(.down), fy = y.rounded(.down), ix = Int(fx), iy = Int(fy), u = x - fx, v = y - fy
        add(ix, iy, c, amount * (1 - u) * (1 - v))
        add(ix + 1, iy, c, amount * u * (1 - v))
        add(ix, iy + 1, c, amount * (1 - u) * v)
        add(ix + 1, iy + 1, c, amount * u * v)
    }

    // MARK: shapes

    public func fill(_ r: DotRect, _ c: DotColor, _ alpha: Double = 1) {
        let q = r.intersection(clip)
        guard q.w > 0, q.h > 0, alpha > 0 else { return }
        for y in q.y..<q.maxY { for x in q.x..<q.maxX { set(x, y, c, alpha) } }
    }

    /// A filled rectangle with its corner dots left out (radius 1) or rounded.
    public func pill(_ r: DotRect, _ c: DotColor, _ alpha: Double = 1, radius: Int = 1) {
        guard r.w > 0, r.h > 0 else { return }
        let k = min(radius, r.w / 2, r.h / 2), first = max(0, clip.y - r.y), last = min(r.h, clip.maxY - r.y)
        guard first < last else { return }
        for j in first..<last {
            let d = min(j, r.h - 1 - j)
            let cut = d < k ? k - Int((Double(k * k) - Double((k - d) * (k - d)) * 0.8).squareRoot().rounded()) : 0
            fill(DotRect(r.x + cut, r.y + j, r.w - 2 * cut, 1), c, alpha)
        }
    }

    public func frame(_ r: DotRect, _ c: DotColor, _ alpha: Double = 1, radius: Int = 1) {
        guard r.w > 1, r.h > 1 else { return }
        for x in r.x + radius..<max(r.x + radius, r.maxX - radius) { set(x, r.y, c, alpha); set(x, r.maxY - 1, c, alpha) }
        for y in r.y + radius..<max(r.y + radius, r.maxY - radius) { set(r.x, y, c, alpha); set(r.maxX - 1, y, c, alpha) }
        guard radius > 1 else { return }
        // round corners
        for (cx, cy, sx, sy) in [(r.x, r.y, 1, 1), (r.maxX - 1, r.y, -1, 1), (r.x, r.maxY - 1, 1, -1), (r.maxX - 1, r.maxY - 1, -1, -1)] {
            for k in 1..<radius { set(cx + sx * k, cy + sy * (radius - k), c, alpha) }
        }
    }

    /// A horizontal line, every `step`th dot.
    public func rule(_ x: Int, _ y: Int, _ w: Int, _ c: DotColor, _ alpha: Double = 1, step: Int = 1) {
        for i in stride(from: 0, to: max(0, w), by: max(1, step)) { set(x + i, y, c, alpha) }
    }

    public func column(_ x: Int, _ y: Int, _ h: Int, _ c: DotColor, _ alpha: Double = 1, step: Int = 1) {
        for i in stride(from: 0, to: max(0, h), by: max(1, step)) { set(x, y + i, c, alpha) }
    }

    /// A line of light between two points (smooth ends).
    public func line(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ c: DotColor, _ amount: Double = 1) {
        let dx = x1 - x0, dy = y1 - y0, n = max(abs(dx), abs(dy))
        guard n > 0, n < 20_000 else { return glow(x0, y0, c, amount) }
        let steps = Int(n.rounded(.up))
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            glow(x0 + dx * t, y0 + dy * t, c, amount)
        }
    }

    public func disc(_ cx: Double, _ cy: Double, _ r: Double, _ c: DotColor, _ amount: Double = 1) {
        guard r > 0, r < 4096, abs(cx) < 1e6, abs(cy) < 1e6 else { return }
        for y in Int((cy - r - 1).rounded(.down))...Int((cy + r + 1).rounded(.up)) {
            for x in Int((cx - r - 1).rounded(.down))...Int((cx + r + 1).rounded(.up)) {
                let dx = Double(x) - cx, dy = Double(y) - cy
                let cover = min(1, max(0, r + 0.5 - (dx * dx + dy * dy).squareRoot()))
                if cover > 0 { add(x, y, c, amount * cover) }
            }
        }
    }

    /// Part of a circle's line; angles in turns, 0 at the top, clockwise.
    public func arc(_ cx: Double, _ cy: Double, _ r: Double, from a0: Double = 0, to a1: Double = 1, _ c: DotColor,
                    _ amount: Double = 1, squash: Double = 1, dash: Int = 1) {
        guard r > 0.2, r < 1e5, a1 > a0, a1 - a0 < 1e4 else { return }
        let n = max(4, Int(r * 6.2832 * (a1 - a0) * 1.1))
        for i in stride(from: 0, through: n, by: max(1, dash)) {
            let t = Turn.of(a0 + (a1 - a0) * Double(i) / Double(n))
            glow(cx + t.x * r, cy + t.y * r * squash, c, amount * 0.72)
        }
    }

    // MARK: text

    @discardableResult
    public func text(_ s: String, _ x: Int, _ y: Int, _ c: DotColor, _ alpha: Double = 1, font: DotFont = .small, align: DotAlign = .left) -> Int {
        let w = font.width(s)
        var at = switch align { case .left: x; case .center: x - w / 2; case .right: x - w }
        for ch in s.unicodeScalars {
            let g = font.glyph(ch)
            if alpha > 0 { for d in g.dots { set(at + d.x, y + d.y, c, alpha * d.a) } }
            at += g.advance
        }
        return w
    }
}

/// Sine and cosine by turn, 0 at the top, clockwise: a table, so thousands a frame cost nothing.
public enum Turn {
    static let n = 4096
    static let table: [(Double, Double)] = (0..<n).map { let a = Double($0) / Double(n) * 2 * 3.141592653589793; return (sin(a), -cos(a)) }
    @inline(__always) public static func of(_ t: Double) -> (x: Double, y: Double) {
        abs(t) < 1e12 ? table[Int((t * Double(n)).rounded(.down)) & (n - 1)] : (0, -1)
    }
    /// sin(2π t)
    @inline(__always) public static func sine(_ t: Double) -> Double { of(t).x }

    // Taylor series: no Foundation needed.
    private static func sin(_ a: Double) -> Double {
        var x = a
        while x > 3.141592653589793 { x -= 6.283185307179586 }
        var term = x, sum = x
        for k in 1..<14 { term *= -x * x / Double((2 * k) * (2 * k + 1)); sum += term }
        return sum
    }
    private static func cos(_ a: Double) -> Double { sin(a + 1.5707963267948966) }
}

public struct DotRect: Equatable, Hashable, Sendable {
    public var x, y, w, h: Int
    @inlinable public init(_ x: Int, _ y: Int, _ w: Int, _ h: Int) { (self.x, self.y, self.w, self.h) = (x, y, w, h) }
    @inlinable public var maxX: Int { x + w }
    @inlinable public var maxY: Int { y + h }
    public var midX: Int { x + w / 2 }
    public var midY: Int { y + h / 2 }
    public func intersection(_ o: DotRect) -> DotRect {
        let x0 = max(x, o.x), y0 = max(y, o.y)
        return DotRect(x0, y0, max(0, min(maxX, o.maxX) - x0), max(0, min(maxY, o.maxY) - y0))
    }
    public func inset(_ dx: Int, _ dy: Int) -> DotRect { DotRect(x + dx, y + dy, max(0, w - 2 * dx), max(0, h - 2 * dy)) }
    public func contains(_ px: Int, _ py: Int) -> Bool { px >= x && py >= y && px < maxX && py < maxY }
}

public enum DotAlign: Sendable { case left, center, right }
