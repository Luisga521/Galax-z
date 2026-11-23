import Foundation
import Testing
@testable import OPZLink
@testable import OPZModel

/// `Fixtures/file-session.json`: op-free's fake OP-Z serving both settings files ($51, $52, $35 × 2, close), both
/// directions, and the files as the fake holds them.
struct FileSessionFixture: @unchecked Sendable {
    let transcript: [(fromHost: Bool, bytes: [UInt8])]
    let plugs: [UInt8]
    let slots: [UInt8]

    static let shared: FileSessionFixture = {
        let url = Bundle.module.url(forResource: "file-session", withExtension: "json", subdirectory: "Fixtures")!
        let doc = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let transcript = (doc["transcript"] as! [[String: String]]).map {
            (fromHost: $0["from"] == "host", bytes: DemoOPZCore.bytes($0["hex"]!))
        }
        return FileSessionFixture(transcript: transcript, plugs: Array((doc["plugs"] as! String).utf8),
                                  slots: Array((doc["slots"] as! String).utf8))
    }()

    var opz: [[UInt8]] { transcript.filter { !$0.fromHost }.map(\.bytes) }
}

@Suite struct FileClientTests {
    @Test func pullsBothSettingsFilesLikeOpFree() {
        let fixture = FileSessionFixture.shared
        let client = FileClient()
        var expected = fixture.transcript.filter(\.fromHost).map(\.bytes)[...]
        func check(_ sent: [[UInt8]]) {
            for frame in sent {
                #expect(frame == expected.first)
                expected = expected.dropFirst()
            }
        }
        check(client.start(now: 0))
        var now = 0.0
        for frame in fixture.opz {
            now += 0.002
            check(client.receive(frame, now: now))
        }
        #expect(expected.isEmpty, "\(expected.count) host frames never sent")
        #expect(client.phase == .done)
        #expect(client.files[FileClient.plugs] == fixture.plugs)
        #expect(client.files[FileClient.slotConfiguration] == fixture.slots)
    }

    @Test func aLostPartIsAskedForAgain() {
        let fixture = FileSessionFixture.shared
        let client = FileClient(fileIDs: [FileClient.plugs])
        _ = client.start(now: 0)
        let open = fixture.opz.first { (try? SysEx.decode($0))?.id == 0x34 }!
        _ = client.receive(open, now: 0.01)
        let parts = fixture.opz.filter { frame in
            guard let f = try? SysEx.decode(frame), f.id == 0x53 else { return false }
            return f.payload[2] == 1 // plugs.json
        }
        #expect(parts.count > 3)
        for (i, part) in parts.enumerated() where i != 2 { _ = client.receive(part, now: 0.02) } // part 2 lost
        #expect(client.files.isEmpty)
        #expect(client.tick(now: 0.2).isEmpty || client.tick(now: 0.2) == [FileClient.keepaliveFrame()])
        #expect(client.tick(now: 0.5).contains(FileClient.requestFrame(fid: FileClient.plugs, part: 2)))
        _ = client.receive(parts[2], now: 0.55)
        #expect(client.files[FileClient.plugs] == fixture.plugs)
        #expect(client.phase == .done)
    }

    @Test func nothingServedFailsAfterThreeRounds() {
        let fixture = FileSessionFixture.shared
        let client = FileClient(fileIDs: [99])
        _ = client.start(now: 0)
        _ = client.receive(fixture.opz.first { (try? SysEx.decode($0))?.id == 0x34 }!, now: 0)
        _ = client.tick(now: 3)
        #expect(client.phase == .failed("file 99 is not served"))
    }
}

@Suite struct SoundNameTests {
    let settings = OPZSettings(plugsJSON: FileSessionFixture.shared.plugs, slotsJSON: FileSessionFixture.shared.slots)!

    @Test func communityEnginesByNameAndKnobs() throws {
        let table = try #require(Sound(plug: 61016, settings: settings))
        #expect(table.name == "TABLE")
        #expect(table.origin == .community)
        #expect(table.p1 == "position" && table.p2 == "bank")
        #expect(EngineCatalogue.byPlug.count == 31)
        #expect(settings.slot(of: 61016, track: 4) == 1)
        #expect(settings.slot(of: 61008, track: 8) == 10) // shimmer on FX1
    }

    @Test func teSoundsAndSamplePacks() {
        #expect(Sound(plug: 121, settings: settings)?.name == "TE KICKS")
        #expect(Sound(plug: 121, settings: settings)?.origin == .samples)
        #expect(Sound(plug: 10, settings: settings)?.name == "ANALOGA")
        #expect(Sound(plug: 10, settings: settings)?.origin == .teenageEngineering)
        #expect(Sound(plug: 999, settings: settings)?.name == "PLUG 999")
        // a plug with neither engine nor samples (perform, module, lights on a real OP-Z)
        let builtIn = OPZSettings(plugsJSON: Array(#"{"plugs":[{"engine":"","flags":0,"id":147,"samples":"","version":1}]}"#.utf8),
                                  slotsJSON: Array(#"{"tracks":[{"index":12,"packs":[{"id":147,"slot":1}]}]}"#.utf8))
        #expect(Sound(plug: 147, settings: builtIn)?.name == "BUILT-IN")
        #expect(builtIn?.slot(of: 147, track: 12) == 1)
        #expect(Sound(plug: 0, settings: settings) == nil)
        #expect(Sound.words("zVinyl") == "Z VINYL")
    }

    @Test func theDemoNamesEveryTrack() throws {
        let opz = DemoOPZCore.bundled()
        let state = StateSyncClient()
        let files = FileClient()
        var queue = state.tick(now: 0, forceHello: true) + files.start(now: 0)
        var rounds = 0
        while let frame = queue.first, rounds < 2000 {
            queue.removeFirst()
            for reply in opz.receive(frame, now: 0.1) {
                queue += state.receive(reply, now: 0.1) + files.receive(reply, now: 0.1)
            }
            rounds += 1
        }
        let bank = try #require(state.bank)
        #expect(files.phase == .done)
        let s = try #require(OPZSettings(plugsJSON: files.files[FileClient.plugs]!,
                                         slotsJSON: files.files[FileClient.slotConfiguration]!))
        let names = (0..<10).map { Sound(plug: Int(bank.track(0, $0).plug), settings: s)?.name }
        #expect(names == ["FMPERC", "SNAP", "HATS", "MALLET", "TABLE", "SUPER", "CHIP", "MODAL", "PLATE", "SHIMMER"])
        #expect(s.slot(of: 61015, track: 5) == 4) // super on lead, slot 4
    }
}
