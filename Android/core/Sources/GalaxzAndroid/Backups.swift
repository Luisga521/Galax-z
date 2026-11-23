import Foundation

/// The ten projects and the sound settings, read off the OP-Z: `App/Backups.swift` on Android, the same folders and
/// `manifest.json`, so a backup taken here goes back the same way (a copy in content mode). In
/// `Android/data/org.galaxz.app/files/Backups/content`, which a computer sees over USB.
enum Backups {
    struct Manifest: Codable, Sendable {
        var taken: Date
        var checked: Date            // the last time the OP-Z still matched this backup
        var device: String?
        var files: [String: String]  // path -> sha256
    }

    static let keep = 30

    /// Save a complete content backup; if nothing changed since the newest one, only mark that one as checked.
    @discardableResult
    static func save(_ files: [String: [UInt8]], device: String?, root: URL, now: Date = Date()) throws -> (folder: URL, new: Bool) {
        let hashes = files.mapValues { SHA256.hex($0) }
        let fm = FileManager.default
        if let (folder, found) = all(root).first, found.files == hashes {
            var manifest = found
            manifest.checked = now
            try write(manifest, to: folder)
            return (folder, false)
        }
        let folder = root.appendingPathComponent("content").appendingPathComponent(stamp(now))
        for (path, data) in files {
            let url = folder.appendingPathComponent(path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(data).write(to: url, options: .atomic)
        }
        try write(Manifest(taken: now, checked: now, device: device, files: hashes), to: folder)
        for (old, _) in all(root).dropFirst(keep) { try? fm.removeItem(at: old) }
        return (folder, true)
    }

    static func all(_ root: URL) -> [(URL, Manifest)] {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let content = root.appendingPathComponent("content")
        return ((try? FileManager.default.contentsOfDirectory(at: content, includingPropertiesForKeys: nil)) ?? [])
            .compactMap { folder in
                guard let d = try? Data(contentsOf: folder.appendingPathComponent("manifest.json")),
                      let m = try? dec.decode(Manifest.self, from: d) else { return nil }
                return (folder, m)
            }
            .sorted { $0.1.taken > $1.1.taken }
    }

    private static func write(_ m: Manifest, to folder: URL) throws {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(m).write(to: folder.appendingPathComponent("manifest.json"), options: .atomic)
    }

    private static func stamp(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return f.string(from: d)
    }
}

/// SHA-256 (FIPS 180-4), for the manifest's hashes: CryptoKit is Apple's.
enum SHA256 {
    private static let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01,
        0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
        0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116, 0x1e376c08,
        0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]

    static func hex(_ data: [UInt8]) -> String { hash(data).map { String(format: "%02x", $0) }.joined() }

    static func hash(_ data: [UInt8]) -> [UInt8] {
        var h: [UInt32] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
        var m = data
        let bits = UInt64(data.count) * 8
        m.append(0x80)
        while m.count % 64 != 56 { m.append(0) }
        for i in (0..<8).reversed() { m.append(UInt8(truncatingIfNeeded: bits >> (UInt64(i) * 8))) }
        var w = [UInt32](repeating: 0, count: 64)
        func r(_ x: UInt32, _ n: UInt32) -> UInt32 { x >> n | x << (32 - n) }
        for chunk in stride(from: 0, to: m.count, by: 64) {
            for i in 0..<16 {
                let j = chunk + i * 4
                w[i] = UInt32(m[j]) << 24 | UInt32(m[j + 1]) << 16 | UInt32(m[j + 2]) << 8 | UInt32(m[j + 3])
            }
            for i in 16..<64 {
                let s0 = r(w[i - 15], 7) ^ r(w[i - 15], 18) ^ (w[i - 15] >> 3)
                let s1 = r(w[i - 2], 17) ^ r(w[i - 2], 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }
            var (a, b, c, d, e, f, g, hh) = (h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7])
            for i in 0..<64 {
                let t1 = hh &+ (r(e, 6) ^ r(e, 11) ^ r(e, 25)) &+ ((e & f) ^ (~e & g)) &+ k[i] &+ w[i]
                let t2 = (r(a, 2) ^ r(a, 13) ^ r(a, 22)) &+ ((a & b) ^ (a & c) ^ (b & c))
                (hh, g, f, e, d, c, b, a) = (g, f, e, d &+ t1, c, b, a, t1 &+ t2)
            }
            for (i, v) in [a, b, c, d, e, f, g, hh].enumerated() { h[i] = h[i] &+ v }
        }
        return h.flatMap { v in (0..<4).map { UInt8(truncatingIfNeeded: v >> (24 - $0 * 8)) } }
    }
}
