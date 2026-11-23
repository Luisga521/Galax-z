import Foundation
import Testing
@testable import OPZLink
@testable import OPZModel
@testable import OPZStage

/// `$02` edits and panel messages against bytes a real OP-Z sent (Documents/Diagnostics, 2026-11-21) and the bank bytes
/// that changed after them.
@Suite struct LiveEditTests {
    static func hex(_ s: String) -> [UInt8] { s.split(separator: " ").map { UInt8($0, radix: 16)! } }

    @Test func recordsOfAPayload() throws {
        // a step recorded over: its old note out, the new one in, then its length while it is held
        let c = try #require(PatternChange.parse(Self.hex("0c 00 00 00 07 03 05 01 00 00 0d 00 d0 00 07 08 00 30 00 00 00 38 64 00 00 0e 00 d0 00 07 04 00 00 30 00 00")))
        #expect(c.map(\.timestamp) == [12, 13, 14])
        #expect(c.allSatisfy { $0.address.raw == 7 })
        #expect(c[0].kind == .clearStep(track: 1, step: 0))
        #expect(c[1].kind == .write(offset: 0xD0, bytes: [0x30, 0, 0, 0, 0x38, 0x64, 0, 0]))
        #expect(c[2].kind == .write(offset: 0xD0, bytes: [0, 0x30, 0, 0]))
        #expect(PatternChange.parse(Self.hex("29 00 00 00 10 00 02")) == [PatternChange(timestamp: 41, address: PatternAddress(raw: 16), kind: .replaced(type: 2))])
        #expect(PatternChange.parse(Self.hex("01 00 00 00 07 09 00 01")) == nil)
        #expect(PatternChange.parse([1, 2]) == nil)
        #expect(PatternChange.parse([]) == [])
    }

    @Test func editsLandWhereTheOPZPutThem() throws {
        var bank = try #require(Bank([UInt8](repeating: 0x36, count: OPZ.bankSize)))
        func make(_ s: String) -> Bool { PatternChange.parse(Self.hex(s))!.allSatisfy { bank.apply($0) } }
        // "bank changed: p8+000c4 36>ff", "p8+007a4 36>ff", "p8+00824 / 0082c / 00834 36>ff" (track 7, step 5)
        #expect(make("01 00 00 00 07 03 05 00 00 01 02 00 00 00 07 03 05 00 04 01 06 00 00 00 07 03 05 06 04 01"))
        let p = 7 * OPZ.patternSize
        for at in [0xC4, 0xCC, 0x7A4, 0x7AC, 0x824, 0x82C, 0x834] { #expect(bank.bytes[p + at] == 0xFF, "\(String(at, radix: 16))") }
        #expect(bank.bytes[p + 0xD4] == 0x36)
        // "p8+000d1 1d>d8"
        #expect(make("09 00 d0 00 07 04 00 00 d8 00 00"))
        #expect(bank.bytes[p + 0xD1] == 0xD8)
        #expect(!make("09 00 00 00 07 00 02"))
        #expect(!make("09 00 8f 53 07 04 00 00 d8 00 00"))   // past the pattern's end
        #expect(bank.bytes.count == OPZ.bankSize)
    }

    @Test func theTwoKindsOfMute() throws {
        var bank = try #require(Bank([UInt8](repeating: 0, count: OPZ.bankSize)))
        // group 0: track 1 muted (2), track 2 audio muted (1), track 4 muted; as a unit's project has it: a2 00 00 00 is 1, 3 and 4
        let at = 21_344
        func write(_ b: [UInt8]) -> Bool { bank.apply(PatternChange(timestamp: 1, address: PatternAddress(raw: 0), kind: .write(offset: at, bytes: b))) }
        #expect(write([0xA2, 0, 0, 0]))
        #expect((0..<16).filter { bank.muted(0, $0) } == [0, 2, 3] && (0..<16).allSatisfy { !bank.audioMuted(0, $0) })
        #expect(write([0x06, 0, 0x01, 0x40]))
        #expect((0..<16).filter { bank.muted(0, $0) } == [0] && (0..<16).filter { bank.audioMuted(0, $0) } == [1, 8, 15])
        let g = PatternGrid(bank, 0)
        #expect((0..<16).filter { g.muted[$0] } == [0, 1, 8, 15] && (0..<16).filter { g.audioMuted[$0] } == [1, 8, 15])
    }

    private func live() -> (StateSyncClient, PatternAddress) {
        let c = Vector.shared.replay()
        return (c, c.bankAddress!)
    }

    @Test func anEditIsThereAtOnceWithNoFetch() {
        let (c, a) = live()
        let offset = OPZ.notesAt + (3 * OPZ.slotsPerStep + 8) * 8     // bass, step 4
        let before = c.bankRevision
        let frame = SysEx.frame(0x02, [1, 0, UInt8(offset & 255), UInt8(offset >> 8), UInt8(a.raw), 8, 0, 0, 0x0A, 0, 0, 0x38, 0x64, 0, 0])
        #expect(c.receive(frame, now: 100).isEmpty)
        #expect(c.bank!.notes(a.pattern, 4, 3).contains { $0.note == 0x38 && $0.velocity == 0x64 })
        #expect(c.editRevision == 1 && c.bankRevision == before && c.refetches == 0)
        _ = c.tick(now: 100.0)
        #expect(!c.tick(now: 101).contains(StateSyncClient.bankRequestFrame()))
        // a sound
        #expect(c.receive(SysEx.frame(0x0E, [4] + (0..<18).map { UInt8($0 * 10) }), now: 101).isEmpty)
        #expect(c.bank!.sound(a.pattern, 4) == (0..<18).map { $0 * 10 })
    }

    @Test func whatCannotBeFollowedIsFetched() {
        for frames in [[[1, 0, 0, 0, 0, 0, 2]], [[1, 0, 0, 0, 0, 3, 5, 0, 0, 1], [3, 0, 0, 0, 0, 3, 5, 0, 4, 1]], [[9, 9, 9]]] as [[[UInt8]]] {
            let (c, _) = live()
            for f in frames { _ = c.receive(SysEx.frame(0x02, f), now: 100) }
            #expect(c.tick(now: 100.3).contains(StateSyncClient.bankRequestFrame()), "\(frames)")
            #expect(c.refetches == 1)
        }
    }

    @Test func thePanel() {
        let (c, _) = live()
        func receive(_ id: UInt8, _ p: [UInt8]) { _ = c.receive(SysEx.frame(id, p), now: 50) }
        receive(0x03, [0xFF, 0x15])
        #expect(c.panel.track == 5 && c.panel.playing && c.panel.octave == -1)
        receive(0x05, (0..<16).map { UInt8($0 << 4 | 3) } + [0x27])
        #expect(c.panel.positions == (0..<16).map { UInt8($0 << 4 | 3) } && c.panel.step == 7 && c.panel.told == 1)
        receive(0x06, [0x80, 0x3F, 0x80, 0])
        #expect(c.panel.page == 2 && c.panel.heldStep == nil && c.panel.shift && c.panel.recording)
        receive(0x06, [0x00, 0x05, 0x00, 0])
        #expect(c.panel.heldStep == 5 && !c.panel.shift && !c.panel.recording)
        receive(0x12, Array(0..<18))
        #expect(c.panel.levels == Array(0..<16))
        let n = c.panelRevision
        receive(0x03, [1])
        receive(0x05, [])
        #expect(c.panelRevision == n)
        c.reset()
        #expect(c.panel == PanelState())
    }

    /// A bank, part by part, as an OP-Z sends it.
    private func bankFrames(_ b: [UInt8], address: Int, transfer: Int) -> [[UInt8]] {
        let z = Vector.shared.transcript.filter { !$0.fromHost }.map(\.bytes).filter { [0x09, 0x0A].contains((try? SysEx.decode($0))?.id) }
        return z.map { raw in
            let f = try! SysEx.decode(raw)
            var p = f.payload
            p[0] = UInt8(address & 255); p[1] = UInt8(address >> 8); p[2] = UInt8(transfer & 255); p[3] = UInt8(transfer >> 8)
            return SysEx.frame(f.id, p)
        }
    }
    private func edit(_ id: UInt8, _ a: PatternAddress, velocity: UInt8) -> [UInt8] {
        let o = OPZ.notesAt + 8 * 8
        return SysEx.frame(0x02, [id, 0, UInt8(o & 255), UInt8(o >> 8), UInt8(a.raw), 8, 0, 0, 0x0A, 0, 0, 0x38, velocity, 0, 0])
    }

    @Test func aBankThatDoesNotComeIsAskedForAgain() {
        let (c, _) = live()
        _ = c.receive(SysEx.frame(0x02, [1, 0, 0, 0, 0, 0, 2]), now: 100)
        var asks = 0
        for k in 0..<240 { asks += c.tick(now: 100 + Double(k) * 0.05).filter { $0 == StateSyncClient.bankRequestFrame() }.count }
        #expect(asks >= 4 && asks < 12)
        for f in bankFrames([], address: c.bankAddress!.raw, transfer: 77) { _ = c.receive(f, now: 113) }
        #expect((0..<100).allSatisfy { !c.tick(now: 114 + Double($0) * 0.1).contains(StateSyncClient.bankRequestFrame()) })
    }

    @Test func editsWhileABankIsOnItsWayStay() {
        let (c, a) = live()
        _ = c.receive(SysEx.frame(0x02, [1, 0, 0, 0, 0, 0, 2]), now: 100)
        #expect(c.tick(now: 100.3).contains(StateSyncClient.bankRequestFrame()))
        _ = c.receive(edit(2, a, velocity: 0x11), now: 100.32)                       // before its first part
        _ = c.receive(SysEx.frame(0x0E, [4] + [UInt8](repeating: 9, count: 18)), now: 100.33)
        let parts = bankFrames([], address: a.raw, transfer: 78)
        for (i, f) in parts.enumerated() {
            _ = c.receive(f, now: 100.4 + Double(i) * 0.001)
            if i == 3 { _ = c.receive(edit(3, a, velocity: 0x22), now: 100.41) }     // and during it
        }
        #expect(c.bank!.notes(a.pattern, 4, 0).first?.velocity == 0x22)
        #expect(c.bank!.sound(a.pattern, 4) == [Int](repeating: 9, count: 18))
    }

    @Test func afterASessionIsLostTheProjectIsReadAgain() {
        let (c, a) = live()
        c.reset()
        _ = c.tick(now: 200)
        _ = c.receive(SysEx.frame(0x01, [0, 0, 0x42, 0x42]), now: 200.01)            // the session was still open: no bank comes
        #expect((0..<40).contains { c.tick(now: 200 + Double($0) * 0.1).contains(StateSyncClient.bankRequestFrame()) })
        for f in bankFrames([], address: a.raw, transfer: 79) { _ = c.receive(f, now: 205) }
        #expect((0..<30).allSatisfy { !c.tick(now: 206 + Double($0) * 0.1).contains(StateSyncClient.bankRequestFrame()) })
    }

    @Test func anEditOfAnotherProjectMeansItIsOpenNow() {
        let (c, a) = live()
        _ = c.receive(edit(1, PatternAddress(raw: (a.raw + 16) & 255), velocity: 1), now: 100)
        #expect(c.tick(now: 100.3).contains(StateSyncClient.bankRequestFrame()))
    }
}
