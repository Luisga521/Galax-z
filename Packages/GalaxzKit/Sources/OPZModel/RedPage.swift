/// What the OP-Z's red page is doing, GROOVE: as Galax-z OS v11 tells it (`Firmware/tell/tell.c`, `$72`).
public struct RedPage: Equatable, Sendable {
    public static let page = 6
    public static let dialNames = ["GROOVE", "RATE", "GATE", "ORDER", "PROGRESSION", "KEY", "LENGTH", "SWING"]
    public static let orders = ["CHORD", "UP", "DOWN", "PLAYED", "RANDOM"]
    public var track = 0, more = false, waiting = false
    /// The step of the groove that plays.
    public var step: Int?
    public var dials = [Int](repeating: 0, count: 8)
    public var notes: [Int] = []

    public init() {}
    public init?(_ p: [UInt8]) {
        guard p.count >= 12, p[0] < 8, p[1] <= 8, p.count == 12 + Int(p[1]) else { return nil }
        track = Int(p[0])
        (more, waiting) = (p[2] & 1 != 0, p[2] & 2 != 0)
        step = p[3] < 16 ? Int(p[3]) : nil
        dials = p[4..<12].map(Int.init)
        notes = p[12...].map(Int.init)
    }

    /// Which of `n` a dial is on: as the OS has it.
    public func which(_ dial: Int, of n: Int) -> Int { (dials[dial] * n) >> 8 }
    /// A dial as a person reads it; the names of grooves and progressions come from outside.
    public func reading(_ k: Int, grooves: [String], progressions: [String]) -> String {
        switch k {
        case 0: let i = which(0, of: grooves.count); return grooves.indices.contains(i) ? grooves[i] : "?"
        case 1: return ["1/4", "1/4T", "1/8", "1/8T", "1/16", "1/16T", "1/32"][(dials[1] * 1796) >> 16]
        case 2: return "\(10 + dials[2] * 85 / 255)%"
        case 3: return Self.orders[which(3, of: 5)]
        case 4: let i = track < 4 ? 0 : which(4, of: progressions.count + 1); return i == 0 ? "OFF" : progressions[i - 1]
        case 5: return ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][which(5, of: 12)]
        case 6: return ["1/2 BAR", "1 BAR", "2 BARS", "4 BARS"][which(6, of: 4)]
        default: return "\(dials[7] * 100 / 255)"
        }
    }
}
