/// A value that moves to its target like a damped spring: never a jump, at any frame rate.
public struct Spring: Sendable {
    public var value: Double
    public var velocity = 0.0
    public var target: Double
    public var stiffness: Double
    public var damping: Double

    public init(_ v: Double, stiffness: Double = 260, damping: Double = 26) {
        (value, target, self.stiffness, self.damping) = (v, v, stiffness, damping)
    }

    /// Move `dt` seconds on (in steps short enough to stay stable after a dropped frame).
    public mutating func step(_ dt: Double) {
        var left = min(dt, 0.1)
        while left > 0 {
            let h = min(left, 1.0 / 240)
            velocity += ((target - value) * stiffness - velocity * damping) * h
            value += velocity * h
            left -= h
        }
        if abs(target - value) < 1e-4, abs(velocity) < 1e-3 { value = target; velocity = 0 }
    }

    public mutating func jump(_ v: Double) { (value, target, velocity) = (v, v, 0) }
    public var settled: Bool { value == target && velocity == 0 }
}

/// Something that lights at once and goes out with time.
public struct Flash: Sendable {
    public var level = 0.0
    public var life: Double
    public init(life: Double) { self.life = life }
    public mutating func hit(_ v: Double) { level = max(level, v) }
    public mutating func step(_ dt: Double) {
        level -= level * min(1, dt / life)
        if level < 0.002 { level = 0 }
    }
}

/// Numbers that look random and are the same every run.
public struct DotRandom: Sendable {
    private var s: UInt64
    public init(_ seed: UInt64) { s = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }
    public mutating func next() -> UInt64 {
        s ^= s << 13; s ^= s >> 7; s ^= s << 17
        return s
    }
    /// 0 ..< 1
    public mutating func unit() -> Double { Double(next() >> 11) / 9_007_199_254_740_992 }
    public mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * unit() }
}

public enum Ease {
    public static func out(_ t: Double) -> Double { let u = 1 - min(max(t, 0), 1); return 1 - u * u * u }
    public static func inOut(_ t: Double) -> Double { let x = min(max(t, 0), 1); return x * x * (3 - 2 * x) }
}
