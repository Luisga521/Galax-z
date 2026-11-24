#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto        // swift-crypto: the same API, on Windows and Linux
#endif
import Foundation

/// A Galax-z OS release, as it travels: one file (`.galaxz`), signed. It holds a build and its patch records (addresses, the
/// bytes expected there, ours) and says exactly which image they make from TE's 1.2.45, which every OP-Z's owner reads off
/// their own unit. Of TE's it holds only the few bytes each edit replaces.
///
/// What is refused: a signature by another key, a file that is not a build or a record, a draft record, a build whose image
/// is not the one promised byte for byte.
public struct Release: Codable, Sendable, Equatable, Identifiable {
    public static let format = 1

    public let format: Int
    /// Counts up; the newest wins. Galax-z v9 is 9.
    public let number: Int
    public let label: String                 // galaxz-v9, the build's name
    public let title: String
    public let date: String                  // 2026-11-22
    public let notes: [String]               // what is new, a line each
    public let firmware: String              // 1.2.45: the OS it is made from
    public let imageSHA256: String
    public let imageSize: Int
    public let build: String                 // builds/<label>.json as text
    public let patches: [String: String]     // patches/<name>.json as text

    public var id: String { label }

    public init(number: Int, label: String, title: String, date: String, notes: [String], image: [UInt8], build: String, patches: [String: String]) {
        format = Self.format
        (self.number, self.label, self.title, self.date, self.notes) = (number, label, title, date, notes)
        firmware = Original.firmware
        imageSHA256 = Hash.sha256(image)
        imageSize = image.count
        (self.build, self.patches) = (build, patches)
    }

    /// Its build and records, checked as far as they can be without TE's image. The records are kept apart from other
    /// builds' of the same name ("galaxz-v9/meter.json").
    public func parts() throws -> (build: Catalog.Build, records: [String: PatchRecord]) {
        guard format == Self.format else { throw ReleaseError("made for a newer Galax-z app (format \(format))") }
        guard firmware == Original.firmware else { throw ReleaseError("made for OP-Z OS \(firmware), not \(Original.firmware)") }
        guard Self.isName(label), number > 0, label == "galaxz-v\(number)", (1...1_000_000_000).contains(imageSize) else { throw ReleaseError("not a Galax-z release") }
        let dec = JSONDecoder()
        guard let b = try? dec.decode(Catalog.Build.self, from: Data(build.utf8)), !b.patches.isEmpty else { throw ReleaseError("its build is not readable") }
        guard Set(b.patches) == Set(patches.keys), b.patches.count == patches.count else { throw ReleaseError("its build and its records do not match") }
        var records: [String: PatchRecord] = [:]
        for (name, text) in patches {
            guard name.hasSuffix(".json"), Self.isName(String(name.dropLast(5))), let r = try? dec.decode(PatchRecord.self, from: Data(text.utf8)) else {
                throw ReleaseError("a record is not readable: \(name.prefix(40))")
            }
            guard !r.isDraft else { throw ReleaseError("a record is a draft: \(name)") }
            guard r.source.sha256 == Original.sha256 else { throw ReleaseError("a record is not for TE's \(Original.firmware): \(name)") }
            records["\(label)/\(name)"] = r
        }
        return (Catalog.Build(title: b.title, description: b.description, patches: b.patches.map { "\(label)/\($0)" }), records)
    }

    /// The image it makes, which must be the one it promises.
    public func image(original: [UInt8]) throws -> [UInt8] {
        let (b, records) = try parts()
        guard Original.matches(original) else { throw ReleaseError("that is not TE's \(Original.firmware)") }
        let d = try Patcher.apply(original, b.patches.map { records[$0]! })
        guard d.count == imageSize, Hash.sha256(d) == imageSHA256 else { throw ReleaseError("its records do not make the image it promises") }
        return d
    }

    static func isName(_ s: String) -> Bool {
        (1...48).contains(s.count) && s.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-") } && s.first != "-"
    }
}

public struct ReleaseError: Error, CustomStringConvertible, Equatable {
    public let description: String
    public init(_ d: String) { description = d }
}

/// What is signed, and by whom.
public struct SignedRelease: Codable, Sendable {
    public let payload: Data
    public let signature: Data
    public let key: String              // the public key's first 8 hex digits, to say which

    public init(_ release: Release, key k: Curve25519.Signing.PrivateKey) throws {
        payload = try Self.encoder.encode(release)
        signature = try k.signature(for: Self.signed(payload))
        key = ReleaseKeys.name(k.publicKey.rawRepresentation)
    }

    /// The release, if one of these keys signed it.
    public func open(_ keys: [Data] = ReleaseKeys.trusted) throws -> Release {
        guard payload.count < 8_000_000 else { throw ReleaseError("too big") }
        let good = keys.contains { raw in
            (try? Curve25519.Signing.PublicKey(rawRepresentation: raw))?.isValidSignature(signature, for: Self.signed(payload)) ?? false
        }
        guard good else { throw ReleaseError("not signed by Galax-z (key \(key.prefix(16)))") }
        guard let r = try? JSONDecoder().decode(Release.self, from: payload) else { throw ReleaseError("signed, but not a release this app can read") }
        _ = try r.parts()
        return r
    }

    public static func read(_ d: Data) throws -> SignedRelease {
        guard d.count < 16_000_000, let s = try? JSONDecoder().decode(SignedRelease.self, from: d) else { throw ReleaseError("not a Galax-z release file") }
        return s
    }

    public func file() throws -> Data { try Self.encoder.encode(self) }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }
    /// So a signature made for something else can never pass for a release's.
    private static func signed(_ d: Data) -> Data { Data("galaxz-release-1\0".utf8) + d }
}

/// Which releases there are: a small file beside them. Not signed: it can only point at releases, and each is checked by itself.
public struct ReleaseFeed: Codable, Sendable {
    public struct Entry: Codable, Sendable { public let number: Int; public let label, title, date, file: String
        public init(number: Int, label: String, title: String, date: String, file: String) {
            (self.number, self.label, self.title, self.date, self.file) = (number, label, title, date, file)
        }
    }
    public let releases: [Entry]
    public init(releases: [Entry]) { self.releases = releases }

    public static let defaultURL = URL(string: "https://raw.githubusercontent.com/Luisga521/Galax-z/main/Releases/feed.json")!

    /// Where an entry is, beside the feed; nil for anything that is not a plain file name.
    public static func url(of entry: Entry, feed: URL) -> URL? {
        guard entry.file.hasSuffix(".galaxz"), Release.isName(String(entry.file.dropLast(7))) else { return nil }
        return feed.deletingLastPathComponent().appending(path: entry.file)
    }
}

/// The releases on this device, downloaded or opened from a file. Every one is checked again each time they are read.
public struct ReleaseStore: Sendable {
    public let folder: URL
    let keys: [Data]
    public init(folder: URL, keys: [Data] = ReleaseKeys.trusted) { (self.folder, self.keys) = (folder, keys) }

    public func all() -> [Release] {
        ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "galaxz" }
            .compactMap { try? SignedRelease.read(Data(contentsOf: $0)).open(keys) }
            .sorted { $0.number > $1.number }
    }

    /// Check a release file and keep it.
    @discardableResult
    public func add(_ data: Data) throws -> Release {
        let r = try SignedRelease.read(data).open(keys)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: folder.appending(path: r.label + ".galaxz"), options: .atomic)
        return r
    }
}

extension Catalog {
    /// This catalogue with releases in it. A build the app already has stays the app's own.
    public func adding(_ releases: [Release]) -> Catalog {
        var builds = self.builds.map { ($0.label, $0.build) }, records = self.records, promised = self.promised
        for r in releases where !builds.contains(where: { $0.0 == r.label }) {
            guard let (b, rs) = try? r.parts() else { continue }
            builds.append((r.label, b))
            promised[r.label] = r.imageSHA256
            records.merge(rs) { mine, _ in mine }
        }
        return Catalog(builds: builds, records: records, promised: promised)
    }

    /// A version without its chime: "galaxz-v11-quiet".
    public static let quiet = "-quiet"

    /// Galax-z v9 → 9, and v11 without its chime 11; nil for anything else.
    public static func number(of label: String) -> Int? {
        label.hasPrefix("galaxz-v") ? Int(label.dropFirst(8).prefix { $0 != "-" }).flatMap { label.hasSuffix(quiet) || !label.dropFirst(8).contains("-") ? $0 : nil } : nil
    }
}
