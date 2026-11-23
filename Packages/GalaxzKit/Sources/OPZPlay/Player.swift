import OPZModel

/// Keys into notes: a scale, chords, a hold, a drone, a strum, a groove. It plays one track at a time and remembers exactly what each key
/// sounded, so whatever is changed meanwhile, every note that was begun is ended.
public struct Player: Sendable {
    /// What one key plays.
    public enum Tool: Int, CaseIterable, Codable, Sendable {
        case off, triad, seventh, fifth, octave, numbers, progression
        public var name: String { ["NOTE", "TRIAD", "7TH", "5TH", "OCT", "NUMBERS", "PROG"][rawValue] }
    }
    /// When a key's notes end: with it; with the next key; never, until it is touched again (eight at most).
    public enum Hold: Int, CaseIterable, Codable, Sendable {
        case off, hold, drone
        public var name: String { ["OFF", "HOLD", "DRONE"][rawValue] }
    }
    public enum Order: Int, CaseIterable, Codable, Sendable {
        case chord, up, down, random
        public var name: String { ["CHORD", "UP", "DOWN", "RANDOM"][rawValue] }
    }
    public struct Settings: Equatable, Codable, Sendable {
        public var tonic = 0
        public var scale = Scale.off
        public var tool = Tool.off
        public var hold = Hold.off
        public var progression = "ROYAL ROAD"
        /// How far a progression strays from what is written, 0-1.
        public var vary = 0.0
        /// Keep a chord's notes close to the one before.
        public var lead = true
        /// Seconds from a chord's first note to its last.
        public var strum = 0.0
        /// A groove's name; nil: notes last as keys do.
        public var groove: String?
        public var order = Order.chord
        /// How much of its step a groove's note lasts.
        public var gate = 0.6
        public var swing = 0.0
        public var velocity = 100
        public init() {}
    }
    public struct Event: Equatable, Sendable {
        public var at: Double
        public var command: OPZCommand
        public init(_ at: Double, _ command: OPZCommand) { (self.at, self.command) = (at, command) }
    }
    private struct Held: Sendable { var track: Int; var notes: [Int]; var down: Bool }

    public var settings = Settings() { didSet { if settings.progression != oldValue.progression || settings.tool != oldValue.tool { place = 0 } } }
    public private(set) var track = 0
    /// Where the progression is, and the chord played last.
    public private(set) var place = 0
    public private(set) var chord: NashChord?
    private var held: [Int: Held] = [:]
    private var order: [Int] = []
    private var counts: [Int: Int] = [:]                 // how many hold a track's note
    private var begins: [Int: Double] = [:]              // when a note begins, or began
    private var last: [Int] = []
    private var arp = 0
    private var dice = DotDice(11)

    public init() {}

    /// The notes sounding, or kept for the groove.
    public var kept: [Int] { order.flatMap { held[$0]?.notes ?? [] } }
    public func isLit(_ key: Int) -> Bool { held[key] != nil }
    public var isEmpty: Bool { held.isEmpty && counts.isEmpty }

    // MARK: keys

    public mutating func press(_ key: Int, note: Int, velocity: Int? = nil, at now: Double) -> [Event] {
        var out: [Event] = []
        if let h = held[key] {
            if settings.hold == .drone, !h.down { return let_go(key, now) }             // touched again
            out += let_go(key, now)
        }
        if settings.hold == .hold { for k in order where !(held[k]?.down ?? false) { out += let_go(k, now) } }
        if settings.hold == .drone, order.count >= 8, let first = order.first { out += let_go(first, now) }
        let notes = self.notes(for: note)
        held[key] = Held(track: track, notes: notes, down: true)
        order.append(key)
        if settings.groove == nil { out += begin(notes, velocity ?? settings.velocity, now) }
        return out
    }

    public mutating func release(_ key: Int, at now: Double) -> [Event] {
        guard var h = held[key] else { return [] }
        if settings.hold == .off { return let_go(key, now) }
        h.down = false
        held[key] = h
        return []
    }

    /// Everything that sounds ends.
    public mutating func silence(at now: Double) -> [Event] {
        var out: [Event] = []
        for k in order { out += let_go(k, now) }
        out += counts.keys.sorted().map { Event(ends($0, now), .noteOff(track: $0 >> 8, note: $0 & 255)) }
        counts = [:]
        return out
    }

    public mutating func select(track t: Int, at now: Double) -> [Event] {
        guard t != track else { return [] }
        let out = settings.hold == .off ? silence(at: now) : []           // a hold goes on while another track is played
        track = max(0, min(15, t))
        return out
    }

    /// HOLD or DRONE off: what they kept ends, what is still under a finger does not.
    public mutating func unhold(at now: Double) -> [Event] { order.filter { !(held[$0]?.down ?? false) }.flatMap { let_go($0, now) } }

    private mutating func let_go(_ key: Int, _ now: Double) -> [Event] {
        guard let h = held.removeValue(forKey: key) else { return [] }
        order.removeAll { $0 == key }
        return h.notes.flatMap { off(h.track, $0, now) }
    }

    private mutating func begin(_ notes: [Int], _ velocity: Int, _ now: Double) -> [Event] {
        notes.enumerated().map { i, n in
            counts[track << 8 | n, default: 0] += 1
            let at = notes.count > 1 ? now + settings.strum * Double(i) / Double(notes.count - 1) : now
            begins[track << 8 | n] = max(at, begins[track << 8 | n] ?? at)
            return Event(at, .noteOn(track: track, note: n, velocity: i == 0 ? velocity : max(1, velocity * 85 / 100)))
        }
    }

    private mutating func off(_ t: Int, _ n: Int, _ at: Double) -> [Event] {
        guard let c = counts[t << 8 | n] else { return [] }
        counts[t << 8 | n] = c > 1 ? c - 1 : nil
        return c > 1 ? [] : [Event(ends(t << 8 | n, at), .noteOff(track: t, note: n))]
    }

    /// A strummed note that has not begun yet is ended when it has.
    private func ends(_ k: Int, _ at: Double) -> Double { begins[k].map { $0 >= at ? $0 + 0.001 : at } ?? at }

    // MARK: chords

    /// The notes of a key, lowest first.
    mutating func notes(for key: Int) -> [Int] {
        let s = settings
        chord = nil
        // drums are their keys
        if track < 4 { return [key] }
        func close(_ c: NashChord, near: Int) -> [Int] {
            let pc = (s.tonic + c.root) % 12, base = near - (((near - pc) % 12) + 12) % 12
            let root = c.intervals.map { base + $0 }
            guard s.lead, last.count > 1 else { return root }
            // the inversion that moves least
            let ways = (0..<root.count).flatMap { k in [-12, 0].map { o in (root.dropFirst(k) + root.prefix(k).map { $0 + 12 }).map { $0 + o }.sorted() } }
            func far(_ a: [Int]) -> Int { a.reduce(0) { sum, n in sum + last.map { abs($0 - n) }.min()! } + abs(a[0] - last[0]) }
            return ways.filter { $0[0] >= 24 && $0.last! <= 108 }.min { far($0) < far($1) } ?? root
        }
        var out: [Int]
        switch s.tool {
        case .off: out = [s.scale.snap(key, tonic: s.tonic)]
        case .triad, .seventh, .fifth, .octave:
            let root = s.scale.snap(key, tonic: s.tonic)
            if s.scale != .off, s.tool == .triad || s.tool == .seventh {
                let tonic = root - (((root - s.tonic) % 12) + 12) % 12, degree = s.scale.steps.firstIndex(of: root - tonic) ?? 0
                out = (s.tool == .triad ? [0, 2, 4] : [0, 2, 4, 6]).map { s.scale.note(degree + $0, base: tonic) }
            } else {
                out = (s.tool == .triad ? [0, 4, 7] : s.tool == .seventh ? [0, 4, 7, 10] : s.tool == .fifth ? [0, 7, 12] : [0, 12]).map { root + $0 }
            }
        case .numbers:
            let pc = ((key % 12) + 12) % 12, c = Progressions.keyChords[pc]
            chord = c
            out = close(c, near: key - pc + s.tonic + c.root - (s.tonic > 6 ? 12 : 0))
        case .progression:
            let p = Progressions.named(s.progression) ?? Progressions.all[0]
            let c = ChordVary.vary(p.chords[place % p.chords.count], amount: Float(s.vary)) { dice.next() }
            place = (place + 1) % p.chords.count
            chord = c
            out = close(c, near: key)
        }
        out = Array(Set(out.map { max(0, min(127, $0)) })).sorted()
        last = out
        return out
    }

    /// The chord that comes next in the progression, named.
    public var upNext: String {
        let p = Progressions.named(settings.progression) ?? Progressions.all[0]
        return p.chords[place % p.chords.count].name(tonic: settings.tonic)
    }

    // MARK: groove

    /// A sixteenth of the bar (0-15) begins at `at`: what the groove plays of the notes kept.
    public mutating func groove(step: Int, at: Double, sixteenth: Double) -> [Event] {
        guard let name = settings.groove, let p = Groove.library.first(where: { $0.name == name }), !order.isEmpty else { return [] }
        let m = Groove.masks(p.steps), bit = UInt16(1) << UInt16(step & 15)
        guard m.hit & bit != 0 else { return [] }
        let v = m.accent & bit != 0 ? min(127, settings.velocity * 118 / 100) : m.ghost & bit != 0 ? settings.velocity * 45 / 100 : settings.velocity * 85 / 100
        let start = at + (step & 1 == 1 ? settings.swing * 0.33 * sixteenth : 0)
        var out: [Event] = []
        for (t, notes) in Dictionary(grouping: order.compactMap { held[$0] }, by: \.track).sorted(by: { $0.key < $1.key }) {
            let pool = Array(Set(notes.flatMap(\.notes))).sorted()
            let these: [Int] = switch settings.order {
            case .chord: pool
            case .up: [pool[arp % pool.count]]
            case .down: [pool[pool.count - 1 - arp % pool.count]]
            case .random: [pool[min(pool.count - 1, Int(dice.next() * Float(pool.count)))]]
            }
            for n in these {
                out.append(Event(start, .noteOn(track: t, note: n, velocity: max(1, v))))
                out.append(Event(start + sixteenth * max(0.1, min(1.9, settings.gate)), .noteOff(track: t, note: n)))
            }
        }
        arp += 1
        return out.sorted { $0.at < $1.at }
    }
}

/// Chance that comes out the same every run.
struct DotDice: Sendable {
    private var s: UInt64
    init(_ seed: UInt64) { s = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }
    mutating func next() -> Float {
        s ^= s << 13; s ^= s >> 7; s ^= s << 17
        return Float(s >> 40) / 16_777_216
    }
}
