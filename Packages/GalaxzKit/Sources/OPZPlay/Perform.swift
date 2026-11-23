import OPZModel

/// A performance move: what it does to the OP-Z while it is held (or on), over MIDI. All of it is put back when it ends.
public struct Move: Identifiable, Codable, Equatable, Sendable {
    public enum Kind: Codable, Equatable, Sendable {
        /// The gain on and off, `division` sixteenths a turn, open for `open` of it.
        case gate(division: Double, open: Double)
        /// A pattern of sixteenths, as a groove's.
        case trance(String)
        /// A sound value goes to `to` (0-1) over so many beats, and stays.
        case sweep(param: Int, to: Double, beats: Double)
        /// A sound value up and down around where it is, so many beats a turn.
        case wave(param: Int, beats: Double, stepped: Bool)
        /// The gain goes to `to` over so many beats.
        case fade(to: Double, beats: Double)
        /// The pitch goes to `to` (-1 ... 1) over so many beats.
        case bend(to: Double, beats: Double)
        case mute
        /// The note played last, again and again.
        case roll(division: Double, rising: Bool)
    }
    /// Which tracks it takes.
    public enum Scope: Int, CaseIterable, Codable, Sendable {
        case track, drums, synths, all, others
        public var name: String { ["TRACK", "DRUMS", "SYNTHS", "ALL", "OTHERS"][rawValue] }
        public func tracks(_ selected: Int) -> [Int] {
            switch self {
            case .track: [selected]
            case .drums: [0, 1, 2, 3]
            case .synths: [4, 5, 6, 7]
            case .all: Array(0..<8)
            case .others: (0..<8).filter { $0 != selected }
            }
        }
    }
    public var id: String
    public var name: String
    public var blurb: String
    public var family: String
    public var kind: Kind
    public var scope: Scope
    /// How much of it, 0-1.
    public var amount = 1.0
    public init(id: String, name: String, blurb: String, family: String, kind: Kind, scope: Scope, amount: Double = 1) {
        (self.id, self.name, self.blurb, self.family, self.kind, self.scope, self.amount) = (id, name, blurb, family, kind, scope, amount)
    }

    private static func m(_ id: String, _ name: String, _ family: String, _ scope: Scope, _ kind: Kind, _ blurb: String, _ amount: Double = 1) -> Move {
        Move(id: id, name: name, blurb: blurb, family: family, kind: kind, scope: scope, amount: amount)
    }
    public static let families = ["GATE", "FILTER", "SPACE", "PITCH", "MIX", "ROLL", "MOTION"]
    /// The gallery. Places in `OPZ.params`: 0 P1, 1 P2, 2-5 the envelope, 6 FX1, 7 FX2, 8 filter, 9 resonance, 10 pan, 11 level.
    public static let gallery: [Move] = [
        m("gate8", "GATE 1/8", "GATE", .all, .gate(division: 2, open: 0.5), "Chops everything in eighths"),
        m("gate16", "GATE 1/16", "GATE", .all, .gate(division: 1, open: 0.5), "Chops everything in sixteenths"),
        m("gate3", "GATE 3/16", "GATE", .synths, .gate(division: 3, open: 0.5), "Synths chopped across the beat"),
        m("gate4", "GATE 1/4", "GATE", .synths, .gate(division: 4, open: 0.35), "Short stabs on the beat"),
        m("trance", "TRANCE", "GATE", .synths, .trance("Xx.xX.xx.xx.Xx.x"), "A trance gate over the synths"),
        m("stutter", "STUTTER", "GATE", .all, .trance("Xxx.....Xxx....."), "Three and a rest"),
        m("tresillo", "TRESILLO", "GATE", .synths, .trance("X..x..x.X..x..x."), "The clave as a gate"),
        m("pump", "PUMP", "GATE", .synths, .trance("..Xx..Xx..Xx..Xx"), "Ducks on the beat, like a sidechain"),
        m("dive", "FILTER DIVE", "FILTER", .all, .sweep(param: 8, to: 0, beats: 4), "Closes the filter over a bar"),
        m("rise", "FILTER RISE", "FILTER", .all, .sweep(param: 8, to: 1, beats: 8), "Opens the filter over two bars"),
        m("drumdive", "DRUM DIVE", "FILTER", .drums, .sweep(param: 8, to: 0.1, beats: 2), "The drums go under"),
        m("reso", "SCREAM", "FILTER", .synths, .sweep(param: 9, to: 1, beats: 4), "Resonance up, for a bar", 0.8),
        m("wah", "WAH", "FILTER", .synths, .wave(param: 8, beats: 1, stepped: false), "The filter up and down each beat", 0.6),
        m("sample", "SAMPLE HOLD", "FILTER", .track, .wave(param: 8, beats: 0.5, stepped: true), "A new filter place each eighth", 0.7),
        m("wash", "WASH", "SPACE", .all, .sweep(param: 7, to: 1, beats: 2), "Everything into FX 2"),
        m("throw", "THROW", "SPACE", .track, .sweep(param: 6, to: 1, beats: 0.1), "This track into FX 1, at once"),
        m("cloud", "CLOUD DRUMS", "SPACE", .drums, .sweep(param: 7, to: 0.9, beats: 4), "The drums drift into FX 2"),
        m("dry", "DRY", "SPACE", .all, .sweep(param: 7, to: 0, beats: 0.1), "All of it out of FX 2"),
        m("tape", "TAPE STOP", "PITCH", .all, .bend(to: -1, beats: 2), "The pitch falls away"),
        m("lift", "LIFT", "PITCH", .synths, .bend(to: 1, beats: 4), "The synths climb for a bar"),
        m("dip", "DIP", "PITCH", .track, .bend(to: -0.5, beats: 0.25), "A quick dip of this track"),
        m("drop", "DRUMS OUT", "MIX", .drums, .mute, "Takes the drums away"),
        m("breakdown", "SYNTHS OUT", "MIX", .synths, .mute, "Only the drums"),
        m("solo", "SOLO", "MIX", .others, .mute, "Only this track"),
        m("silence", "SILENCE", "MIX", .all, .mute, "Nothing, for as long as it is held"),
        m("fade", "FADE OUT", "MIX", .all, .fade(to: 0, beats: 16), "Out over four bars"),
        m("duck", "DUCK", "MIX", .others, .fade(to: 0.35, beats: 0.5), "The others step back"),
        m("roll16", "ROLL 1/16", "ROLL", .track, .roll(division: 1, rising: false), "The last note, in sixteenths", 0.8),
        m("roll32", "ROLL 1/32", "ROLL", .track, .roll(division: 0.5, rising: false), "The last note, in thirty-seconds", 0.8),
        m("roll12", "ROLL TRIPLET", "ROLL", .track, .roll(division: 4.0 / 3, rising: false), "The last note, in triplets", 0.8),
        m("build", "BUILD", "ROLL", .track, .roll(division: 1, rising: true), "A roll that gets louder and faster for two bars"),
        m("spin", "SPIN", "MOTION", .synths, .wave(param: 10, beats: 2, stepped: false), "Round the room, half a bar a turn"),
        m("pingpong", "PING PONG", "MOTION", .drums, .wave(param: 10, beats: 1, stepped: true), "The drums left and right"),
        m("morph", "MORPH", "MOTION", .track, .wave(param: 0, beats: 4, stepped: false), "P1 breathes over a bar", 0.5),
        m("glitch", "GLITCH", "MOTION", .track, .wave(param: 1, beats: 0.25, stepped: true), "P2 jumps each sixteenth", 0.8),
    ]
    public static func named(_ id: String) -> Move? { gallery.first { $0.id == id } }
}

/// What the moves start from: the OP-Z as it is.
public protocol MoveSource {
    /// A sound value and a track's gain, 0-127.
    func sound(_ track: Int, _ param: Int) -> Int
    func gain(_ track: Int) -> Int
    func muted(_ track: Int) -> Bool
    func lastNote(_ track: Int) -> Int
}

/// The moves that are on. Give it the beat (quarter notes, any origin) some sixty times a second; it says what changed, and puts back
/// what each move took when the last move on it ends.
public struct Performer: Sendable {
    private enum Place: Hashable, Comparable { case sound(Int, Int), gain(Int), bend(Int), mute(Int)
        static func < (a: Place, b: Place) -> Bool { a.key < b.key }
        var key: Int { switch self { case .sound(let t, let p): t * 32 + p; case .gain(let t): 1000 + t; case .bend(let t): 2000 + t; case .mute(let t): 3000 + t } }
    }
    private struct On: Sendable { var move: Move; var tracks: [Int]; var since: Double; var rolled = -1; var notes: [Int: Int] = [:] }

    private var on: [(id: Int, On)] = []
    private var before: [Place: Int] = [:]
    private var sent: [Place: Int] = [:]
    private var dice = DotDice(3)
    private var held: [String: Double] = [:]

    public init() {}

    public var active: Set<Int> { Set(on.map(\.id)) }
    public var isEmpty: Bool { on.isEmpty }

    /// Begin a move (on a pad): `beat` is when.
    public mutating func begin(_ pad: Int, _ move: Move, selected: Int, beat: Double, from s: some MoveSource) -> [OPZCommand] {
        var out = end(pad)
        let tracks = move.scope.tracks(selected)
        on.append((pad, On(move: move, tracks: tracks, since: beat)))
        for t in tracks { for p in places(move, t) where before[p] == nil { before[p] = now(p, s) } }
        out += step(beat: beat, from: s)
        return out
    }

    /// End a move: what nothing else holds is put back.
    public mutating func end(_ pad: Int) -> [OPZCommand] {
        guard let i = on.firstIndex(where: { $0.id == pad }) else { return [] }
        let gone = on.remove(at: i).1
        var out = gone.notes.sorted { $0.key < $1.key }.map { OPZCommand.noteOff(track: $0.key, note: $0.value) }
        let still = Set(on.flatMap { o in o.1.tracks.flatMap { places(o.1.move, $0) } })
        for p in gone.tracks.flatMap({ places(gone.move, $0) }).sorted() where !still.contains(p) {
            guard let v = before.removeValue(forKey: p) else { continue }
            if sent[p] != nil, sent[p] != v { out.append(command(p, v)) }
            sent[p] = nil
        }
        return out
    }

    public mutating func endAll() -> [OPZCommand] { on.map(\.id).flatMap { end($0) } }

    /// On to `beat`.
    public mutating func step(beat: Double, from s: some MoveSource) -> [OPZCommand] {
        var out: [OPZCommand] = [], want: [Place: Double] = [:]
        for i in on.indices {
            let m = on[i].1.move, age = max(0, beat - on[i].1.since)
            for (k, t) in on[i].1.tracks.enumerated() {
                func hold(_ p: Place, _ v: Double) { want[p] = v }
                func base(_ p: Place) -> Double { want[p] ?? Double(before[p] ?? 0) }
                func toward(_ p: Place, _ target: Double, _ beats: Double) {
                    let f = beats <= 0 ? 1 : min(1, age / beats)
                    hold(p, base(p) + (target - base(p)) * f * m.amount)
                }
                switch m.kind {
                case .gate(let d, let open):
                    let x = beat * 4 / d
                    hold(.gain(t), base(.gain(t)) * (x - x.rounded(.down) < open ? 1 : 1 - m.amount))
                case .trance(let steps):
                    let at = Int((beat * 4).rounded(.down)), step = ((at % 16) + 16) % 16, x = beat * 4 - Double(at)
                    let bit = UInt16(1) << UInt16(step), g = Groove.masks(steps)
                    hold(.gain(t), base(.gain(t)) * (g.hit & bit != 0 && x < 0.8 ? (g.ghost & bit != 0 ? 1 - 0.5 * m.amount : 1) : 1 - m.amount))
                case .sweep(let p, let to, let beats): toward(.sound(t, p), to * 127, beats)
                case .fade(let to, let beats): toward(.gain(t), base(.gain(t)) * to, beats)
                case .bend(let to, let beats):
                    hold(.bend(t), to * (beats <= 0 ? 1 : min(1, age / beats)) * m.amount * 8191)
                case .wave(let p, let beats, let stepped):
                    let turn = beat / max(0.05, beats)
                    let w: Double
                    if stepped {
                        let n = Int(turn.rounded(.down)), key = "\(on[i].id) \(t) \(n)"
                        if held[key] == nil { if held.count > 64 { held = [:] }; held[key] = p == 10 ? ((n + k) & 1 == 0 ? -1 : 1) : Double(dice.next()) * 2 - 1 }
                        w = held[key]!
                    } else { w = Self.sine(turn + (p == 10 ? Double(k) / Double(max(1, on[i].1.tracks.count)) : 0)) }
                    hold(.sound(t, p), min(127, max(0, (p == 10 ? 63.5 : base(.sound(t, p))) + w * 63.5 * m.amount)))
                case .mute: hold(.mute(t), 1)
                case .roll(let d, let rising):
                    let way = rising ? min(1, age / 8) : 1, division = rising ? (way < 0.5 ? d * 2 : way < 0.8 ? d : d / 2) : d
                    let n = Int((beat * 4 / division).rounded(.down))
                    guard n != on[i].1.rolled || on[i].1.notes[t] == nil else { continue }
                    if k == on[i].1.tracks.count - 1 { on[i].1.rolled = n }
                    if let was = on[i].1.notes[t] { out.append(.noteOff(track: t, note: was)) }
                    let note = s.lastNote(t)
                    on[i].1.notes[t] = note
                    out.append(.noteOn(track: t, note: note, velocity: max(1, Int((rising ? 40 + 87 * way : 127) * max(0.1, m.amount)))))
                }
            }
        }
        for (p, v) in want.sorted(by: { $0.key < $1.key }) {
            let n = Int(v.rounded())
            guard sent[p] != n else { continue }
            if case .bend = p, let was = sent[p], abs(was - n) < 40, n != 0 { continue }        // fine enough for an ear
            if sent[p] == nil, n == before[p] { continue }
            sent[p] = n
            out.append(command(p, n))
        }
        return out
    }

    private func places(_ m: Move, _ t: Int) -> [Place] {
        switch m.kind {
        case .gate, .trance, .fade: [.gain(t)]
        case .sweep(let p, _, _), .wave(let p, _, _): [.sound(t, p)]
        case .bend: [.bend(t)]
        case .mute: [.mute(t)]
        case .roll: []
        }
    }
    private func now(_ p: Place, _ s: some MoveSource) -> Int {
        switch p {
        case .sound(let t, let k): s.sound(t, k)
        case .gain(let t): s.gain(t)
        case .bend: 0
        case .mute(let t): s.muted(t) ? 1 : 0
        }
    }
    private func command(_ p: Place, _ v: Int) -> OPZCommand {
        switch p {
        case .sound(let t, let k): .sound(track: t, param: k, value: v)
        case .gain(let t): .gain(track: t, value: v)
        case .bend(let t): .bend(track: t, Double(v) / 8191)
        case .mute(let t): .mute(track: t, on: v != 0)
        }
    }
    /// A sine a turn long, near enough.
    static func sine(_ turns: Double) -> Double {
        let x = turns - turns.rounded(.down), y = x < 0.5 ? x * 2 : (x - 0.5) * 2, p = 4 * y * (1 - y)
        return (x < 0.5 ? 1 : -1) * p * (0.775 + 0.225 * p)
    }
}

/// The sixteen pads of the performance bay: a move each, changed as wanted.
public struct PerformBay: Codable, Equatable, Sendable {
    public static let pads = 16
    public var slots: [Move?]
    public init() { slots = ["gate16", "stutter", "dive", "rise", "wash", "throw", "tape", "lift", "drop", "breakdown", "solo", "duck", "roll16", "build", "spin", "glitch"].map(Move.named) }
    public mutating func load(_ m: Move?, at pad: Int) { if slots.indices.contains(pad) { slots[pad] = m } }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        slots = Array((try c.decode([Move?].self, forKey: .slots) + [Move?](repeating: nil, count: Self.pads)).prefix(Self.pads))
    }
}
