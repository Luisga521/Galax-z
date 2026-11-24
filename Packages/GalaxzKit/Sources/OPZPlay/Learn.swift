import OPZModel

/// A knob, fader, pad or key of any controller.
public struct Control: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable { case cc, note }
    public var device: String
    public var channel: Int
    public var kind: Kind
    public var number: Int
    public init(device: String, channel: Int, kind: Kind, number: Int) { (self.device, self.channel, self.kind, self.number) = (device, channel, kind, number) }
    public var name: String { (kind == .cc ? "CC \(number)" : "PAD \(number)") + " · CH \(channel + 1)" }
}

/// What a control does. A track of nil: the one that is selected.
public enum Target: Hashable, Codable, Sendable {
    case sound(track: Int?, param: Int)
    /// One of the OP-Z's four encoders (0-3): what it turns on the selected track's page.
    case encoder(Int)
    case gain(track: Int?)
    case mute(track: Int?)
    case move(pad: Int)
    /// A dial of the chops, and a chop.
    case chopDial(Int), chop(Int)
    case select(track: Int)
    case page(by: Int)
    case pattern(Int)
    case nextPattern, previousPattern
    case play
    /// Its keys play the selected track.
    case keys

    public var name: String {
        func t(_ n: Int?) -> String { n.map { OPZ.trackNames[$0 & 15].uppercased() } ?? "TRACK" }
        switch self {
        case .sound(let n, let p): return t(n) + " · " + (OPZ.params.indices.contains(p) ? OPZ.params[p].uppercased() : "?")
        case .encoder(let e): return "ENCODER \(e + 1)"
        case .gain(let n): return t(n) + " · VOLUME"
        case .mute(let n): return t(n) + " · MUTE"
        case .move(let p): return "PERFORM PAD \(p + 1)"
        case .chopDial(let d): return "CHOPS · " + (["PITCH", "MUTATE", "BLOOM", "TAIL", "TONE", "ATTACK", "SPREAD", "LEVEL"].indices.contains(d) ? ["PITCH", "MUTATE", "BLOOM", "TAIL", "TONE", "ATTACK", "SPREAD", "LEVEL"][d] : "?")
        case .chop(let n): return "CHOP \(n + 1)"
        case .select(let n): return "SELECT " + t(n)
        case .page(let by): return by > 0 ? "NEXT PAGE" : "PAGE BEFORE"
        case .pattern(let p): return "PATTERN \(p + 1)"
        case .nextPattern: return "NEXT PATTERN"
        case .previousPattern: return "PATTERN BEFORE"
        case .play: return "PLAY / STOP"
        case .keys: return "PLAY THE TRACK"
        }
    }
    /// It takes a value; the others are pressed.
    public var continuous: Bool { switch self { case .sound, .encoder, .gain, .chopDial: true; default: false } }
}

/// What has been learned: any controller's controls to what they do.
public struct Learned: Codable, Equatable, Sendable {
    /// How a knob says where it is.
    public enum Way: String, Codable, Sendable {
        /// 0-127; it takes hold when it passes where the value is, so nothing jumps.
        case absolute
        /// 1 up, 127 down (or 65 and 63), for a knob with no ends.
        case relative
    }
    public struct Entry: Codable, Equatable, Sendable, Identifiable {
        public var control: Control
        public var target: Target
        public var way: Way
        public var id: Control { control }
    }
    public private(set) var entries: [Entry] = []
    /// What the next control that moves will do.
    public private(set) var waiting: Target?
    private var seen: [Control: [Int]] = [:]
    private var caught: Set<Control> = [], lastValue: [Control: Int] = [:]

    private enum CodingKeys: CodingKey { case entries }
    public init() {}

    public mutating func learn(_ t: Target?) { waiting = t; seen = [:] }
    public mutating func forget(_ c: Control) { entries.removeAll { $0.control == c }; caught.remove(c) }
    public mutating func forgetAll() { entries = []; caught = [] }
    public func entry(_ c: Control) -> Entry? { entries.first { $0.control == c } }
    public func controls(of t: Target) -> [Control] { entries.filter { $0.target == t }.map(\.control) }
    public mutating func set(_ way: Way, for c: Control) { if let i = entries.firstIndex(where: { $0.control == c }) { entries[i].way = way } }

    public enum Action: Equatable, Sendable { case learned(Entry), set(Target, Int), press(Target, velocity: Int), release(Target), none }

    /// A control moved to `value` (a key let go: 0). `now`: where what it sets is, 0-127, if that is known.
    public mutating func moved(_ c: Control, _ value: Int, now: (Target) -> Int?) -> Action {
        if let t = waiting {
            guard c.kind == .cc || value > 0 else { return .none }
            // a knob with no ends says little numbers over and over: three of them tell
            var way = Way.absolute
            if t.continuous, c.kind == .cc {
                seen[c, default: []].append(value)
                let s = seen[c]!
                guard s.count >= 3 else { return .none }
                if s.allSatisfy({ [1, 2, 3, 127, 126, 125].contains($0) }) || s.allSatisfy({ [63, 65, 62, 66].contains($0) }), Set(s).count < 3 { way = .relative }
            }
            let e = Entry(control: c, target: t, way: way)
            entries.removeAll { $0.control == c }
            entries.append(e)
            waiting = nil
            seen = [:]
            caught.remove(c)
            lastValue[c] = value
            return .learned(e)
        }
        guard let e = entry(c) else { return .none }
        let was = lastValue[c] ?? value
        lastValue[c] = value
        if !e.target.continuous {
            if c.kind == .note { return value > 0 ? .press(e.target, velocity: value) : .release(e.target) }
            if value >= 64, was < 64 || lastValue[c] == nil { return .press(e.target, velocity: value) }
            return value < 64 && was >= 64 ? .release(e.target) : .none
        }
        if c.kind == .note { return value > 0 ? .set(e.target, value) : .none }
        let at = now(e.target)
        if e.way == .relative {
            let by = value == 0 || value == 64 ? 0 : value < 32 ? value : value > 96 ? value - 128 : value - 64
            return by == 0 ? .none : .set(e.target, max(0, min(127, (at ?? 64) + by)))
        }
        if caught.contains(c), let at, abs(at - was) > 12 { caught.remove(c) }              // changed elsewhere since
        if !caught.contains(c) {
            guard let at else { caught.insert(c); return .set(e.target, value) }
            guard abs(value - at) <= 3 || (was < at) != (value < at) else { return .none }
            caught.insert(c)
        }
        return .set(e.target, value)
    }
}
