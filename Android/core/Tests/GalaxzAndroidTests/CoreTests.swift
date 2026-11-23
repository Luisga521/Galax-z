import DotKit
import Foundation
@testable import GalaxzAndroid
import OPZLink
import OPZStage
import Testing

@Suite struct MIDIBytesTests {
    private func read(_ chunks: [[UInt8]]) -> (frames: [[UInt8]], keys: [KeyEvent]) {
        var r = MIDIBytes(), frames: [[UInt8]] = [], keys: [KeyEvent] = []
        for c in chunks { c.withUnsafeBufferPointer { r.feed($0, time: 1, frame: { frames.append($0) }, key: { keys.append($0) }) } }
        return (frames, keys)
    }

    @Test func sysexCutAnywhereWithClockInside() {
        let (frames, keys) = read([[0xF0, 0x00, 0x20], [0x76, 0xF8, 0x01], [0x02, 0xF7]])
        #expect(frames == [[0xF0, 0x00, 0x20, 0x76, 0x01, 0x02, 0xF7]])
        #expect(keys == [.clock])
    }

    @Test func notesWithRunningStatus() {
        let (_, keys) = read([[0x93, 60, 100, 62], [90, 60, 0], [0xB3, 7, 64, 0xFA, 0xFC]])
        #expect(keys == [.noteOn(note: 60, channel: 3, velocity: 100, time: 1), .noteOn(note: 62, channel: 3, velocity: 90, time: 1),
                         .noteOff(note: 60, channel: 3, time: 1), .cc(number: 7, value: 64, channel: 3),
                         .playing(true, time: 1), .playing(false, time: 1)])
    }

    @Test func aStatusEndsAnUnfinishedSysex() {
        let (frames, keys) = read([[0xF0, 1, 2, 0x90, 60, 1, 0xF7]])
        #expect(frames.isEmpty)
        #expect(keys == [.noteOn(note: 60, channel: 0, velocity: 1, time: 1)])
    }
}

@Suite struct CoreTests {
    private func folder() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("galaxz-android-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    /// Ticks as the Kotlin side does, until `done` or a few seconds pass.
    private func run(_ c: Core, seconds: Double = 4, until done: () -> Bool) {
        let end = monotonic() + seconds
        while monotonic() < end, !done() { c.tick(); usleep(5_000) }
    }

    @Test func demoLoadsTheSongAndItsSounds() {
        let c = Core(folder: folder(), demo: true)
        run(c) { c.stage.input.bank != nil && c.stage.input.link == .live && c.stage.input.sounds.contains { $0 != nil } }
        #expect(c.stage.input.bank != nil)
        #expect(c.stage.input.link == .live)
        #expect(c.stage.input.linkName == "DEMO")
        #expect(c.stage.input.sounds.contains { $0 != nil })
        #expect(c.takeOutgoing().isEmpty)                    // nothing to a real OP-Z in demo mode
    }

    @Test func demoDrawsEveryPage() {
        let c = Core(folder: folder(), demo: true)
        run(c) { c.stage.input.bank != nil }
        for p in Stage.Page.allCases {
            c.stage.page = p
            c.stage.frame(c.canvas, time: monotonic(), dt: 1 / 60)
            c.canvas.resize(360, 240)
            c.stage.frame(c.canvas, time: monotonic(), dt: 1 / 60)
            let lit = (0..<c.canvas.count).filter { c.canvas.dots[$0] & 0xFFFFFF != 0 }.count
            #expect(lit > 200, "\(p.name): \(lit) dots lit")
        }
    }

    @Test func aConnectedOPZIsGreetedAndNothingGoesWithoutOne() {
        let c = Core(folder: folder(), demo: false)
        c.tick()
        #expect(c.takeOutgoing().isEmpty)
        c.connected("OP-Z", bluetooth: false)
        let out = c.takeOutgoing()
        #expect(out.contains { $0.bytes.first == 0xF0 && $0.bytes.last == 0xF7 })
        #expect(c.stage.input.linkName == "USB")
        c.connected(nil, bluetooth: false)
        c.tick()
        #expect(c.stage.input.link == .searching)
    }

    @Test func playingKeepsSettingsInItsFolder() throws {
        let dir = folder()
        let c = Core(folder: dir, demo: true)
        c.stage.kept()
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("player.json").path))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("performBay.json").path))
    }
}

@Suite struct SamplerTests {
    private func folder() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("galaxz-sampler-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    @Test func waveRoundTrip() throws {
        let u = folder().appendingPathComponent("x.wav")
        let x: [Float] = (0..<4800).map { Float(sin(Double($0) / 10)) * 0.5 }
        try Wave.write(x, rate: 48_000, to: u)
        let (y, rate) = try Wave.read(u, most: 10)
        #expect(rate == 48_000)
        #expect(y.count == x.count)
        #expect(zip(x, y).allSatisfy { abs($0 - $1) < 0.001 })
    }

    @Test func aSoundBecomesAKeptKit() throws {
        let dir = folder()
        let c = Core(folder: dir, demo: true)
        // four hits a quarter second apart, at 48 kHz
        var x = [Float](repeating: 0, count: 48_000)
        for h in 0..<4 { for i in 0..<2400 { x[h * 12_000 + i] = Float(sin(Double(i) / 5)) * Float(1 - Double(i) / 2400) } }
        c.sampler.open(x, rate: 48_000, name: "HITS")
        #expect(c.stage.chops.name == "HITS")
        #expect(c.stage.chops.list.count >= 2)
        #expect(c.stage.chops.own)
        let kept = try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("Chops").path)
        #expect(kept.contains { $0.hasSuffix(".wav") } && kept.contains { $0.hasSuffix(".json") })
        // a new start finds it again
        let again = Core(folder: dir, demo: true)
        again.stage.ask(.kit(1))
        #expect(again.stage.chops.name == "HITS")
    }
}

@Suite struct SettingsTests {
    private func folder() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("galaxz-settings-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    private func json(_ s: String) -> [String: Any] { (try? JSONSerialization.jsonObject(with: Data(s.utf8))) as? [String: Any] ?? [:] }

    @Test func sha256AsTheStandardHasIt() {
        #expect(SHA256.hex(Array("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(SHA256.hex([]) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(SHA256.hex(Array(repeating: 0x61, count: 1000)) == "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3")
    }

    @Test func aBackupIsKeptAndMatchedAgain() throws {
        let root = folder()
        let files = ["settings/plugs.json": Array("{}".utf8), "projects/project01.opz": [1, 2, 3]]
        let (f, new) = try Backups.save(files, device: "OP-Z", root: root)
        #expect(new)
        #expect(FileManager.default.fileExists(atPath: f.appendingPathComponent("projects/project01.opz").path))
        let (_, again) = try Backups.save(files, device: "OP-Z", root: root)
        #expect(!again)
        #expect(Backups.all(root).count == 1)
    }

    @Test func generalSaysTheDemoAndTheCheck() {
        let c = Core(folder: folder(), demo: true)
        let g = json(c.query("general"))
        #expect(g["demo"] as? Bool == true)
        #expect(((g["check"] as? [String: Any])?["items"] as? [Any])?.isEmpty == false)
    }

    @Test func theKeyTestCountsTheDemosPresses() {
        let c = Core(folder: folder(), demo: true)
        _ = c.command("keyTestOpen", "")
        let end = monotonic() + 1.5
        while monotonic() < end { c.tick(); usleep(10_000) }
        let k = json(c.query("keytest"))
        #expect((k["presses"] as? Int ?? 0) > 0)
        #expect((k["keys"] as? [Any])?.count == 24)
        _ = c.command("keyTestWindow", "0.005")
        #expect(json(c.query("keytest"))["window"] as? Int == 40)
    }

    @Test func learnListsAndWaits() {
        let c = Core(folder: folder(), demo: true)
        let l = json(c.query("learn:4"))
        #expect((l["targets"] as? [[String: Any]])?.first?["name"] as? String == "PLAY / STOP")
        _ = c.command("learn", "4,,0")
        #expect((json(c.query("learn:4"))["waiting"] as? String)?.isEmpty == false)
        _ = c.command("learnOff", "")
        #expect((json(c.query("learn:4"))["waiting"] as? String)?.isEmpty == true)
    }

    @Test func dotTextHasItsShape() {
        let d = dotText("OK", font: 1)
        #expect(d[1] == 7)
        #expect(d.count == 2 + Int(d[0]) * 7)
        #expect(d.dropFirst(2).contains(1))
    }
}
