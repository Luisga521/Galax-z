import CryptoKit
import Foundation
import Testing
@testable import OPZFirmware

@Suite struct ReleaseTests {
    let key = Curve25519.Signing.PrivateKey()
    var pub: [Data] { [key.publicKey.rawRepresentation] }

    /// Galax-z v9 as a release, from the records shipped here (its image needs TE's OS: see the last test).
    func release(_ label: String = "galaxz-v9", number: Int = 9, image: [UInt8] = [1, 2, 3], change: (inout [String: String], inout String) -> Void = { _, _ in }) throws -> Release {
        let root = try #require(Catalog.bundledRoot)
        var build = try String(contentsOf: root.appending(path: "builds/galaxz-v9.json"), encoding: .utf8)
        let b = try JSONDecoder().decode(Catalog.Build.self, from: Data(build.utf8))
        var patches = try Dictionary(uniqueKeysWithValues: b.patches.map { ($0, try String(contentsOf: root.appending(path: "patches/\($0)"), encoding: .utf8)) })
        change(&patches, &build)
        return Release(number: number, label: label, title: "Galax-z v9", date: "2026-11-22", notes: ["More notes"], image: image, build: build, patches: patches)
    }

    @Test func signedAndOpened() throws {
        let r = try release(), s = try SignedRelease(r, key: key)
        #expect(try SignedRelease.read(s.file()).open(pub) == r)
        let (b, records) = try r.parts()
        #expect(b.patches.allSatisfy { $0.hasPrefix("galaxz-v9/") && records[$0] != nil })
    }

    @Test func anotherKeyIsRefused() throws {
        let s = try SignedRelease(try release(), key: key)
        #expect(throws: ReleaseError.self) { try s.open([Curve25519.Signing.PrivateKey().publicKey.rawRepresentation]) }
        #expect(throws: ReleaseError.self) { try s.open([]) }
        #expect(throws: ReleaseError.self) { try s.open([Data([1, 2])]) }
    }

    @Test func aChangedByteIsRefused() throws {
        let s = try SignedRelease(try release(), key: key)
        var json = try JSONSerialization.jsonObject(with: s.file()) as! [String: Any]
        for at in [10, 400, 9000] {
            var p = s.payload
            p[at] ^= 1
            json["payload"] = p.base64EncodedString()
            let d = try JSONSerialization.data(withJSONObject: json)
            #expect(throws: ReleaseError.self) { try SignedRelease.read(d).open(pub) }
        }
        // signed for something else
        let other = try key.signature(for: s.payload)
        json["payload"] = s.payload.base64EncodedString()
        json["signature"] = other.base64EncodedString()
        #expect(throws: ReleaseError.self) { try SignedRelease.read(JSONSerialization.data(withJSONObject: json)).open(pub) }
        for junk in [Data(), Data("{}".utf8), Data("[]".utf8), Data([0xFF])] { #expect(throws: ReleaseError.self) { try SignedRelease.read(junk) } }
    }

    @Test func whatIsNotABuildOfRecordsIsRefused() throws {
        func refused(_ r: Release) throws { #expect(throws: ReleaseError.self) { try SignedRelease(r, key: key).open(pub) } }
        try refused(release { p, _ in p["../evil.json"] = p.removeValue(forKey: "meter.json") })
        try refused(release { p, _ in p["extra.json"] = p["meter.json"] })
        try refused(release { p, _ in p["meter.json"] = "{}" })
        try refused(release { p, _ in p["meter.json"] = p["meter.json"]!.replacingOccurrences(of: "WORKS on the unit", with: "DRAFT") })
        try refused(release { p, _ in p["meter.json"] = p["meter.json"]!.replacingOccurrences(of: Original.sha256, with: String(repeating: "0", count: 64)) })
        try refused(release { _, b in b = "not json" })
        try refused(release("../x"))
        try refused(release(number: 0))
        try refused(release("original"))
        try refused(release("galaxz-v20", number: 99))          // a name that says one thing and a number another
        try refused(release("galaxz-v-5", number: 5))
        let wild = "0xfffffffffffffff0"
        #expect(throws: (any Error).self) { try release { p, _ in p["meter.json"] = p["meter.json"]!.replacingOccurrences(of: "0x80119bc8", with: wild) }.image(original: FirmwareFixture.original ?? []) }
    }

    @Test func theStoreKeepsOnlyWhatChecksOut() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "galaxz-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ReleaseStore(folder: dir, keys: pub)
        #expect(store.all().isEmpty)
        try store.add(SignedRelease(try release("galaxz-v20", number: 20), key: key).file())
        try store.add(SignedRelease(try release("galaxz-v21", number: 21), key: key).file())
        #expect(store.all().map(\.number) == [21, 20])
        #expect(throws: ReleaseError.self) { try store.add(SignedRelease(try release(), key: Curve25519.Signing.PrivateKey()).file()) }
        try Data("{}".utf8).write(to: dir.appending(path: "galaxz-v22.galaxz"))
        #expect(store.all().map(\.number) == [21, 20])
    }

    @Test func aReleaseJoinsTheCatalogueAndNeverReplacesABuildOfTheApps() throws {
        let mine = try Catalog.bundled()
        let c = mine.adding([try release("galaxz-v20", number: 20), try release { p, _ in p["meter.json"] = p["meter.json"]!.replacingOccurrences(of: "SHIFT", with: "shift") }])
        #expect(c.builds.map(\.label).filter { $0 == "galaxz-v9" }.count == 1)
        #expect(c.builds.first { $0.label == "galaxz-v9" }?.build.patches == mine.builds.first { $0.label == "galaxz-v9" }?.build.patches)
        #expect(c.builds.contains { $0.label == "galaxz-v20" })
        #expect(Catalog.number(of: "galaxz-v22") == 22 && Catalog.number(of: "original") == nil)
    }

    @Test func theFeedPointsOnlyBesideItself() {
        let feed = URL(string: "https://example.com/a/feed.json")!
        func url(_ f: String) -> String? { ReleaseFeed.url(of: .init(number: 1, label: "x", title: "", date: "", file: f), feed: feed)?.absoluteString }
        #expect(url("galaxz-v9.galaxz") == "https://example.com/a/galaxz-v9.galaxz")
        for bad in ["../x.galaxz", "https://evil/x.galaxz", "x.exe", "", "a/b.galaxz"] { #expect(url(bad) == nil, "\(bad)") }
    }

    @Test(.enabled(if: FirmwareFixture.original != nil)) func itMakesTheImageItPromises() throws {
        let original = try #require(FirmwareFixture.original)
        let images = try Catalog.bundled().images(original: original)
        let v9 = try #require(images.first { $0.label == "galaxz-v9" }?.ldr)
        #expect(try release(image: v9).image(original: original) == v9)
        #expect(throws: ReleaseError.self) { try release(image: v9 + [0]).image(original: original) }
        #expect(throws: ReleaseError.self) { try release(image: v9).image(original: [0]) }
        // and what the hub would write is held to the promise too
        let good = try Catalog.bundled().adding([release("galaxz-v20", number: 20, image: v9)]).images(original: original)
        #expect(good.first { $0.label == "galaxz-v20" }?.ldr == v9)
        let bad = try Catalog.bundled().adding([release("galaxz-v20", number: 20, image: v9 + [0])]).images(original: original)
        #expect(bad.contains { $0.label == "galaxz-v20" && $0.ldr == nil && !$0.reason.isEmpty })
    }

    @Test(.enabled(if: FirmwareFixture.original != nil)) func aReleasePlaysAnimationsToo() throws {
        let original = try #require(FirmwareFixture.original), layout = try LEDLayout.bundled()
        let images = try Catalog.bundled().images(original: original)
        let v9 = try #require(images.first { $0.label == "galaxz-v9" }?.ldr)
        // the app's own v9 taken away, so that only the release can be what is recognised
        let mine = try Catalog.bundled()
        let without = Catalog(builds: mine.builds.filter { $0.label != "galaxz-v9" }.map { ($0.label, $0.build) }, records: mine.records)
        let c = without.adding([try release("galaxz-v20", number: 20, image: v9)])
        #expect(c.playerBuilds.contains { $0.label == "galaxz-v20" })
        let a = try #require(LEDAnimation.library.last { !$0.isTest })
        let im = try #require(c.bootImage(original: original, a, layout: layout, on: "galaxz-v20").ldr)
        #expect(c.underPlayer(im)?.label == "galaxz-v20" && c.underPlayer(im)?.original == original)
        #expect(c.frames(playedBy: im) == a.bytes(layout))
        #expect(c.underPlayer(v9)?.label == "galaxz-v20" && c.recoverOriginal(from: v9) == original)
    }
}

enum FirmwareFixture {
    /// TE's 1.2.45, if this Mac has it (it is never in the repository).
    static let original: [UInt8]? = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        for p in ["Desktop/Galax-z/Firmware/dumps/2026-11-21/os.ldr", "Library/Application Support/Galax-z/os-1.2.45.ldr"] {
            if let d = try? Data(contentsOf: home.appending(path: p)), Original.matches([UInt8](d)) { return [UInt8](d) }
        }
        return nil
    }()
}
