#if canImport(CoreMIDI)
import CoreMIDI
#endif
import Foundation
import Testing
@testable import OPZLink
@testable import OPZModel

/// Galax-z against op-free's TypeScript core: `Fixtures/statesync-vector.json` is a whole StateSync opening recorded
/// from op-free's fake OP-Z holding op-free's vector project, plus what op-free reads from the bank
/// (`Tools/fixtures/make-fixtures.mjs`).
struct Vector: @unchecked Sendable { // read-only after load
    let address: Int
    let transcript: [(fromHost: Bool, bytes: [UInt8])]
    let reads: [String: Any]

    static let shared: Vector = {
        let url = Bundle.module.url(forResource: "statesync-vector", withExtension: "json", subdirectory: "Fixtures")!
        let doc = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let transcript = (doc["transcript"] as! [[String: String]]).map {
            (fromHost: $0["from"] == "host", bytes: DemoOPZCore.bytes($0["hex"]!))
        }
        return Vector(address: doc["address"] as! Int, transcript: transcript, reads: doc["reads"] as! [String: Any])
    }()

    /// Play the OP-Z's side of the transcript into a client; every frame the client sends must be the next host frame.
    func replay() -> StateSyncClient {
        let client = StateSyncClient()
        var expected = transcript.filter(\.fromHost).map(\.bytes)[...]
        var now = 0.0
        func check(_ sent: [[UInt8]]) {
            for frame in sent {
                #expect(frame == expected.first, "host frame \(transcript.filter(\.fromHost).count - expected.count)")
                expected = expected.dropFirst()
            }
        }
        check(client.tick(now: now, forceHello: true))
        for entry in transcript where !entry.fromHost {
            now += 0.002
            check(client.receive(entry.bytes, now: now))
        }
        #expect(expected.isEmpty, "\(expected.count) host frames never sent")
        return client
    }
}

@Suite struct SysExTests {
    @Test func pack7RoundTrips() throws {
        let data: [UInt8] = (0..<300).map { UInt8(($0 * 37 + 11) & 0xFF) }
        #expect(try SysEx.unpack7(SysEx.pack7(data)[...]) == data)
        #expect(SysEx.pack7([0x80, 0x01]) == [0x01, 0x00, 0x01])
    }

    @Test func helloMatchesTheCore() {
        // op-free: stateSyncClientHello(0x4242) = frame(0x00, 42 42 06)
        #expect(StateSyncClient.helloFrame() == Vector.shared.transcript[0].bytes)
    }

    #if canImport(CoreMIDI)
    @Test func umpRoundTrip() async {
        let short = StateSyncClient.helloFrame() // one UMP message
        let long = StateSyncClient.ackFrame(transfer: 3, index: 513) // start, continue, end
        let (stream, continuation) = AsyncStream.makeStream(of: [UInt8].self)
        let reader = UMPReader(continuation)
        for frame in [short, long] {
            let words = MIDITransport.umpWords(frame)
            for i in stride(from: 0, to: words.count, by: 2) { reader.feed(words[i], words[i + 1]) }
        }
        continuation.finish()
        var got: [[UInt8]] = []
        for await f in stream { got.append(f) }
        #expect(got == [short, long])
    }
    #endif
}

#if canImport(CoreMIDI)
/// The 0.1 crash: CoreMIDI calls the receive block on its own thread. Call it the same way.
@Suite struct MIDIThreadTests {
    struct Call: @unchecked Sendable { let block: MIDIReceiveBlock; let list: UnsafeMutablePointer<MIDIEventList> }

    @Test func theReceiveBlockRunsOffTheMainActor() async {
        let (stream, continuation) = AsyncStream.makeStream(of: [UInt8].self)
        let size = 1024
        let raw = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 8)
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: MIDIEventList.self, capacity: 1)
        var words = MIDITransport.umpWords(StateSyncClient.helloFrame())
        let packet = MIDIEventListInit(list, ._1_0)
        _ = MIDIEventListAdd(list, size, packet, 0, words.count, &words)
        let call = Call(block: MIDITransport.readBlock(UMPReader(continuation)), list: list)
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            Thread.detachNewThread {
                call.block(call.list, nil)
                done.resume()
            }
        }
        continuation.finish()
        var got: [[UInt8]] = []
        for await f in stream { got.append(f) }
        #expect(got == [StateSyncClient.helloFrame()])
    }
}
#endif

@Suite struct StateSyncTests {
    /// Edits on the OP-Z (`$02`): one fresh bank once they pause (or after 0.6 s of non-stop edits), never mid-transfer.
    @Test func editsBringAFreshBank() {
        let client = Vector.shared.replay()
        let delta = SysEx.frame(0x02, [1, 2, 3])
        let ask = StateSyncClient.bankRequestFrame()
        var seen: [[UInt8]] = []
        client.onDelta = { seen.append($0) }
        var now = 100.0
        _ = client.receive(delta, now: now)
        #expect(seen == [[1, 2, 3]])
        #expect(!client.tick(now: now + 0.05).contains(ask))          // still editing
        #expect(client.tick(now: now + 0.2).contains(ask))            // a pause: fetch
        #expect(!client.tick(now: now + 0.4).contains(ask))           // once
        now = 200
        for k in 0..<10 { _ = client.receive(delta, now: now + Double(k) * 0.1) }   // edits without a pause
        #expect(client.tick(now: now + 0.65).contains(ask))           // still fetched within 0.6 s
        // a transfer in progress is never cut short
        let part0 = Vector.shared.transcript.first { !$0.fromHost && $0.bytes.count > 7 && $0.bytes[5] == 0x09 }!.bytes
        _ = client.receive(part0, now: 300)
        _ = client.receive(delta, now: 300.01)
        #expect(!client.tick(now: 300.3).contains(ask))
    }

    @Test func acksEveryPartAndInflatesTheBank() throws {
        let v = Vector.shared
        let client = v.replay()
        let bank = try #require(client.bank)
        #expect(client.bankAddress?.raw == v.address)
        #expect(client.bankRevision == 1)
        #expect(client.global?.tempo == v.reads["tempo"] as? Int)
        #expect(client.playAddress?.raw == v.address)
        #expect(bank.patternInUse(0) == v.reads["patternInUse"] as? Bool)
        #expect(bank.patternHasNotes(0) == v.reads["patternHasNotes"] as? Bool)
    }

    @Test func readsLikeOpFree() throws {
        let v = Vector.shared
        let bank = try #require(v.replay().bank)
        let tracks = v.reads["tracks"] as! [[String: Any]]
        for (t, track) in tracks.enumerated() {
            let r = track["record"] as! [String: Int]
            let rec = bank.track(0, t)
            #expect([Int(rec.plug), rec.stepCount, rec.timing, rec.stepLength, rec.quantize, rec.byte8, rec.noteLength,
                     rec.lastNote, rec.byte11]
                    == ["plug", "step_count", "timing", "step_length", "quantize", "byte8", "note_length", "last_note",
                        "byte11"].map { r[$0]! }, "track \(t) record")
            #expect(bank.sound(0, t) == track["sound"] as! [Int], "track \(t) sound")
            #expect(bank.muted(0, t) == track["muted"] as! Bool, "track \(t) muted")
            for (s, step) in (track["steps"] as! [[String: Any]]).enumerated() {
                let notes = (step["notes"] as! [[String: Int]]).map {
                    Note(note: $0["note"]!, velocity: $0["velocity"]!, duration: $0["duration"]!, micro: $0["micro"]!,
                         age: $0["age"]!)
                }
                #expect(bank.notes(0, t, s) == notes, "track \(t) step \(s) notes")
                let st = bank.step(0, t, s)
                #expect(st.mask == step["mask"] as! Int, "track \(t) step \(s) mask")
                #expect(st.components == step["components"] as! [String: Int], "track \(t) step \(s) components")
                #expect(st.locks == step["locks"] as! [String: Int], "track \(t) step \(s) locks")
            }
        }
    }

    @Test func aLostPartIsAskedForAgain() {
        let v = Vector.shared
        let client = StateSyncClient()
        _ = client.tick(now: 0, forceHello: true)
        let opz = v.transcript.filter { !$0.fromHost }.map(\.bytes)
        let parts = opz.filter { (try? SysEx.decode($0))?.id == 0x09 }
        for frame in opz.prefix(while: { (try? SysEx.decode($0))?.id != 0x09 }) { _ = client.receive(frame, now: 0.01) }
        _ = client.receive(parts[0], now: 0.02)
        #expect(client.receive(parts[2], now: 0.03) == [StateSyncClient.bankRequestFrame()]) // part 1 never came
        #expect(client.tick(now: 0.5).isEmpty)
        #expect(client.tick(now: 3.0).contains(StateSyncClient.bankRequestFrame())) // nothing since: still waiting
    }

    @Test func theDemoOPZPlaysAWholeSession() throws {
        let opz = DemoOPZCore.bundled()
        let client = StateSyncClient()
        var queue = client.tick(now: 0, forceHello: true)
        var rounds = 0
        while let frame = queue.first, rounds < 1000 {
            queue.removeFirst()
            for reply in opz.receive(frame, now: 0.1) { queue += client.receive(reply, now: 0.1) }
            rounds += 1
        }
        let bank = try #require(client.bank)
        #expect(client.global?.tempo == 124)
        #expect(bank.notes(0, 0, 0).first?.note == 53)
        #expect(bank.notes(0, 7, 0).map(\.note) == [60, 63, 67, 70])
        #expect(bank.track(0, 2).stepCount == 12)
        #expect(bank.muted(0, 3))
    }
}
