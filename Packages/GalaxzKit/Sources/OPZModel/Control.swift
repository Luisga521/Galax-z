/// What an app can ask of the OP-Z over plain MIDI (its manual, p. 57-60; op-free `research/param-paths.md`, `manual-notes.md`): nothing of
/// it is kept unless the OP-Z's project is saved, and it needs MIDI in switched on (hold TEMPO + SCREEN, key 2).
public enum OPZCommand: Equatable, Hashable, Sendable {
    case noteOn(track: Int, note: Int, velocity: Int)
    case noteOff(track: Int, note: Int)
    /// One of the 18 sound values (`OPZ.params`'s order), 0-127.
    case sound(track: Int, param: Int, value: Int)
    /// The mixer's gain of a track, 0-127.
    case gain(track: Int, value: Int)
    case mute(track: Int, on: Bool)
    /// Pitch, -1 ... 1.
    case bend(track: Int, Double)
    case pattern(project: Int, Int)
    case nextPattern, previousPattern
    case start, stop, proceed

    /// The CC of each sound value: CCs 1-18 go P1 P2 filter resonance A D S R, the LFO's four, FX1 FX2 pan level, portamento, note style.
    public static let soundCC = [1, 2, 5, 6, 7, 8, 13, 14, 3, 4, 15, 16, 17, 9, 10, 11, 12, 18]

    /// The track it is for.
    public var track: Int? {
        switch self {
        case .noteOn(let t, _, _), .noteOff(let t, _), .sound(let t, _, _), .gain(let t, _), .mute(let t, _), .bend(let t, _): t
        default: nil
        }
    }

    /// As MIDI: one short message. Nothing for what is out of range.
    public var bytes: [UInt8] {
        func seven(_ v: Int) -> UInt8 { UInt8(max(0, min(127, v))) }
        func on(_ status: UInt8, _ t: Int, _ a: Int, _ b: Int) -> [UInt8] { (0..<16).contains(t) ? [status | UInt8(t), seven(a), seven(b)] : [] }
        switch self {
        case .noteOn(let t, let n, let v): return (0...127).contains(n) ? on(0x90, t, n, max(1, v)) : []
        case .noteOff(let t, let n): return (0...127).contains(n) ? on(0x80, t, n, 0) : []
        case .sound(let t, let p, let v): return Self.soundCC.indices.contains(p) ? on(0xB0, t, Self.soundCC[p], v) : []
        case .gain(let t, let v): return on(0xB0, t, 50, v)
        case .mute(let t, let m): return on(0xB0, t, 53, m ? 127 : 0)
        case .bend(let t, let x):
            let v = max(0, min(16383, Int((8192 + max(-1, min(1, x)) * 8191).rounded())))
            return on(0xE0, t, v & 127, v >> 7)
        case .pattern(let project, let p): return (0..<10).contains(project) && (0..<16).contains(p) ? on(0xB0, project, 103, p) : []
        case .nextPattern: return on(0xB0, 0, 103, 16)
        case .previousPattern: return on(0xB0, 0, 103, 17)
        case .start: return [0xFA]
        case .stop: return [0xFC]
        case .proceed: return [0xFB]
        }
    }
}
