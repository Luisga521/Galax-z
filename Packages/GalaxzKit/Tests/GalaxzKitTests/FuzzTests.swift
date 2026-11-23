import Foundation
import Testing
@testable import DotKit
@testable import OPZFirmware
@testable import OPZLink
@testable import OPZModel
@testable import OPZStage

/// Whatever comes down the cable, the app stays up.
@Suite struct FuzzTests {
    @Test func anyMessages() {
        var r = DotRandom(1)
        let c = Vector.shared.replay()
        var now = 1000.0
        for _ in 0..<6_000 {
            now += r.unit() * 0.05
            let id = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x09, 0x0A, 0x0C, 0x0E, 0x12, 0x13, 0x1B][Int(r.unit() * 14)]
            let n = r.unit() < 0.5 ? [0, 1, 2, 4, 7, 17, 18, 19, 20][Int(r.unit() * 9)] : Int(r.unit() * 190)
            var p = (0..<n).map { _ in UInt8(truncatingIfNeeded: r.next()) }
            if id == 0x02, n >= 7, r.unit() < 0.7 { p[5] = UInt8(min(n - 7, 255)); p[6] = r.unit() < 0.5 ? 0 : 5 }
            _ = c.receive(SysEx.frame(UInt8(id), p), now: now)
            _ = c.tick(now: now)
            if r.unit() < 0.001 { c.reset() }
            #expect(c.bank?.bytes.count ?? OPZ.bankSize == OPZ.bankSize)
        }
        for _ in 0..<3000 { _ = c.receive((0..<Int(r.unit() * 60)).map { _ in UInt8(truncatingIfNeeded: r.next()) }, now: now) }
    }

    @Test func anyProjectOnEveryPage() {
        var r = DotRandom(2)
        let c = DotCanvas(width: 320, height: 240)
        for round in 0..<6 {
            let bytes = (0..<OPZ.bankSize).map { _ in round == 0 ? 0xFF : round == 1 ? 0 : UInt8(truncatingIfNeeded: r.next()) } as [UInt8]
            let s = Stage()
            var i = StageInput()
            i.link = .live
            i.bank = Bank(bytes)
            i.revision = round + 1
            i.tempo = [0, 1, -5, 65_535, 120, nil][round]
            s.input = i
            s.linkFade.jump(1)
            var t = 400_000.0
            for k in 0..<120 {
                t += r.unit() * 0.2
                var j = s.input
                j.address = PatternAddress(raw: Int(r.unit() * 256))
                _ = j.panel.receive(0x03, [UInt8(truncatingIfNeeded: r.next()), UInt8(truncatingIfNeeded: r.next())])
                _ = j.panel.receive(0x05, (0..<17).map { _ in UInt8(truncatingIfNeeded: r.next()) })
                _ = j.panel.receive(0x06, (0..<4).map { _ in UInt8(truncatingIfNeeded: r.next()) })
                _ = j.panel.receive(0x12, (0..<18).map { _ in UInt8(truncatingIfNeeded: r.next()) })
                for q in 0..<16 { j.sounds[q] = Sound(plug: Int(r.unit() * 62_000), settings: nil) }
                s.input = j
                s.noteOn(channel: Int(r.unit() * 18) - 1, note: Int(r.unit() * 128), velocity: Int(r.unit() * 128))
                s.noteOff(channel: Int(r.unit() * 16), note: Int(r.unit() * 128))
                s.page = Stage.Page(rawValue: k % Stage.Page.allCases.count)!
                _ = s.tap(Int(r.unit() * 400) - 40, Int(r.unit() * 300) - 30)
                s.frame(c, time: t, dt: r.unit() * 0.3)
            }
        }
    }

    @Test func anyReleaseFile() throws {
        var r = DotRandom(3)
        for _ in 0..<400 {
            let d = Data((0..<Int(r.unit() * 400)).map { _ in UInt8(truncatingIfNeeded: r.next()) })
            #expect(throws: (any Error).self) { try SignedRelease.read(d).open() }
        }
    }

    /// Hours of playing: nothing piles up.
    @Test func nothingGrows() {
        let s = StageTests().stage(), c = DotCanvas(width: 240, height: 180)
        s.linkFade.jump(1)
        var t = 0.0, r = DotRandom(4)
        for k in 0..<6_000 {
            t += 0.05
            var i = s.input
            i.panel.step = k % 16
            i.panel.positions = [UInt8](repeating: UInt8(k % 16) << 4, count: 16)
            i.panel.told += 1
            s.input = i
            s.noteOn(channel: k % 16, note: Int(r.unit() * 128), velocity: 90)        // and never a note off
            if k % 10 == 0 { s.frame(c, time: t, dt: 0.05) } else { s.time = t }
        }
        #expect(s.trail.notes.count <= 600 && s.sky.thrown.count <= 160 && s.touches.count < 100 && s.strikes.allSatisfy { $0.count <= 8 } && s.loads.count <= 48)
    }
}
