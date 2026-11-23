import Foundation

/// TE's 1.2.45 `os.ldr` as installed on the OP-Z: every build starts from it.
public enum Original {
    public static let firmware = "1.2.45", size = 828_136, crc32: UInt32 = 2_403_806_141
    public static let sha256 = "5be99760c8797bdd4797ed20cfb9a92b6588889d3a81109bae5a45646a9bde07"

    public static func matches(_ d: [UInt8]) -> Bool { d.count == size && Hash.sha256(d) == sha256 }
}

/// Something that can go on the OP-Z: the original, or a build of patch records.
public struct FirmwareImage: Sendable, Identifiable {
    public let label, title, description: String
    public let patches: [String]
    public let ldr: [UInt8]?          // nil: not flashable (see reason)
    public let reason: String
    public var id: String { label }

    public var crcText: [UInt8] { Array(String(Hash.crc32(ldr ?? [])).utf8) }
    /// os.crc32 first (10 bytes: the tripwire for the frame format), then os.ldr.
    public var files: [(name: String, data: [UInt8])] { ldr.map { [("os.crc32", crcText), ("os.ldr", $0)] } ?? [] }
}

/// The builds and patch records shipped with the app (copies of Firmware/builds and Firmware/patches).
public struct Catalog: Sendable {
    public struct Build: Codable, Sendable { public let title: String; public let description: String?; public let patches: [String]
        /// What is new, a line each, for people.
        public var notes: [String]? }

    public let builds: [(label: String, build: Build)]
    public let records: [String: PatchRecord]
    /// The image a signed release promised (its SHA-256), by label: what its records make must be exactly that.
    public let promised: [String: String]

    public init(builds: [(String, Build)], records: [String: PatchRecord], promised: [String: String] = [:]) {
        self.promised = promised
        // by number, so v10 comes after v9
        func order(_ l: String) -> (Int, String) { (Self.number(of: l) ?? 0, l) }
        self.builds = builds.sorted { order($0.0) < order($1.0) }.map { (label: $0.0, build: $0.1) }
        self.records = records
    }

    /// The catalog in this package's resources.
    public static var bundledRoot: URL? { Bundle.module.url(forResource: "firmware", withExtension: nil) }

    public static func bundled() throws -> Catalog {
        guard let root = bundledRoot else { throw PatchError(description: "no firmware folder in the app") }
        return try load(root)
    }

    public static func load(_ root: URL) throws -> Catalog {
        let fm = FileManager.default, dec = JSONDecoder()
        func jsons(_ dir: String) throws -> [(String, Data)] {
            try fm.contentsOfDirectory(at: root.appending(path: dir), includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
                .map { ($0.lastPathComponent, try Data(contentsOf: $0)) }
        }
        let records = try Dictionary(uniqueKeysWithValues: jsons("patches").map { ($0.0, try dec.decode(PatchRecord.self, from: $0.1)) })
        let builds = try jsons("builds").map { (String($0.0.dropLast(5)), try dec.decode(Build.self, from: $0.1)) }
        return Catalog(builds: builds, records: records)
    }

    public func images(original: [UInt8]) throws -> [FirmwareImage] {
        guard Original.matches(original) else { throw PatchError(description: "that is not TE's 1.2.45 os.ldr") }
        var out = [FirmwareImage(label: "original", title: "TE 1.2.45 (original)",
                                 description: "What teenage engineering ships. The way back.", patches: [], ldr: original, reason: "")]
        for (label, b) in builds {
            do {
                let recs = try b.patches.map { name in
                    guard let r = records[name] else { throw PatchError(description: "missing record \(name)") }
                    return r
                }
                let made = try Patcher.apply(original, recs)
                if let p = promised[label], Hash.sha256(made) != p { throw PatchError(description: "its records do not make the image its release promises") }
                out.append(FirmwareImage(label: label, title: b.title, description: b.description ?? "", patches: b.patches, ldr: made, reason: ""))
            } catch {
                out.append(FirmwareImage(label: label, title: b.title, description: b.description ?? "", patches: b.patches,
                                         ldr: nil, reason: "\(error)"))
            }
        }
        return out
    }

    /// TE's original out of whatever known image is installed (the original itself, or any build of ours).
    public func recoverOriginal(from installed: [UInt8]) -> [UInt8]? {
        if Original.matches(installed) { return installed }
        for (_, b) in builds {
            let recs = b.patches.compactMap { records[$0] }
            if recs.count == b.patches.count, let d = Patcher.unapply(installed, recs), Original.matches(d) { return d }
        }
        return originalUnderPlayer(installed)
    }

    /// The builds that carry the animation player, Galax-z v2 first.
    public var playerBuilds: [(label: String, build: Build)] { builds.filter { Self.playerRecord(in: $0.build) != nil } }

    /// A build's own player record: a release's records have its label in front.
    static func playerRecord(in b: Build) -> String? { b.patches.first { $0.split(separator: "/").last.map(String.init) == galaxyRecord } }

    /// TE's original out of a player build (Galax-z v2, v3 …) playing any frames at all (an animation this app has since
    /// changed), and which build. Strict: the player's code must be ours byte for byte and, with it and the build's other
    /// blocks and edits taken out, what is left must be TE's 1.2.45 by SHA-256. Only the frames' data may differ.
    public func underPlayer(_ installed: [UInt8]) -> (label: String, original: [UInt8])? {
        guard let blocks = try? LDR.parse(installed) else { return nil }
        for (label, build) in playerBuilds {
            guard let name = Self.playerRecord(in: build), let player = records[name], let block = player.blocks?.first, player.blocks?.count == 1,
                  let data = try? Patcher.bytes(block.data), let target = try? Patcher.number(block.target),
                  let code = data.firstRange(of: Self.framesMarker)?.upperBound,
                  let b = blocks.last(where: { UInt64($0.target) == target && Int($0.count) == data.count }) else { continue }
            let there = Array(installed[b.dataOffset..<b.dataOffset + data.count])
            guard there[..<code] == data[..<code],
                  let now = try? build.patches.map({ $0 == name ? swapped(player, block, there) : try record($0) }) else { continue }
            // each combination of our blocks, as they are or as they were
            let all = now.reduce([[PatchRecord]]([[]])) { sets, r in sets.flatMap { set in r.versions.map { set + [$0] } } }
            for recs in all {
                if let d = Patcher.unapply(installed, recs), Original.matches(d) { return (label, d) }
            }
        }
        return nil
    }

    public func originalUnderPlayer(_ installed: [UInt8]) -> [UInt8]? { underPlayer(installed)?.original }

    private func swapped(_ player: PatchRecord, _ block: PatchRecord.Block, _ blob: [UInt8]) -> PatchRecord {
        PatchRecord(name: player.name, status: player.status, description: player.description, source: player.source, edits: player.edits,
                    blocks: [.init(what: block.what, target: block.target, source: block.source,
                                   data: blob.map { String(format: "%02x", $0) }.joined(), sha256: Hash.sha256(blob))])
    }

    /// What is on the OP-Z, by name; a player build with frames this app does not have is named too, not "unknown".
    public func name(_ images: [FirmwareImage], ldr: [UInt8]?, crc: [UInt8]?) -> String {
        let found = Self.identify(images, ldr: ldr, crc: crc)
        guard found.hasPrefix("unknown"), let label = ldr.flatMap(underPlayer)?.label else { return found }
        return "\(label) (another animation)"
    }

    public static func identify(_ images: [FirmwareImage], ldr: [UInt8]?, crc: [UInt8]?) -> String {
        guard let ldr else { return "no os.ldr" }
        if let im = images.first(where: { $0.ldr == ldr }) {
            let crcOK = crc.map { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
                == String(decoding: im.crcText, as: UTF8.self)
            return im.label + (crcOK ? "" : " (os.crc32 does not match it)")
        }
        return "unknown os.ldr (\(ldr.count) bytes, sha256 \(Hash.sha256(ldr).prefix(16))…)"
    }
}

/// What a flash or a check did.
public struct FlashReport: Sendable {
    public var installedBefore: String
    public var backup: [(name: String, data: [UInt8])]
}

extension UpdateConsole {
    public func readInstalled() throws -> (ldr: [UInt8]?, crc: [UInt8]?) {
        let crc = try readFile("os.crc32")
        let ldr = try readFile("os.ldr")
        return (ldr, crc)
    }

    /// Write an image's os.crc32 then os.ldr, reading each back byte for byte. `saveBackup` gets what is installed before
    /// anything is written; if it throws, nothing is written.
    public func flash(_ image: FirmwareImage, all images: [FirmwareImage],
                      saveBackup: ([(name: String, data: [UInt8])]) throws -> Void = { _ in },
                      name: (_ ldr: [UInt8]?, _ crc: [UInt8]?) -> String? = { _, _ in nil },
                      progress: (@Sendable (String, Int, Int) -> Void)? = nil) throws -> FlashReport {
        guard image.ldr != nil else { throw ConsoleError.refused("\(image.label) is not flashable: \(image.reason)") }
        try start()
        log("backing up what is installed")
        let (ldr, crc) = try readInstalled()
        let found = name(ldr, crc) ?? Catalog.identify(images, ldr: ldr, crc: crc)
        log("installed: \(found)")
        if found.hasPrefix("unknown") || found.hasPrefix("no os.ldr"), image.label != "original" {
            throw ConsoleError.refused("this app does not know the OS on the OP-Z. It may be older than what was flashed: rebuild it "
                                       + "(./run-mac.sh). Otherwise only `original` may be written over it")
        }
        let backup = [("os.crc32", crc), ("os.ldr", ldr)].compactMap { n, d in d.map { (name: n, data: $0) } }
        try saveBackup(backup)
        for (name, data) in image.files {
            try writeFile(name, data) { progress?(name, $0, $1) }
            guard try readFile(name) == data else {
                throw ConsoleError.refused("\(name) read back DIFFERENT. Don't switch on normally: flash `original`")
            }
            log("  \(name) read back identical")
        }
        log("done: \(image.title) is on the OP-Z. Switch it off and on to start it")
        return FlashReport(installedBefore: found, backup: backup)
    }
}

// MARK: - boot animations

extension Catalog {
    public static let galaxyRecord = "galaxy-boot.json"
    static let framesMarker = Array("GALAXZ-GALAXY-2\0".utf8)

    /// Galax-z v2's records with another animation of the library: the galaxy player as shipped, its frames replaced.
    /// Only data changes (240 frames × 53 LEDs × RGBW); the code on the OP-Z is the same, byte for byte.
    public func bootRecords(_ animation: LEDAnimation, layout: LEDLayout, on label: String = "galaxz-v2") throws -> (build: Build, records: [PatchRecord]) {
        guard let base = playerBuilds.first(where: { $0.label == label }), let name = Self.playerRecord(in: base.build),
              let player = records[name], let block = player.blocks?.first else {
            throw PatchError(description: "no animation player in \(label)")
        }
        let data = try Patcher.bytes(block.data)
        guard let at = data.firstRange(of: Self.framesMarker)?.upperBound else {
            throw PatchError(description: "the galaxy player has no frames marker")
        }
        let frames = animation.bytes(layout)
        guard data.count - at == frames.count else { throw PatchError(description: "the player plays \(data.count - at) bytes of frames") }
        let blob = Array(data[..<at]) + frames
        return (base.build, try base.build.patches.map { $0 == name ? swapped(player, block, blob) : try record($0) })
    }

    /// A player build (Galax-z v2, or v3 with the A/B bars) playing `animation` after boot.
    public func bootImage(original: [UInt8], _ animation: LEDAnimation, layout: LEDLayout, on label: String = "galaxz-v2") throws -> FirmwareImage {
        let (build, recs) = try bootRecords(animation, layout: layout, on: label)
        return FirmwareImage(label: "\(label.replacingOccurrences(of: "galaxz-", with: ""))-\(animation.id)", title: "\(build.title) · \(animation.name)", description: animation.blurb,
                             patches: build.patches, ldr: try Patcher.apply(original, recs), reason: "")
    }

    /// The frames Galax-z v2 is playing on an OP-Z (nil unless it is ours, checked as `originalUnderPlayer` does).
    public func frames(playedBy installed: [UInt8]) -> [UInt8]? {
        guard let label = underPlayer(installed)?.label, let build = playerBuilds.first(where: { $0.label == label })?.build,
              let block = Self.playerRecord(in: build).flatMap({ records[$0] })?.blocks?.first,
              let target = try? Patcher.number(block.target), let b = try? LDR.parse(installed).last(where: { UInt64($0.target) == target })
        else { return nil }
        let there = Array(installed[b.dataOffset..<b.dataOffset + Int(b.count)])
        return there.firstRange(of: Self.framesMarker).map { Array(there[$0.upperBound...]) }
    }

    func record(_ name: String) throws -> PatchRecord {
        guard let r = records[name] else { throw PatchError(description: "missing record \(name)") }
        return r
    }
}
