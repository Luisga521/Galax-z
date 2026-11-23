/// One record of a StateSync `$02`: an edit made on the OP-Z. Read in the OS (1.2.45: the writers at 0x80113790 …
/// 0x80113bbc) and checked against 312 edits recorded on a unit (2026-11-21):
///
///     u16 timestamp, counting up by one · u16 offset · u8 pattern address · u8 length · u8 type · data
public struct PatternChange: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Type 0: bytes written at an offset of the pattern.
        case write(offset: Int, bytes: [UInt8])
        /// Type 5: a step's notes taken out.
        case clearStep(track: Int, step: Int)
        /// Type 2: the whole pattern became another one (copied, cleared, loaded); types 1, 3, 4, 6: a track, step or
        /// sound copied over. What it holds now has to be asked for.
        case replaced(type: UInt8)
    }

    public let timestamp: UInt16
    public let address: PatternAddress
    public let kind: Kind

    /// The records of a `$02` payload, in order; nil if it does not add up.
    public static func parse(_ p: [UInt8]) -> [PatternChange]? {
        var out: [PatternChange] = []
        var i = 0
        while i < p.count {
            guard i + 7 <= p.count else { return nil }
            let length = Int(p[i + 5]), type = p[i + 6], data = i + 7
            guard data + length <= p.count else { return nil }
            let kind: Kind
            switch type {
            case 0: kind = .write(offset: Int(p[i + 2]) | Int(p[i + 3]) << 8, bytes: Array(p[data..<data + length]))
            case 5 where length == 3 && p[data] < 16 && p[data + 1] < 16:
                kind = .clearStep(track: Int(p[data]), step: Int(p[data + 1]))
            default: kind = .replaced(type: type)
            }
            out.append(PatternChange(timestamp: UInt16(p[i]) | UInt16(p[i + 1]) << 8, address: PatternAddress(raw: Int(p[i + 4])), kind: kind))
            i = data + length
        }
        return out
    }
}

extension Bank {
    /// Make the edit; false when it cannot be made from the record alone (the bank has to be read again).
    public mutating func apply(_ change: PatternChange) -> Bool {
        let at = change.address.pattern * OPZ.patternSize
        switch change.kind {
        case .write(let offset, let data):
            guard offset + data.count <= OPZ.patternSize else { return false }
            bytes.replaceSubrange(at + offset..<at + offset + data.count, with: data)
        case .clearStep(let track, let step):
            for slot in 0..<OPZ.notesPerStep[track] {
                bytes[at + OPZ.notesAt + (step * OPZ.slotsPerStep + OPZ.noteOffsets[track] + slot) * 8 + 4] = 0xFF
            }
        case .replaced:
            return false
        }
        return true
    }

    /// A track's 18 sound bytes, as `$0E` brings them.
    public mutating func setSound(_ pattern: Int, _ track: Int, _ values: [UInt8]) {
        guard (0..<16).contains(pattern), (0..<16).contains(track), values.count == OPZ.params.count else { return }
        let at = pattern * OPZ.patternSize + OPZ.soundAt + track * OPZ.params.count
        bytes.replaceSubrange(at..<at + values.count, with: values)
    }
}
