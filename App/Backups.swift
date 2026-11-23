import CryptoKit
import Foundation

/// Copies of everything on the OP-Z that a factory reset or a bad flash could take: the ten projects and the sound
/// settings (taken by Galax-z at every connection, read-only), and the OS files the hub saves before every flash.
///
/// `Documents/Backups/` — in the Files app on the iPad (Galax-z › Backups), in the app's Documents on the Mac. Each
/// content backup is a folder named by its time, laid out like the OP-Z's own disk (`projects/project01.opz`,
/// `settings/plugs.json`…), so putting one back is a copy in content mode (hold TRACK while switching on).
enum Backups {
    struct Manifest: Codable, Sendable {
        var taken: Date
        var checked: Date            // the last time the OP-Z still matched this backup
        var device: String?
        var files: [String: String]  // path -> sha256
    }

    static let keep = 30

    static var root: URL {
        #if DEBUG
        if let s = SelfTest.scratch { return s.appending(path: "Backups") }
        #endif
        return documents
    }
    private static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(path: "Backups")
    }
    static var content: URL { root.appending(path: "content") }
    static var os: URL { root.appending(path: "os") }

    /// Save a complete content backup; if nothing changed since the newest one, only mark that one as checked.
    @discardableResult
    static func save(_ files: [String: [UInt8]], device: String?, now: Date = Date()) throws -> (folder: URL, new: Bool) {
        let hashes = files.mapValues { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }
        let fm = FileManager.default
        if let (folder, found) = latest(), found.files == hashes {
            var manifest = found
            manifest.checked = now
            try write(manifest, to: folder)
            return (folder, false)
        }
        let folder = content.appending(path: stamp(now))
        for (path, data) in files {
            let url = folder.appending(path: path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(data).write(to: url, options: .atomic)
        }
        try write(Manifest(taken: now, checked: now, device: device, files: hashes), to: folder)
        prune()
        return (folder, true)
    }

    /// The newest complete content backup.
    static func latest() -> (URL, Manifest)? { all().first }

    static func all() -> [(URL, Manifest)] {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return ((try? FileManager.default.contentsOfDirectory(at: content, includingPropertiesForKeys: nil)) ?? [])
            .compactMap { folder in
                guard let d = try? Data(contentsOf: folder.appending(path: "manifest.json")),
                      let m = try? dec.decode(Manifest.self, from: d) else { return nil }
                return (folder, m)
            }
            .sorted { $0.1.taken > $1.1.taken }
    }

    /// A folder for the hub's OS backup and log of one run.
    static func osRun(_ now: Date = Date()) -> URL {
        let url = os.appending(path: "flash-\(stamp(now))")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func prune() {
        for (folder, _) in all().dropFirst(keep) { try? FileManager.default.removeItem(at: folder) }
    }

    private static func write(_ m: Manifest, to folder: URL) throws {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(m).write(to: folder.appending(path: "manifest.json"), options: .atomic)
    }

    private static func stamp(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return f.string(from: d)
    }
}
