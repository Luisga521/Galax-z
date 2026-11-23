/// A colour of light, 8 bits a channel (sRGB).
public struct DotColor: Equatable, Hashable, Sendable {
    public var r, g, b: UInt8
    @inlinable public init(_ r: UInt8, _ g: UInt8, _ b: UInt8) { (self.r, self.g, self.b) = (r, g, b) }
    @inlinable public init(_ hex: UInt32) { self.init(UInt8(hex >> 16 & 255), UInt8(hex >> 8 & 255), UInt8(hex & 255)) }

    /// `t` of the way to another colour.
    public func mixed(_ o: DotColor, _ t: Double) -> DotColor {
        let k = min(max(t, 0), 1)
        func m(_ a: UInt8, _ b: UInt8) -> UInt8 { UInt8((Double(a) + (Double(b) - Double(a)) * k).rounded()) }
        return DotColor(m(r, o.r), m(g, o.g), m(b, o.b))
    }

    public func scaled(_ k: Double) -> DotColor { DotColor(0, 0, 0).mixed(self, k) }

    /// Hue 0…1, full saturation and value unless given.
    public static func hue(_ h: Double, _ s: Double = 1, _ v: Double = 1) -> DotColor {
        let x = (h - h.rounded(.down)) * 6
        let f = { (n: Double) -> UInt8 in
            let k = (n + x).truncatingRemainder(dividingBy: 6)
            return UInt8((255 * (v - v * s * max(0, min(k, 4 - k, 1)))).rounded())
        }
        return DotColor(f(5), f(3), f(1))
    }

    public static let black = DotColor(0x000000), white = DotColor(0xFFFFFF)
}
