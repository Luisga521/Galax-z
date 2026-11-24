#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto        // swift-crypto: the same API, on Windows and Linux
#endif
import Foundation
import OPZFirmware

/// Make, check and list Galax-z OS releases.
///
///     swift run galaxz-release keygen                       a signing key, in Application Support (never in the repository)
///     swift run galaxz-release make galaxz-v9 OS.ldr OUT_DIR      its notes are the build's
///     swift run galaxz-release verify FILE.galaxz [OS.ldr]
///     swift run galaxz-release feed DIR                     write DIR/feed.json from the releases in it
func fail(_ s: String) -> Never {
    FileHandle.standardError.write(Data((s + "\n").utf8))
    exit(1)
}
let args = Array(CommandLine.arguments.dropFirst())
let keyURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/Galax-z/release-key")
func hex(_ d: Data) -> String { d.map { String(format: "%02x", $0) }.joined() }
func key() -> Curve25519.Signing.PrivateKey {
    guard let d = try? Data(contentsOf: keyURL), let k = try? Curve25519.Signing.PrivateKey(rawRepresentation: d) else { fail("no signing key: galaxz-release keygen") }
    return k
}

switch args.first {
case "keygen":
    if FileManager.default.fileExists(atPath: keyURL.path) { fail("there is a key already: \(keyURL.path)\npublic \(hex(key().publicKey.rawRepresentation))") }
    let k = Curve25519.Signing.PrivateKey()
    try FileManager.default.createDirectory(at: keyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard FileManager.default.createFile(atPath: keyURL.path, contents: k.rawRepresentation, attributes: [.posixPermissions: 0o600]) else { fail("cannot write \(keyURL.path)") }
    print("private key: \(keyURL.path) (keep a copy somewhere safe; never commit it)\npublic key, for ReleaseKeys.swift:\n\(hex(k.publicKey.rawRepresentation))")
case "public":
    print(hex(key().publicKey.rawRepresentation))
case "make" where args.count == 4:
    let label = args[1]
    guard let number = Catalog.number(of: label) else { fail("a release is a build named galaxz-vN") }
    let original = [UInt8](try Data(contentsOf: URL(filePath: args[2])))
    guard Original.matches(original) else { fail("\(args[2]) is not TE's \(Original.firmware)") }
    guard let root = Catalog.bundledRoot else { fail("no firmware folder") }
    let text = try String(contentsOf: root.appending(path: "builds/\(label).json"), encoding: .utf8)
    let build = try JSONDecoder().decode(Catalog.Build.self, from: Data(text.utf8))
    let patches = try Dictionary(uniqueKeysWithValues: build.patches.map { ($0, try String(contentsOf: root.appending(path: "patches/\($0)"), encoding: .utf8)) })
    let records = try build.patches.map { try JSONDecoder().decode(PatchRecord.self, from: Data(patches[$0]!.utf8)) }
    let image = try Patcher.apply(original, records)
    let day = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
    let r = Release(number: number, label: label, title: build.title, date: day, notes: build.notes ?? [build.description ?? ""], image: image, build: text, patches: patches)
    let k = key()
    let signed = try SignedRelease(r, key: k)
    guard try signed.open([k.publicKey.rawRepresentation]).image(original: original) == image else { fail("it does not check out") }
    let out = URL(filePath: args[3])
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let file = out.appending(path: "\(label).galaxz")
    try signed.file().write(to: file, options: .atomic)
    print("\(file.path): \(r.title), image sha256 \(r.imageSHA256.prefix(16))…, signed by \(signed.key)")
    if !ReleaseKeys.trusted.contains(k.publicKey.rawRepresentation) { print("NOTE: this app does not trust that key yet (ReleaseKeys.swift)") }
case "verify" where args.count >= 2:
    let r = try SignedRelease.read(Data(contentsOf: URL(filePath: args[1]))).open()
    print("signed · \(r.title) (\(r.label)) · \(r.date) · \(r.patches.count) records")
    if args.count > 2 {
        _ = try r.image(original: [UInt8](Data(contentsOf: URL(filePath: args[2]))))
        print("makes exactly the image it promises: \(r.imageSHA256)")
    }
case "feed" where args.count == 2:
    let dir = URL(filePath: args[1])
    let entries = ReleaseStore(folder: dir).all().map { ReleaseFeed.Entry(number: $0.number, label: $0.label, title: $0.title, date: $0.date, file: $0.label + ".galaxz") }
    let e = JSONEncoder()
    e.outputFormatting = [.prettyPrinted, .sortedKeys]
    try e.encode(ReleaseFeed(releases: entries)).write(to: dir.appending(path: "feed.json"), options: .atomic)
    print("feed.json: " + entries.map(\.label).joined(separator: ", "))
default:
    fail("galaxz-release keygen | public | make LABEL OS.ldr OUT_DIR | verify FILE [OS.ldr] | feed DIR")
}
