/// The figures of Galax-z's load meter (OS v8 on, `Firmware/meter/meter.c`), sent as notes by SHIFT + SCREEN: two a byte,
/// velocity 1–16 a nibble, the note 24 + a count of 0–63.
public struct LoadReport: Equatable, Sendable {
    public static let size = 40
    /// The OS's line for the instruments, and a whole audio block, in cycles.
    public static let line = 265_000, block = 580_499

    public let seconds: Double
    public let instrumentsMean, instrumentsTop, totalMean, totalTop: Int
    public let notesCut, notesTop, longestFrame: Int

    public init?(_ b: [UInt8]) {
        guard b.count == Self.size, Array(b[..<4]) == Array("GZL1".utf8),
              b[..<(Self.size - 1)].reduce(UInt8(0), &+) == b[Self.size - 1] else { return nil }
        let u = { (i: Int) -> Int in (0..<4).reduce(0) { $0 | Int(b[4 + i * 4 + $1]) << (8 * $1) } }
        seconds = Double(u(0)) / 10
        (instrumentsMean, instrumentsTop, totalMean, totalTop) = (u(1), u(2), u(3), u(4))
        (notesCut, notesTop, longestFrame) = (u(5), u(6), u(7))
    }

    /// Notes as they come, put together; `finished` is given the report when its last one is in.
    public struct Collector: Sendable {
        private var nibbles: [UInt8] = []
        private var last = -Double.infinity
        public init() {}

        /// True if the note is (or could be) a report's, so it is not music.
        public mutating func note(_ note: Int, velocity: Int, at time: Double) -> (taken: Bool, report: LoadReport?) {
            if time - last > 0.5 { nibbles = [] }
            guard (1...16).contains(velocity), note - 24 == nibbles.count & 63 else {
                nibbles = []
                return (false, nil)
            }
            nibbles.append(UInt8(velocity - 1))
            last = time
            guard nibbles.count == LoadReport.size * 2 else { return (nibbles.count > 3, nil) }
            let bytes = stride(from: 0, to: nibbles.count, by: 2).map { nibbles[$0] << 4 | nibbles[$0 + 1] }
            nibbles = []
            return (true, LoadReport(bytes))
        }
    }
}
