import Foundation
import OPZModel

/// What has been heard from the OP-Z on this connection: a check for each thing the screen follows, and a report to send to whoever
/// looks into what is missing. It listens only.
public struct LinkCheck: Sendable {
    /// What the screen follows, and what to do on the OP-Z to hear it.
    public enum Item: Int, CaseIterable, Sendable {
        case session, project, sounds, transport, position, page, dials, edits, mixer, notes, clock, machines

        public var name: String {
            ["ANSWERS", "PROJECT", "SOUNDS", "TRACK AND PLAY", "POSITION", "PAGES", "DIALS", "EDITS", "MIXER", "NOTES", "CLOCK", "TUMBLER AND EUCLID"][rawValue]
        }
        public var how: String {
            ["plug it in, with TE's app closed", "comes by itself", "comes by itself", "choose another track, press play", "press play", "press SHIFT to turn the page",
             "turn a dial", "add a step", "hold MIXER and turn a dial", "play a key", "press play (needs MIDI clock out switched on)", "Galax-z OS v10 tells of them"][rawValue]
        }
        /// Not every OP-Z sends these.
        public var optional: Bool { self == .clock || self == .machines }
    }

    public struct Message: Equatable, Sendable {
        public var count = 0
        public var first = 0.0, last = 0.0
        public var shortest = Int.max, longest = 0
        /// The first few payloads, cut short.
        public var samples: [[UInt8]] = []
    }

    static let samplesKept = 3, sampleBytes = 48

    public private(set) var messages: [UInt8: Message] = [:]
    /// Notes by channel.
    public private(set) var channels = [Int](repeating: 0, count: 16)
    /// CCs, by channel and number.
    private var ccs: [String: Int] = [:]
    public private(set) var notes = 0, clocks = 0, starts = 0, stops = 0, broken = 0
    private var filesDone = false
    /// How long notes waited between the driver and the screen, and frames between being drawn for a moment and shown: milliseconds.
    private var waits: [Double] = [], shows: [Double] = []

    public init() {}

    /// A SysEx from the OP-Z.
    public mutating func heard(_ raw: [UInt8], at t: Double) {
        guard let f = try? SysEx.decode(raw) else { broken += 1; return }
        var m = messages[f.id] ?? Message(first: t)
        m.count += 1
        m.last = t
        m.shortest = min(m.shortest, f.payload.count)
        m.longest = max(m.longest, f.payload.count)
        if m.samples.count < Self.samplesKept {
            let s = Array(f.payload.prefix(Self.sampleBytes))
            if !m.samples.contains(s) { m.samples.append(s) }
        }
        messages[f.id] = m
    }

    public mutating func heard(_ e: KeyEvent) {
        switch e {
        case .noteOn(_, let ch, _, _):
            notes += 1
            if channels.indices.contains(ch) { channels[ch] += 1 }
        case .noteOff: break
        case .cc(let n, _, let ch): if ccs.count < 400 { ccs["\(ch + 1)/\(n)", default: 0] += 1 }
        case .clock: clocks += 1
        case .playing(let on, _): if on { starts += 1 } else { stops += 1 }
        }
    }

    public mutating func late(_ seconds: Double) { Self.keep(seconds, in: &waits) }
    public mutating func shown(_ seconds: Double) { Self.keep(seconds, in: &shows) }
    private static func keep(_ s: Double, in a: inout [Double]) {
        guard s.isFinite, abs(s) < 1 else { return }
        a.append(s * 1000)
        if a.count > 400 { a.removeFirst(200) }
    }
    private static func spread(_ a: [Double]) -> String {
        let s = a.sorted()
        return s.isEmpty ? "not measured" : String(format: "%.1f ms, 19 of 20 under %.1f, worst %.1f", s[s.count / 2], s[min(s.count - 1, s.count * 19 / 20)], s.last!)
    }

    /// The sounds were read whole.
    public mutating func gotSounds() { filesDone = true }

    /// How often something came; 0: not yet.
    public func count(_ item: Item) -> Int {
        func n(_ ids: UInt8...) -> Int { ids.reduce(0) { $0 + (messages[$1]?.count ?? 0) } }
        switch item {
        case .session: return n(0x01)
        case .project: return n(0x0A)
        case .sounds: return filesDone ? 1 : 0
        case .transport: return n(0x03)
        case .position: return n(0x05)
        case .page: return n(0x06)
        case .dials: return n(0x0E)
        case .edits: return n(0x02)
        case .mixer: return n(0x12)
        case .notes: return notes
        case .clock: return clocks
        case .machines: return n(0x70, 0x71)
        }
    }

    public var missing: [Item] { Item.allCases.filter { !$0.optional && count($0) == 0 } }

    private static let names: [UInt8: String] = [0x01: "session ack", 0x02: "edit", 0x03: "track, play", 0x04: "synth state", 0x05: "position", 0x06: "page, held step", 0x07: "play state",
                                                 0x09: "bank part", 0x0A: "bank, last part", 0x0C: "global block", 0x0E: "sound", 0x10: "0x10", 0x12: "mixer gains", 0x13: "pattern state",
                                                 0x1B: "meters", 0x34: "files: open", 0x53: "files: part", 0x70: "Galax-z machines", 0x71: "Galax-z balls", 0x72: "Galax-z groove page"]

    /// The report as text. The samples are of the messages themselves; parts of the project and of files are left out.
    public func text(device: String, over: String, seconds: Double, banksRead: Int, refetches: Int, also: [String] = [], tracks: [String] = []) -> String {
        var out = ["Galax-z link check", "\(device) over \(over), \(Int(seconds)) s" + (also.isEmpty ? "" : ", " + also.joined(separator: ", ")),
                   "project read \(banksRead) times, \(refetches) of them because an edit could not be followed; \(broken) broken messages", ""]
        for i in Item.allCases {
            let n = count(i)
            out.append((n > 0 ? "[x] " : i.optional ? "[-] " : "[ ] ") + i.name.padding(toLength: 20, withPad: " ", startingAt: 0) + (n > 0 ? "\(n)" : i.how))
        }
        out += ["", "MIDI: \(notes) notes, \(starts) starts, \(stops) stops, \(clocks) clock ticks"]
        if notes > 0 { out.append("by channel: " + channels.indices.filter { channels[$0] > 0 }.map { "\($0 + 1): \(channels[$0])" }.joined(separator: ", ")) }
        if !ccs.isEmpty { out.append("CCs (channel/number: times): " + ccs.sorted { $0.key.compare($1.key, options: .numeric) == .orderedAscending }.map { "\($0.key): \($0.value)" }.joined(separator: ", ")) }
        out += ["a note waited for the screen: \(Self.spread(waits))", "a frame was shown after its moment: \(Self.spread(shows))"]
        out += (tracks.isEmpty ? [] : [""] + tracks) + [""]
        for (id, m) in messages.sorted(by: { $0.key < $1.key }) {
            let span = m.last - m.first, rate = m.count > 1 && span > 0 ? String(format: ", %.1f a second", Double(m.count - 1) / span) : ""
            let size = m.shortest == m.longest ? "\(m.longest)" : "\(m.shortest)-\(m.longest)"
            out.append(String(format: "$%02x ", id) + (Self.names[id] ?? "NOT KNOWN") + ": \(m.count), \(size) bytes\(rate)")
            guard ![0x09, 0x0A, 0x0C, 0x34, 0x53].contains(id) else { continue }
            for s in m.samples { out.append("      " + s.map { String(format: "%02x", $0) }.joined(separator: " ") + (s.count == Self.sampleBytes ? " …" : "")) }
        }
        return out.joined(separator: "\n") + "\n"
    }
}
