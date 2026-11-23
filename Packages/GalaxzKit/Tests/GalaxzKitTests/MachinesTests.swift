import Foundation
import DotKit
@testable import OPZLink
@testable import OPZModel
@testable import OPZStage
import OPZPlay
import Testing

/// The tumbler and EUCLID as the OP-Z tells of them. The bytes are what the firmware's own block sent in the Blackfin simulator
/// (`SHOW=1 python3 -I Firmware/tools/test_tell.py`), the figures what `Firmware/pages/pages.c` makes on the Mac.
@Suite struct MachinesTests {
    func bytes(_ hex: String) -> [UInt8] { DemoOPZCore.bytes(hex) }

    @Test func theFirmwaresOwnBytes() {
        var m = Machines()
        let ok1 = m.receive(0x70, bytes("01040524000000000063283c5064788ca0b4c8dc"))
        #expect(ok1)
        #expect(m.page == 4 && m.track == 5 && m.tumbling == 0x24 && m.latched == 0 && !m.more && m.rings.isEmpty)
        #expect(m.dials == [0, 99, 40, 60, 80, 100, 120, 140, 160, 180, 200, 220])
        let ok2 = m.receive(0x71, bytes("050200400000000040c050b03cff7f817f084300"))
        #expect(ok2)
        #expect(m.turn == 0.25 && m.told == 1 && m.balls.count == 2)
        #expect(m.balls[0] == Machines.Ball(x: 0.5, y: -0.5, vx: 5, vy: -5, note: 60, flash: 1))
        #expect(m.balls[1].note == 67 && m.balls[1].vy == 0.5 && m.balls[1].flash == 0)
        let ok3 = m.receive(0x70, bytes("0105010402030203000000000000009900000000321004003310050134100602"))
        #expect(ok3)
        #expect(m.page == 5 && m.track == 1 && m.more && m.waiting && m.pick == 2 && m.balls.isEmpty)
        #expect(m.rings == [Machines.Ring(key: 50, steps: 16, pulses: 4, rotation: 0), Machines.Ring(key: 51, steps: 16, pulses: 5, rotation: 1),
                            Machines.Ring(key: 52, steps: 16, pulses: 6, rotation: 2)])
        let ok4 = m.receive(0x71, bytes("0100000070110100"))
        #expect(ok4 && m.steps == 70000)
    }

    @Test func whatIsNotWholeIsNotTaken() {
        var m = Machines()
        let before = m
        for n in 0..<64 where n != 20 { let ok5 = m.receive(0x70, [1] + [UInt8](repeating: 0, count: n - (n > 0 ? 1 : 0))); #expect(!ok5) }
        let ok6 = m.receive(0x70, [2] + [UInt8](repeating: 0, count: 19))
        let ok7 = m.receive(0x71, [0, 9] + [UInt8](repeating: 0, count: 60))
        let ok8 = m.receive(0x72, [])
        #expect(!ok6 && !ok7 && !ok8)
        #expect(m == before)
        var r = DotRandom(7)
        for _ in 0..<4000 {
            var p = (0..<Int(r.range(0, 70))).map { _ in UInt8(truncatingIfNeeded: r.next()) }
            if r.unit() < 0.5, p.count >= 20 { p[0] = 1; p[7] = UInt8((p.count - 20) / 4 & 15); p = Array(p.prefix(20 + Int(p[7]) * 4)) }
            _ = m.receive(r.unit() < 0.5 ? 0x70 : 0x71, p)
            for k in 0..<12 { _ = m.reading(k); #expect((0...1).contains(m.turned(k)) || m.turned(k) < 20) }
            for g in m.rings + [m.ring] { #expect((1...16).contains(g.steps) && g.pulses <= g.steps && (0..<16).contains(g.rotation)) }
        }
    }

    @Test func dialsAreTheFirmwares() {
        for (v, n, k, rot, ticks) in [(0, 2, 1, 0, 96), (51, 4, 1, 0, 64), (102, 7, 3, 2, 48), (153, 10, 6, 5, 24), (204, 13, 11, 10, 16), (255, 16, 16, 15, 12)] {
            var m = Machines()
            m.track = 5
            for d in 4...7 { m.dials[d] = v }
            #expect(m.ring == Machines.Ring(key: 0, steps: n, pulses: k, rotation: rot), "\(v)")
            #expect(m.reading(7) == [96: "1/4", 64: "1/4T", 48: "1/8", 32: "1/8T", 24: "1/16", 16: "1/16T", 12: "1/32"][ticks], "\(v)")
        }
        #expect((0..<16).map { Machines.isPulse($0, 16, 5, 3) ? "1" : "0" }.joined() == "0100100100100100")
        #expect((0..<13).map { Machines.isPulse($0, 13, 7, 2) ? "1" : "0" }.joined() == "1010101010110")
    }

    /// A second of three balls, as pages.c has them (no scatter): walls, and balls against balls.
    @Test func theBallsGoAsTheFirmwareHasThem() {
        var t = Tombola()
        t.balls = [(0.1, -0.3, 0.4, 0.2), (-0.25, -0.1, -1, 0), (0.3, 0.1, 0, -2)].map { Machines.Ball(x: $0.0, y: $0.1, vx: $0.2, vy: $0.3, note: 60) }
        let theirs: [(Int, Double, [(Double, Double, Double)])] = [
            (64, 0.0378, [(0.1113, -0.1267, 0.129), (-0.5000, 0.0596, 0.000), (0.3887, -0.2041, 0.129)]),
            (128, 0.0755, [(-0.0234, 0.3013, 0.000), (-0.5312, 0.4649, 0.431), (0.6234, -0.1341, 0.000)]),
            (192, 0.1133, [(0.0257, 0.6823, 0.804), (-0.0620, 0.4942, 0.000), (0.5546, 0.2397, 0.000)]),
            (256, 0.1510, [(0.2562, 0.6478, 1.000), (0.2153, 0.4122, 0.000), (0.4355, 0.4462, 0.471)]),
        ]
        var at = 0
        for (step, turn, balls) in theirs {
            while at < step { t.step(1.0 / 256, dials: [90, 190, 110, 0] + [Int](repeating: 0, count: 8)); at += 1 }
            #expect(abs(t.turn - turn) < 0.0002)
            for (a, b) in zip(t.balls, balls) { #expect(abs(a.x - b.0) < 0.03 && abs(a.y - b.1) < 0.03, "\(step): \(a) \(b)") }
        }
    }

    @Test func ballsStayInTheHexagon() {
        var d = DemoMachines()
        for _ in 0..<3000 {
            d.step(0.04)
            for b in d.machines.balls { #expect((b.x * b.x + b.y * b.y).squareRoot() < Tombola.wall) }
            var m = Machines()                                              // and go over the wire as they are
            let s = d.machines.messages
            let ok9 = m.receive(0x70, s[0])
            let ok10 = m.receive(0x71, s[1])
            #expect(ok9 && ok10 && m.balls.count == 5 && m.rings == d.machines.rings)
            #expect(abs(m.balls[0].x - d.machines.balls[0].x) < 0.005)
        }
    }

    @Test func overTheWholeWay() throws {
        let c = StateSyncClient()
        _ = c.receive(SysEx.frame(0x71, bytes("050200400000000040c050b03cff7f817f084300")), now: 1)
        #expect(c.machines == nil)                                          // nothing is known of it yet
        _ = c.receive(SysEx.frame(0x70, bytes("01040524000000000063283c5064788ca0b4c8dc")), now: 1)
        let was = c.panelRevision
        _ = c.receive(SysEx.frame(0x71, bytes("050200400000000040c050b03cff7f817f084300")), now: 1)
        #expect(c.machines?.balls.count == 2 && c.panelRevision == was + 1)
        c.reset()
        #expect(c.machines == nil)
    }

    /// What EUCLID and the tumbler play goes by no pattern and no MIDI: the kick is struck all the same.
    @Test @MainActor func whatAMachinePlaysStrikesItsTrack() {
        func run(_ track: Int, _ ring: Machines.Ring, steps: Int, waiting: Bool = false, chance: Int = 255) -> (rises: Int, report: String) {
            let s = Stage(), c = DotCanvas(width: 320, height: 240)
            s.input.link = .live
            var m = Machines(), t = 100.0, rises = 0, last = 0.0
            m.track = track; m.latched = UInt8(1 << track); m.rings = [ring]; m.dials[10] = chance; m.waiting = waiting
            s.frame(c, time: t, dt: 1 / 120)
            s.input.machines = m
            for k in 1...steps * 15 {                                           // a step every 0.125 s
                t += 1 / 120.0
                if k % 15 == 0 { m.steps = k / 15; m.told += 1; s.input.machines = m }
                s.frame(c, time: t, dt: 1 / 120)
                if s.hits[track] > last + 0.1 { rises += 1 }
                last = s.hits[track]
            }
            return (rises, s.report[track])
        }
        let four = Machines.Ring(key: 53, steps: 16, pulses: 4, rotation: 0)
        #expect((1...32).filter { Machines.isPulse($0 % 16, 16, 4, 0) }.count == 8)
        let kick = run(0, four, steps: 32)
        #expect(kick.rises == 8 && kick.report.contains("pattern 0, EUCLID 8"))
        #expect(run(0, four, steps: 32, waiting: true).rises == 0)              // it has not begun
        #expect(run(0, four, steps: 32, chance: 0).rises == 0)
        #expect(run(5, four, steps: 32).report.contains("EUCLID"))

        // said by the OP-Z too, over MIDI: once
        let s = Stage(), c = DotCanvas(width: 320, height: 240)
        s.input.link = .live
        var m = Machines()
        m.rings = [four]; m.dials[10] = 255; m.steps = 15
        s.frame(c, time: 10, dt: 1 / 120)
        s.input.machines = m
        s.frame(c, time: 10.1, dt: 1 / 120)
        s.noteOn(channel: 0, note: 53, velocity: 100)
        m.steps = 16; m.told += 1
        s.input.machines = m
        #expect(s.report[0].contains("MIDI 1, pattern 0, EUCLID 0"))

        // the tumbler's bounces: as many as its balls make
        let b = Stage()
        b.input.link = .live
        var d = Machines(), real = Tombola(), bounced = 0
        d.tumbling = 1; d.dials = [200, 255, 80, 0] + [Int](repeating: 0, count: 8)
        real.balls = [.init(x: 0, y: 0, vx: 0.5, vy: 0, note: 60, flash: 0)]
        b.frame(c, time: 20, dt: 1 / 120)
        for k in 0..<600 {
            if k % 7 == 0 { d.balls = real.balls; d.turn = real.turn; d.told += 1; b.input.machines = d }
            real.step(1 / 120, dials: d.dials) { _, _ in bounced += 1 }
            b.frame(c, time: 20 + Double(k) / 120, dt: 1 / 120)
        }
        let struck = Int(b.report[0].split(separator: " ").last!)!
        #expect(bounced > 3 && abs(struck - bounced) <= 1 + bounced / 4, "\(struck) of \(bounced)")
    }

    /// The red page: as the OS's own bytes told it in the simulator (Firmware/tools/test_tell.py, SHOW=1), and drawn.
    @Test @MainActor func theRedPage() {
        var p: [UInt8] = [4, 2, 1, 3, 0, 153, 153, 0, 9, 0, 64, 0, 60, 67]
        let r = RedPage(p)!
        #expect(r.track == 4 && r.notes == [60, 67] && r.more && !r.waiting && r.step == 3)
        let g = Groove.library.map(\.name), all = Progressions.all.map(\.name)
        #expect(r.reading(0, grooves: g, progressions: all) == "TRESILLO" && r.reading(1, grooves: g, progressions: all) == "1/16" && r.reading(6, grooves: g, progressions: all) == "1 BAR")
        #expect(r.reading(4, grooves: g, progressions: all) == all[((9 * 134) >> 8) - 1])
        p[0] = 1; #expect(RedPage(p)!.reading(4, grooves: g, progressions: all) == "OFF")                    // a drum track has none
        for v in 0...255 { var q = r; q.dials = [Int](repeating: v, count: 8); for k in 0..<8 { #expect(!q.reading(k, grooves: g, progressions: all).contains("?")) } }
        #expect(RedPage([]) == nil && RedPage([9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]) == nil && RedPage([1, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 60]) == nil)
        // the OS's tables have the app's order
        let h = try! String(contentsOf: URL(filePath: #filePath).appending(path: "../../../../../Firmware/pages/groove_data.h").standardized, encoding: .utf8)
        let names = h.matches(of: /\/\* ([^*]+) \*\/\n/).map { String($0.1) }
        #expect(names.filter { g.contains($0) || all.contains($0) }.count >= 202 && Array(names.dropFirst(names.firstIndex(of: g[0])!).prefix(69)) == g)
        let from = names.lastIndex(of: "ROYAL ROAD")!
        #expect(Array(names[from..<from + 133]) == all)
        let c = StateSyncClient()
        _ = c.receive(SysEx.frame(0x72, p), now: 1)
        #expect(c.red?.track == 1)
        for (w, h) in [(180, 140), (235, 460), (430, 200), (640, 480)] {
            let s = StageTests().stage(), d = DotCanvas(width: w, height: h)
            s.linkFade.jump(1); s.select(track: 4); s.page = .track
            var m = Machines(); m.track = 4; m.page = 6
            s.input.machines = m; s.input.red = r
            #expect(s.redPage != nil)
            for k in 0..<4 { s.frame(d, time: 50 + Double(k) / 60, dt: 1 / 60) }
            s.select(track: 5); #expect(s.redPage == nil)
        }
    }

    @Test @MainActor func everythingOfItDraws() {
        for (w, h) in [(180, 140), (235, 460), (300, 215), (430, 200), (640, 480)] {
            let s = StageTests().stage(), c = DotCanvas(width: w, height: h)
            s.linkFade.jump(1)
            for track in [0, 3, 4, 7, 8, 15] { for page in 0...7 { for n in [0, 1, 8] {
                var m = Machines()
                m.track = track; m.page = page; m.more = n == 1; m.pick = n; m.waiting = n == 8
                m.tumbling = n > 0 ? 0xFF : 0; m.latched = n > 0 ? 0xFF : 0
                m.rings = (0..<n).map { Machines.Ring(key: $0 * 16, steps: 2 + $0 * 2, pulses: 1 + $0, rotation: $0) }
                m.balls = (0..<n).map { Machines.Ball(x: Double($0) / 10 - 0.4, y: 0.2, vx: 1, vy: -1, note: $0 * 18, flash: 1) }
                m.told = 1
                s.input.machines = m
                s.select(track: track)
                for p in [Stage.Page.fx, .track] { s.page = p; for k in 0..<3 { s.frame(c, time: 900 + Double(k) / 60, dt: 1 / 60) } }
            } } }
            s.input.machines = nil
            s.page = .fx
            s.frame(c, time: 901, dt: 1 / 60)
            #expect((0..<c.count).contains { c.dots[$0] != 0 })
        }
    }

    @Test func thePageThatIsOnIsTheOneShown() {
        let s = StageTests().stage()
        var m = Machines()
        m.track = 4; m.page = 4
        s.input.machines = m
        s.select(track: 4)
        #expect(s.machinePage == .tumbler)
        m.page = 5; s.input.machines = m
        #expect(s.machinePage == .euclid)
        m.page = 3; s.input.machines = m
        #expect(s.machinePage == nil)
        m.page = 4; s.input.machines = m
        s.select(track: 5)                                                  // looking at another one here
        #expect(s.machinePage == nil)
    }
}
