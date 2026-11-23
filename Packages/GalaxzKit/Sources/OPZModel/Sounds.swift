import Foundation

/// One community engine from op-free's catalogue (`Resources/OPFree/engines.json`, made by `Tools/fixtures`).
public struct EngineInfo: Decodable, Sendable, Equatable {
    public struct Knob: Decodable, Sendable, Equatable {
        public let name: String
        public let help: String?
    }

    public let dir: String
    public let label: String
    /// synth, drum or fx
    public let kind: String
    public let plug: Int
    public let summary: String?
    public let p1: Knob?
    public let p2: Knob?
    public let presets: [String]
}

public enum EngineCatalogue {
    /// Every op-free engine by plug id.
    public static let byPlug: [Int: EngineInfo] = {
        struct File: Decodable { let engines: [EngineInfo] }
        guard let url = Bundle.module.url(forResource: "engines", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [:] }
        return Dictionary(file.engines.map { ($0.plug, $0) }, uniquingKeysWith: { first, _ in first })
    }()
}

/// The OP-Z's sound settings: `settings/plugs.json` (every sound it has) and `settings/slotConfiguration.json`
/// (which sound sits in which of the 10 slots of each track), as its file service serves them.
public struct OPZSettings: Sendable, Equatable {
    public struct Plug: Decodable, Sendable, Equatable {
        public let id: Int
        public let engine: String
        public let samples: String
        public let flags: Int
        public let version: Int
    }

    public let plugs: [Int: Plug]
    /// track → slot (1…10) → plug id
    public let slots: [Int: [Int: Int]]

    public init?(plugsJSON: [UInt8], slotsJSON: [UInt8]) {
        struct PlugsFile: Decodable { let plugs: [Plug] }
        struct SlotsFile: Decodable {
            struct Track: Decodable { let index: Int; let packs: [Pack] }
            struct Pack: Decodable { let id: Int; let slot: Int }
            let tracks: [Track]
        }
        let decoder = JSONDecoder()
        guard let p = try? decoder.decode(PlugsFile.self, from: Data(plugsJSON)),
              let s = try? decoder.decode(SlotsFile.self, from: Data(slotsJSON)) else { return nil }
        plugs = Dictionary(p.plugs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        slots = Dictionary(s.tracks.map { t in (t.index, Dictionary(t.packs.map { ($0.slot, $0.id) },
                                                                      uniquingKeysWith: { first, _ in first })) },
                           uniquingKeysWith: { first, _ in first })
    }

    /// The slot key (1…10) a sound sits on in a track, if it is in one.
    public func slot(of plug: Int, track: Int) -> Int? {
        slots[track]?.filter { $0.value == plug }.keys.min()
    }
}

/// A track's sound, named for people: a community engine by its name, a sample pack by its pack, a TE sound by its
/// engine.
public struct Sound: Sendable, Equatable {
    public enum Origin: Sendable, Equatable { case community, teenageEngineering, samples, unknown }

    public let plug: Int
    public let name: String
    public let origin: Origin
    public let engine: EngineInfo?

    public var p1: String { engine?.p1?.name ?? "P1" }
    public var p2: String { engine?.p2?.name ?? "P2" }

    /// The sound of a plug id (a track record's active plug); nil for 0, an empty track.
    public init?(plug: Int, settings: OPZSettings?) {
        guard plug != 0 else { return nil }
        self.plug = plug
        if let e = EngineCatalogue.byPlug[plug] {
            name = e.label.uppercased()
            origin = .community
            engine = e
        } else if let p = settings?.plugs[plug] {
            engine = nil
            if !p.samples.isEmpty {
                name = Self.words(Self.base(p.samples))
                origin = .samples
            } else {
                // perform, module and lights name no engine file: a sound built into the OS
                let base = Self.base(p.engine)
                name = base.isEmpty ? "BUILT-IN" : base.uppercased()
                origin = .teenageEngineering
            }
        } else {
            name = "PLUG \(plug)"
            origin = .unknown
            engine = nil
        }
    }

    /// "samplepacks/AlainKicks.aif" → "AlainKicks"
    static func base(_ path: String) -> String {
        let file = path.split(separator: "/").last.map(String.init) ?? path
        return file.split(separator: ".").first.map(String.init) ?? file
    }

    /// "AlainKicks" → "ALAIN KICKS", "zVinyl" → "Z VINYL"
    static func words(_ name: String) -> String {
        var out = ""
        var previous: Character?
        for c in name {
            if let p = previous, c.isUppercase, p.isLowercase || p.isNumber { out.append(" ") }
            out.append(c)
            previous = c
        }
        return out.uppercased()
    }
}
