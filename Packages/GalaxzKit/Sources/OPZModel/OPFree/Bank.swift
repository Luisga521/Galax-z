// SPDX-License-Identifier: MIT
// Derived from OP-FREE: a Swift port of the read side of core/src/project.ts
// Copyright (c) 2026 Lourens Smit and the op-z-engines contributors (OP-FREE)
// Copyright (c) 2026 Luis Tosado (this version of it)

/// The OP-Z's pattern bank: the 16 patterns of one project, as StateSync sends it and as a project file holds it.
/// Port of the read side of op-free's `core/src/project.ts` (layout and evidence: op-free `research/patterns.md`).
/// The bytes are kept as they came so unknown fields survive.
public enum OPZ {
    public static let patternSize = 21_392
    public static let patterns = 16
    public static let tracks = 16
    public static let steps = 16
    public static let bankSize = patternSize * patterns // 342,272
    public static let globalSize = 568

    public static let trackNames = ["kick", "snare", "perc", "sample", "bass", "lead", "arp", "chord", "fx1", "fx2",
                                    "tape", "master", "perform", "module", "lights", "motion"]
    public static let notesPerStep = [2, 2, 2, 2, 4, 4, 8, 4, 1, 1, 1, 4, 6, 6, 4, 4]
    static let noteOffsets = [0, 2, 4, 6, 8, 12, 16, 24, 28, 29, 30, 31, 35, 41, 47, 51]
    public static let slotsPerStep = 55
    public static let params = ["p1", "p2", "attack", "decay", "sustain", "release", "fx1", "fx2", "filter",
                                "resonance", "pan", "level", "portamento", "lfo_depth", "lfo_speed", "lfo_value",
                                "lfo_shape", "note_style"]
    public static let components = ["pulse", "spark", "jump", "velocity", "ramp_up", "ramp_down", "random", "glide",
                                    "multiply", "sweep", "pulse_hold", "tonality", "trigger_spark", "component_spark"]

    public static let notesAt = 192
    static let stepsAt = 7_232
    static let soundAt = 21_056
    static let mutesAt = 21_344
    static let masterAt = 21_386
    static let muteGroupAt = 21_388
    static let stepRecord = 54
    static let trackRecord = 12
    static let inUseBit = 0x0800
    static let tempoAt = 516
    static let swingAt = 561
}

public struct Note: Equatable, Hashable, Sendable {
    public var note: Int
    public var velocity: Int
    /// In step units: 6,200 is one step.
    public var duration: Int
    /// As stored: eighths of a micro tick (the core's `micro`).
    public var micro: Int
    public var age: Int
}

public struct TrackRecord: Equatable, Sendable {
    public var plug: UInt32
    public var stepCount: Int
    public var timing: Int
    public var stepLength: Int
    public var quantize: Int
    public var byte8: Int
    public var noteLength: Int
    public var lastNote: Int
    public var byte11: Int
}

public struct Step: Equatable, Sendable {
    public var mask: Int
    /// Step components that are on, by name, with their value.
    public var components: [String: Int]
    /// Parameter locks, by name, with the locked value.
    public var locks: [String: Int]
}

/// Address of a pattern in StateSync: project × 16 + pattern, both zero-based.
public struct PatternAddress: Equatable, Hashable, Sendable {
    public var raw: Int
    public init(raw: Int) { self.raw = raw }
    public var project: Int { raw >> 4 }
    public var pattern: Int { raw & 0x0F }
}

public struct Bank: Equatable, Sendable {
    public internal(set) var bytes: [UInt8]

    public init?(_ bytes: [UInt8]) {
        guard bytes.count == OPZ.bankSize else { return nil }
        self.bytes = bytes
    }

    private func u16(_ at: Int) -> Int { Int(bytes[at]) | Int(bytes[at + 1]) << 8 }
    private func u32(_ at: Int) -> UInt32 {
        UInt32(bytes[at]) | UInt32(bytes[at + 1]) << 8 | UInt32(bytes[at + 2]) << 16 | UInt32(bytes[at + 3]) << 24
    }
    private func i32(_ at: Int) -> Int { Int(Int32(bitPattern: u32(at))) }
    private func i8(_ at: Int) -> Int { Int(Int8(bitPattern: bytes[at])) }

    private static func check(_ p: Int, _ t: Int = 0, _ s: Int = 0) {
        precondition((0..<16).contains(p) && (0..<16).contains(t) && (0..<16).contains(s),
                     "pattern, track and step are 0...15")
    }

    public func track(_ p: Int, _ t: Int) -> TrackRecord {
        Self.check(p, t)
        let at = p * OPZ.patternSize + t * OPZ.trackRecord
        return TrackRecord(plug: u32(at), stepCount: Int(bytes[at + 4]), timing: Int(bytes[at + 5]),
                           stepLength: Int(bytes[at + 6]), quantize: Int(bytes[at + 7]), byte8: Int(bytes[at + 8]),
                           noteLength: Int(bytes[at + 9]), lastNote: Int(bytes[at + 10]), byte11: Int(bytes[at + 11]))
    }

    public func notes(_ p: Int, _ t: Int, _ s: Int) -> [Note] {
        Self.check(p, t, s)
        var out: [Note] = []
        for slot in 0..<OPZ.notesPerStep[t] {
            let at = p * OPZ.patternSize + OPZ.notesAt + (s * OPZ.slotsPerStep + OPZ.noteOffsets[t] + slot) * 8
            let note = bytes[at + 4]
            if note == 0xFF { continue }
            out.append(Note(note: Int(note), velocity: Int(bytes[at + 5]), duration: i32(at), micro: i8(at + 6),
                            age: Int(bytes[at + 7])))
        }
        return out
    }

    public func step(_ p: Int, _ t: Int, _ s: Int) -> Step {
        Self.check(p, t, s)
        let at = p * OPZ.patternSize + OPZ.stepsAt + (t * OPZ.steps + s) * OPZ.stepRecord
        let mask = u16(at)
        var components: [String: Int] = [:]
        var locks: [String: Int] = [:]
        for (i, name) in OPZ.components.enumerated() where (mask >> i) & 1 == 1 {
            components[name] = Int(bytes[at + 2 + i])
        }
        for (i, name) in OPZ.params.enumerated() where bytes[at + 36 + i] != 0 {
            locks[name] = Int(bytes[at + 18 + i])
        }
        return Step(mask: mask, components: components, locks: locks)
    }

    /// What a step holds, at a glance: how many notes, the loudest, the lowest and highest, whether it has components or
    /// locks. Nothing is allocated: a whole pattern is looked over at every edit.
    public func brief(_ p: Int, _ t: Int, _ s: Int) -> (notes: Int, velocity: Int, low: Int, high: Int, component: Bool, lock: Bool) {
        Self.check(p, t, s)
        return bytes.withUnsafeBufferPointer { b in
            var n = 0, velocity = 0, low = 255, high = 0
            var at = p * OPZ.patternSize + OPZ.notesAt + (s * OPZ.slotsPerStep + OPZ.noteOffsets[t]) * 8
            for _ in 0..<OPZ.notesPerStep[t] {
                let note = Int(b[at + 4])
                if note != 0xFF { n += 1; velocity = max(velocity, Int(b[at + 5])); low = min(low, note); high = max(high, note) }
                at += 8
            }
            let st = p * OPZ.patternSize + OPZ.stepsAt + (t * OPZ.steps + s) * OPZ.stepRecord
            let mask = Int(b[st]) | Int(b[st + 1]) << 8
            var lock = false
            for i in 0..<OPZ.params.count where b[st + 36 + i] != 0 { lock = true; break }
            return (n, velocity, low, high, mask & (1 << OPZ.components.count - 1) != 0, lock)
        }
    }

    /// The track's 18 sound bytes (P1, P2, envelope, FX sends, filter, … in `OPZ.params` order).
    public func sound(_ p: Int, _ t: Int) -> [Int] {
        Self.check(p, t)
        let at = p * OPZ.patternSize + OPZ.soundAt + t * OPZ.params.count
        return bytes[at..<at + OPZ.params.count].map(Int.init)
    }

    public func muteGroup(_ p: Int) -> Int {
        Self.check(p)
        return Int(bytes[p * OPZ.patternSize + OPZ.muteGroupAt])
    }

    public func muted(_ p: Int, _ t: Int, group: Int? = nil) -> Bool {
        Self.check(p, t)
        let g = min(group ?? muteGroup(p), 9)
        return (bytes[p * OPZ.patternSize + OPZ.mutesAt + g * 4 + (t >> 2)] >> ((t % 4) * 2 + 1)) & 1 == 1
    }

    /// The other kind of mute: the track's notes go on, its sound does not (the two bits are 1; for `muted` they are 2. OS 1.2.45:
    /// 0x80108528 sets them, 0x80108644 takes the sound away at 1, 0x8010d0c6 plays no notes at 2).
    public func audioMuted(_ p: Int, _ t: Int, group: Int? = nil) -> Bool {
        Self.check(p, t)
        let g = min(group ?? muteGroup(p), 9)
        return (bytes[p * OPZ.patternSize + OPZ.mutesAt + g * 4 + (t >> 2)] >> ((t % 4) * 2)) & 3 == 1
    }

    /// The OP-Z plays and lights a pattern only when this bit is set.
    public func patternInUse(_ p: Int) -> Bool {
        Self.check(p)
        return u16(p * OPZ.patternSize + OPZ.masterAt) & OPZ.inUseBit != 0
    }

    public func patternHasNotes(_ p: Int) -> Bool {
        Self.check(p)
        let base = p * OPZ.patternSize + OPZ.notesAt
        for n in 0..<(OPZ.steps * OPZ.slotsPerStep) where bytes[base + n * 8 + 4] != 0xFF { return true }
        return false
    }
}

/// The project-global block (StateSync `$0C`): chains, levels, tempo, swing, metronome.
public struct GlobalBlock: Equatable, Sendable {
    public let bytes: [UInt8]

    public init?(_ bytes: [UInt8]) {
        guard bytes.count == OPZ.globalSize else { return nil }
        self.bytes = bytes
    }

    public var tempo: Int { Int(bytes[OPZ.tempoAt]) | Int(bytes[OPZ.tempoAt + 1]) << 8 }
    public var swing: Int { Int(bytes[OPZ.swingAt]) }
}
