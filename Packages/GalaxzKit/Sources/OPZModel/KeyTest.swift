/// Finds keys that double-trigger: the OP-Z's 24 keys send MIDI notes (53–76 at the default octave, F first), so
/// two presses of the same key closer together than any finger can play are a bounce. No firmware involved.
public struct KeyTest: Sendable {
    public static let keys = 24
    public static let defaultFirstNote = 53
    /// Gaps longer than this are ordinary playing and are not kept.
    static let keepGapsUnder = 0.25
    static let logLength = 40

    public struct Key: Sendable, Equatable {
        public var presses = 0
        /// Gaps between one press of this key and the next, under 250 ms, in seconds.
        public var gaps: [Double] = []
        public var fastest: Double? { gaps.min() }
        public func doubles(window: Double) -> Int { gaps.filter { $0 < window }.count }
    }

    public struct Press: Sendable, Equatable, Identifiable {
        public let id: Int
        public let note: Int
        public let time: Double
        /// Since the previous press of the same key, if it was under 250 ms.
        public let gap: Double?
        /// How long the previous press of the same key was held, when its note-off came.
        public let heldBefore: Double?
    }

    /// The double-trigger window in seconds: a second press of a key inside it is a double.
    public var window = 0.035
    public private(set) var byNote: [Int: Key] = [:]
    /// The latest presses, newest first.
    public private(set) var log: [Press] = []
    public private(set) var presses = 0
    /// The channel the test listens on: the first one a key was pressed on (the active track's).
    public private(set) var channel: Int?
    /// Notes ignored because they came on another channel (other tracks' sequencer notes).
    public private(set) var ignored = 0
    /// The note the leftmost key plays; follows the octave buttons.
    public private(set) var firstNote = KeyTest.defaultFirstNote

    private var lastOn: [Int: Double] = [:]
    private var lastOff: [Int: Double] = [:]
    private var serial = 0

    public init() {}

    public var doubles: Int { byNote.values.reduce(0) { $0 + $1.doubles(window: window) } }
    public var keysWithDoubles: [Int] { byNote.filter { $0.value.doubles(window: window) > 0 }.keys.sorted() }
    public var fastest: Double? { byNote.values.compactMap(\.fastest).min() }

    public func isDouble(_ press: Press) -> Bool { press.gap.map { $0 < window } ?? false }

    /// The key (0…23, left to right) a note is on at the current octave.
    public func key(of note: Int) -> Int? {
        let k = note - firstNote
        return (0..<Self.keys).contains(k) ? k : nil
    }

    public func note(ofKey key: Int) -> Int { firstNote + key }

    public mutating func noteOn(_ note: Int, channel: Int, at time: Double) {
        if self.channel == nil { self.channel = channel }
        guard channel == self.channel else {
            ignored += 1
            return
        }
        follow(note)
        var key = byNote[note] ?? Key()
        key.presses += 1
        var gap: Double?
        if let previous = lastOn[note], time - previous < Self.keepGapsUnder, time >= previous {
            gap = time - previous
            key.gaps.append(time - previous)
        }
        let held = lastOn[note].flatMap { on in lastOff[note].map { $0 - on } }.flatMap { $0 >= 0 ? $0 : nil }
        byNote[note] = key
        lastOn[note] = time
        lastOff[note] = nil
        presses += 1
        serial += 1
        log.insert(Press(id: serial, note: note, time: time, gap: gap, heldBefore: held), at: 0)
        if log.count > Self.logLength { log.removeLast(log.count - Self.logLength) }
    }

    public mutating func noteOff(_ note: Int, channel: Int, at time: Double) {
        guard channel == self.channel else { return }
        lastOff[note] = time
    }

    public mutating func reset() {
        let keep = window
        self = KeyTest()
        window = keep
    }

    /// Shift the keyboard by octaves so the note lands on one of the 24 keys (the OP-Z's − / + buttons).
    private mutating func follow(_ note: Int) {
        while note < firstNote { firstNote -= 12 }
        while note >= firstNote + Self.keys { firstNote += 12 }
    }

    public static func name(_ note: Int) -> String {
        ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][((note % 12) + 12) % 12] + String(note / 12 - 1)
    }

    /// A plain-text summary to keep with the debounce work.
    public var report: String {
        let ms = { (s: Double) in String(Int((s * 1000).rounded())) }
        var lines = ["Galax-z key test · window \(ms(window)) ms · channel \(channel.map { String($0 + 1) } ?? "-")",
                     "\(presses) presses, \(doubles) doubles on \(keysWithDoubles.count) keys"
                        + (fastest.map { ", fastest repeat \(ms($0)) ms" } ?? "")]
        for note in byNote.keys.sorted() {
            let k = byNote[note]!
            let d = k.doubles(window: window)
            lines.append("\(Self.name(note)): \(k.presses) presses" + (d > 0 ? ", \(d) doubles" : "")
                         + (k.fastest.map { ", fastest \(ms($0)) ms" } ?? ""))
        }
        return lines.joined(separator: "\n")
    }
}
