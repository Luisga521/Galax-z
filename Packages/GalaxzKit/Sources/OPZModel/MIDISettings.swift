/// The OP-Z's MIDI settings (hold TEMPO + SCREEN; `midi.json`), as it answers `$0F` with `$10`: 292 bytes, zlib. Read only.
public struct MIDISettings: Equatable, Sendable {
    public static let size = 292
    /// Each track's MIDI is on; its channel, 0-15.
    public let enabled: [Bool]
    public let channels: [Int]
    public let flags: UInt8

    /// What comes on channel 1 goes to the selected track, not to the one whose channel it is.
    public var channelOneToActive: Bool { flags & 1 != 0 }
    public var incoming: Bool { flags & 2 != 0 }
    public var outgoing: Bool { flags & 4 != 0 }

    public init?(_ b: [UInt8]) {
        guard b.count == Self.size, b[..<32].allSatisfy({ $0 < 16 }) else { return nil }
        enabled = b[..<16].map { $0 != 0 }
        channels = b[16..<32].map(Int.init)
        flags = b[288]
    }

    /// The track that sends on a channel: of several, the one that is selected, else the first.
    public func track(channel: Int, selected: Int?) -> Int? {
        if let s = selected, channels.indices.contains(s), channels[s] == channel { return s }
        return channels.firstIndex(of: channel)
    }

    /// A message for a track, on the track's own channel. (Pattern changes and the like are for no track.)
    public func placed(_ c: OPZCommand) -> [UInt8] {
        var b = c.bytes
        guard !b.isEmpty, let t = c.track, channels.indices.contains(t) else { return b }
        b[0] = b[0] & 0xF0 | UInt8(channels[t])
        return b
    }

    /// In words, for the link check.
    public var lines: [String] {
        let names = [(1, "channel 1 to the selected track"), (2, "in"), (4, "out"), (8, "clock in"), (16, "clock out"), (32, "alt program change"), (64, "echo"), (128, "program change")]
        return ["MIDI settings on: " + names.filter { Int(flags) & $0.0 != 0 }.map(\.1).joined(separator: ", "),
                "tracks whose MIDI is off: " + (enabled.contains(false) ? enabled.indices.filter { !enabled[$0] }.map { "\($0 + 1) \(OPZ.trackNames[$0])" }.joined(separator: ", ") : "none"),
                "track channels: " + (channels == Array(0..<16) ? "1-16, each its own" : channels.enumerated().map { "\($0 + 1) on \($1 + 1)" }.joined(separator: ", "))]
    }
}
