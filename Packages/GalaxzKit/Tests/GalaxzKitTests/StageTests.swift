import Foundation
import Testing
@testable import DotKit
@testable import OPZLink
@testable import OPZModel
@testable import OPZStage

@Suite struct DotKitTests {
    @Test func drawingOutsideIsIgnored() {
        let c = DotCanvas(width: 20, height: 10)
        c.clear()
        for x in [-1000, -1, 20, 1000] { for y in [-1000, -1, 10, 1000] { c.set(x, y, .white); c.add(x, y, .white) } }
        c.fill(DotRect(-50, -50, 40, 40), .white)
        c.disc(-30, -30, 5, .white); c.arc(400, 400, 20, .white); c.line(-90, 50, -10, 90, .white)
        c.text("OUTSIDE", -200, -50, .white); c.pill(DotRect(50, 50, 9, 9), .white, radius: 4); c.frame(DotRect(90, 2, 5, 5), .white, radius: 2)
        #expect((0..<c.count).allSatisfy { c.dots[$0] == 0 })
        c.glow(.infinity, 3, .white, 0)      // nothing asked for, nothing done
    }

    @Test func mixingAndClipping() {
        let c = DotCanvas(width: 8, height: 8)
        c.set(1, 1, .white)
        c.set(1, 1, .black, 0.5)
        #expect(abs(Int(c[1, 1].r) - 127) < 3)
        c.add(2, 2, DotColor(200, 100, 0)); c.add(2, 2, DotColor(200, 100, 0))
        #expect(c[2, 2] == DotColor(255, 200, 0))
        c.clipped(DotRect(4, 4, 2, 2)) { c.fill(DotRect(0, 0, 8, 8), .white) }
        #expect(c[4, 4] == .white && c[3, 4] == .black && c[6, 6] == .black)
        c.fill(DotRect(0, 7, 8, 1), .white)
        #expect(c[0, 7] == .white)
    }

    @Test func resizing() {
        let c = DotCanvas(width: 4, height: 4)
        c.resize(30, 2)
        #expect(c.width == 30 && c.height == 2 && c.count == 60)
        c.set(29, 1, .white)
        #expect(c[29, 1] == .white)
        c.resize(0, 5)
        #expect(c.width == 30)
    }

    @Test func type() {
        for f in [DotFont.tiny, .small, .big, .huge] {
            for s in (33...95).compactMap({ UnicodeScalar($0) }) where !"\\^;".unicodeScalars.contains(s) || f !== DotFont.tiny {
                if "^\\`".unicodeScalars.contains(s) { continue }
                #expect(!f.glyph(s).dots.isEmpty, "\(s) at \(f.height)")
                #expect(f.glyph(s).dots.allSatisfy { $0.x >= 0 && $0.x < f.glyph(s).advance && $0.y >= 0 && $0.y < f.height })
            }
            #expect(f.width("") == 0 && f.width("AB") > f.width("A") && f.width("abc") == f.width("ABC"))
            #expect(f.width("111") == f.width("888"))           // figures stand under each other
            #expect(f.width(f.fitted("A VERY LONG NAME", 40)) <= 40)
            #expect(f.fitted("A", 200) == "A")
        }
        // letters that must not be taken for one another
        for (a, b) in ["HN", "KH", "OD", "VU", "MW", "0O"].map({ (Array($0.unicodeScalars)[0], Array($0.unicodeScalars)[1]) }) where !(a == "0") {
            let x = DotFont.tiny.glyph(a).dots.map { [$0.x, $0.y] }, y = DotFont.tiny.glyph(b).dots.map { [$0.x, $0.y] }
            #expect(x != y, "\(a) \(b)")
        }
    }

    @Test func turning() {
        for t in stride(from: -2.0, through: 2, by: 0.013) {
            #expect(abs(Turn.of(t).x - sin(t * 2 * .pi)) < 0.002 && abs(Turn.of(t).y + cos(t * 2 * .pi)) < 0.002)
        }
        #expect(Turn.of(500_000.25).x > 0.99)                   // after days switched on
    }

    @Test func springsSettleAtAnyFrameRate() {
        for dt in [1.0 / 240, 1.0 / 120, 1.0 / 60, 1.0 / 8, 2.0] {
            var s = Spring(0)
            s.target = 1
            for _ in 0..<Int(6 / min(dt, 0.1)) { s.step(dt); #expect(s.value > -0.5 && s.value < 1.6) }
            #expect(s.settled && s.value == 1)
        }
    }
}

@Suite struct StageTests {
    static let project: (Bank, PatternAddress) = { let c = Vector.shared.replay(); return (c.bank!, c.bankAddress!) }()

    func stage(playing: Bool = true) -> Stage {
        let s = Stage()
        var i = StageInput()
        i.link = .live; i.linkName = "USB"; i.bank = Self.project.0; i.address = Self.project.1; i.revision = 1; i.tempo = 120
        i.panel.playing = playing
        for t in 0..<16 { i.sounds[t] = Sound(plug: Int(i.bank!.track(i.address!.pattern, t).plug), settings: nil) }
        s.input = i
        return s
    }

    /// Four on the floor as a track of one step four sixteenths long: it is always on its step, and begins it each time.
    @Test func aTrackOfOneStepIsStruckEachTime() {
        var bytes = Self.project.0.bytes
        let p = Self.project.1.pattern, at = p * OPZ.patternSize
        (bytes[at + 4], bytes[at + 6]) = (1, 4)                                  // the kick: one step, length 4
        let note = at + OPZ.notesAt
        bytes.replaceSubrange(note..<note + 8, with: [0x10, 0x27, 0, 0, 53, 100, 0, 0])
        for g in 0..<10 { bytes[at + 21_344 + g * 4] = 0 }                        // nothing muted
        let s = Stage(), c = DotCanvas(width: 320, height: 240)
        var i = StageInput()
        i.link = .live; i.bank = Bank(bytes); i.address = Self.project.1; i.revision = 1; i.tempo = 120
        s.frame(c, time: 50, dt: 1 / 120)
        s.input = i
        var t = 50.0, rises = 0, last = 0.0
        i.panel.playing = true
        s.input = i
        while t < 57.9 {                                                        // 16 beats of half a second
            t += 1 / 120.0
            if Int((t - 50) / 2) > Int((t - 1 / 120.0 - 50) / 2) { i.panel.told += 1; i.panel.positions = [UInt8](repeating: 0, count: 16); s.input = i }   // it comes round
            s.frame(c, time: t, dt: 1 / 120)
            if s.hits[0] > last + 0.1 { rises += 1 }
            last = s.hits[0]
        }
        #expect((15...17).contains(rises), "\(rises)")
    }

    @Test func everyPageAndEverySoundDrawsAtEverySize() {
        for (w, h) in [(1, 1), (40, 400), (400, 40), (120, 120), (200, 150), (240, 320), (222, 480), (320, 240), (640, 640), (640, 200)] {
            let s = stage(), c = DotCanvas(width: w, height: h)
            s.linkFade.jump(1)
            for p in Stage.Page.allCases {
                s.page = p
                for t in 0..<16 {
                    s.select(track: t)
                    s.noteOn(channel: t, note: [0, 60, 127][t % 3], velocity: 127)
                    for k in 0..<2 { s.frame(c, time: 500_000 + Double(t * 2 + k) / 60, dt: 1 / 60) }
                }
            }
        }
    }

    /// SHOW: every scene, playing and stopped, the lights and motion tracks struck, at the smallest size and the usual one; its scene name and
    /// AUTO answer a touch; it is never still, so it drifts when nothing plays.
    @Test func everySceneOfTheShowDraws() {
        for (w, h) in [(180, 140), (360, 240), (235, 460)] {
            for playing in [true, false] {
                let s = stage(playing: playing), c = DotCanvas(width: w, height: h)
                s.linkFade.jump(1)
                s.page = .show
                s.showAuto = false
                var t = 700.0
                for scene in 0..<Stage.showScenes.count {
                    s.showScene = scene
                    #expect(s.showScene == scene)
                    for k in 0..<24 {
                        if k % 6 == 0 { for ch in [0, 1, 4, 7, 14, 15] { s.noteOn(channel: ch, note: [0, 60, 77, 127][k / 6], velocity: 20 + k * 4) } }
                        t += 1 / 60
                        s.frame(c, time: t, dt: 1 / 60)
                    }
                    #expect((0..<c.count).filter { c.dots[$0] & 0xFFFFFF != 0 }.count > 300, "\(Stage.showScenes[scene]) \(w)x\(h)")
                }
                #expect(!s.still)
                // the name: its right half the next scene; AUTO turns them going by itself on
                let name = s.touches.first { if case .grip(.choose(.scene)) = $0.1 { true } else { false } }!.0
                let id = 1
                #expect(s.grab(id, name.maxX - 2, name.midY)); s.release(id, name.maxX - 2, name.midY)
                #expect(s.showScene == 0)
                s.frame(c, time: t + 1, dt: 1 / 60)
                let auto = s.touches.first { if case .grip(.choose(.showAuto)) = $0.1 { true } else { false } }!.0
                #expect(auto.maxX <= w && s.grab(id, auto.midX, auto.midY)); s.release(id, auto.midX, auto.midY)
                #expect(s.showAuto)
                for k in 0..<(8 * 60) { s.frame(c, time: t + 2 + Double(k) / 15, dt: 1 / 15) }       // 32 s: on by itself
                #expect(s.showScene != 0)
            }
        }
    }

    /// The tabs fit, however small: every page's name ends before the next begins, and before SETTINGS.
    @Test func theTabsFit() {
        for (w, h) in [(180, 140), (235, 460), (300, 215), (360, 240)] {
            let s = stage(), c = DotCanvas(width: w, height: h)
            s.linkFade.jump(1)
            s.frame(c, time: 1, dt: 1 / 60)
            let tabs = s.touches.compactMap { r, t -> DotRect? in if case .page = t { r } else { nil } }
            let set = s.touches.first { if case .action(.settings) = $0.1 { true } else { false } }!.0
            #expect(tabs.count == Stage.Page.allCases.count)
            #expect(zip(tabs, tabs.dropFirst()).allSatisfy { $0.maxX <= $1.x + 1 } && tabs.last!.maxX <= set.x + 1, "\(w)x\(h)")
        }
    }

    @Test func everyKindOfEngineHasItsLook() {
        let c = DotCanvas(width: 200, height: 120), s = stage()
        for kind in [VisualKind.wave, .fm, .string, .bars, .vowel, .chip, .piano, .drum, .hats, .snap, .sample, .space, .echo, .grain, .swirl, .filter, .dist,
                     .comp, .tape, .master, .punch, .module, .lights, .motion] {
            for v in [0.0, 0.5, 1.0] {
                c.clear()
                s.draw(kind, c, DotRect(0, 0, 200, 120), VisualInput(values: [Double](repeating: v, count: 18), colour: .white, hit: v, level: v, note: 60,
                                                                     velocity: v, strikes: [0.05, 0.3], seed: 3), 1 / 60)
                #expect((0..<c.count).contains { c.dots[$0] != 0 }, "\(kind) draws nothing at \(v)")
            }
        }
        for e in EngineCatalogue.byPlug.values { _ = VisualKind(track: e.kind == "fx" ? 8 : e.kind == "drum" ? 0 : 5, sound: Sound(plug: e.plug, settings: nil)) }
        #expect(VisualKind(track: 5, sound: Sound(plug: 61013, settings: nil)) == .fm)
        #expect(VisualKind(track: 8, sound: Sound(plug: 61004, settings: nil)) == .comp)
        #expect(VisualKind(track: 10, sound: nil) == .tape && VisualKind(track: 4, sound: nil) == .wave)
    }

    @Test func theTracksSoundWhereTheirPatternHasNotes() {
        let s = stage(), p = Self.project.1.pattern
        let c = DotCanvas(width: 320, height: 240)
        s.frame(c, time: 100, dt: 1 / 60)
        var heard = Set<Int>()
        for step in 0..<16 {
            var i = s.input
            i.panel.step = step
            i.panel.positions = [UInt8](repeating: UInt8(step) << 4, count: 16)
            i.panel.told += 1
            s.input = i
            for t in 0..<16 where s.hitFlashes[t].level > 0.3 { heard.insert(t) }
            for k in 0..<60 { s.frame(c, time: 100 + Double(step) + Double(k) / 60, dt: 1 / 60) }
        }
        let expected = Set((0..<16).filter { t in !Self.project.0.muted(p, t) && (0..<16).contains { !Self.project.0.notes(p, t, $0).isEmpty } })
        #expect(heard == expected)
    }

    @Test func notesOfOneTrackDoNotHideTheOthers() {
        let s = stage(), p = Self.project.1.pattern, c = DotCanvas(width: 320, height: 240)
        let sounding = (0..<8).filter { t in !Self.project.0.muted(p, t) && (0..<16).contains { !Self.project.0.notes(p, t, $0).isEmpty } }
        var heard = Set<Int>()
        for step in 0..<16 {
            s.noteOn(channel: 7, note: 60, velocity: 100)
            var i = s.input
            i.panel.step = step
            i.panel.positions = [UInt8](repeating: UInt8(step) << 4, count: 16)
            i.panel.told += 1
            s.input = i
            for t in 0..<16 where s.hits[t] > 0.3 { heard.insert(t) }
            for k in 0..<30 { s.frame(c, time: 100 + Double(step) * 0.12 + Double(k) / 250, dt: 1 / 60) }
        }
        #expect(heard.isSuperset(of: sounding))
    }

    @Test func itFollowsTheOPZ() {
        let s = stage()
        s.select(track: 2)
        var i = s.input
        i.panel.track = 7
        s.input = i
        #expect(s.track == 7)
        s.select(track: 3)
        i.panel.step = 4             // something else changed: the choice made here stays
        s.input = i
        #expect(s.track == 3)
        s.select(track: 99)
        #expect(s.track == 15)
    }

    @Test func touching() {
        let s = stage(), c = DotCanvas(width: 320, height: 240)
        s.linkFade.jump(1)
        s.frame(c, time: 1, dt: 1 / 60)
        for (r, what) in s.touches { if case .page(.mix) = what { #expect(s.tap(r.midX, r.midY) == .none) } }
        #expect(s.page == .mix)
        s.frame(c, time: 2, dt: 1 / 60)
        let settings = s.touches.first { if case .action(.settings) = $0.1 { true } else { false } }!
        #expect(s.tap(settings.0.midX, settings.0.midY) == .settings)
        #expect(s.tap(-5, -5) == .none)
        s.turn(-3)
        #expect(s.page == .show)
        s.turn(1)
        #expect(s.page == .track)
    }

    @Test func theStartScreenHasPairingHubAndSettings() {
        for (w, h) in [(180, 140), (235, 460), (300, 215), (640, 480)] {
            let s = Stage(), c = DotCanvas(width: w, height: h)
            for pairing in [false, true] {
                s.showsPairing = pairing
                s.frame(c, time: 1, dt: 1 / 60)
                let boxes = s.touches.compactMap { r, t -> (DotRect, Stage.Action)? in if case .action(let a) = t { (r, a) } else { nil } }
                #expect(boxes.map(\.1) == (pairing ? [.pair, .settings] : [.settings]))
                #expect(boxes.allSatisfy { $0.0.x >= 0 && $0.0.maxX <= w })
                #expect(abs(boxes.first!.0.x + boxes.last!.0.maxX - w) <= 2)       // in the middle
                for (r, a) in boxes { #expect(s.tap(r.midX, r.midY) == a) }
            }
        }
    }

    @Test func aNewVersionShowsOnTheHubWhateverTheSize() {
        for (w, h) in [(222, 400), (320, 240)] {
            let s = stage(), c = DotCanvas(width: w, height: h)
            s.linkFade.jump(1)
            s.input.notice = "NEW: V10"
            s.frame(c, time: 1, dt: 1 / 60)
            #expect(s.touches.contains { if case .action(.hub) = $0.1 { true } else { false } })
        }
    }

    @Test func stillMeansStill() {
        let s = stage(playing: false), c = DotCanvas(width: 320, height: 240)
        s.page = .grid
        var t = 10.0
        for _ in 0..<2000 { t += 1 / 60; s.frame(c, time: t, dt: 1 / 60) }
        #expect(s.still)
        let before = (0..<c.count).map { c.dots[$0] }
        s.frame(c, time: t + 5, dt: 1 / 60)
        #expect(before == (0..<c.count).map { c.dots[$0] })
        s.noteOn(channel: 0, note: 60, velocity: 100)
        #expect(!s.still)
        var i = s.input
        i.panel.playing = true
        s.input = i
        #expect(!s.still)
    }

    @Test func theMeterOpensItsPage() {
        var b: [UInt8] = Array("GZL1".utf8)
        for v in [123, 90_000, 150_000, 200_000, 260_000, 3, 11, 14] { for k in 0..<4 { b.append(UInt8(v >> (8 * k) & 255)) } }
        b += [0, 0, 0]
        b.append(b.reduce(0, &+))
        var collector = LoadReport.Collector(), report: LoadReport?, taken = 0
        for (i, n) in b.flatMap({ [$0 >> 4, $0 & 15] }).enumerated() {
            let r = collector.note(24 + (i & 63), velocity: Int(n) + 1, at: 5 + Double(i) * 0.01)
            taken += r.taken ? 1 : 0
            if let x = r.report { report = x }
        }
        #expect(report?.instrumentsTop == 150_000 && report?.notesCut == 3 && report?.seconds == 12.3 && taken > 70)
        #expect(LoadReport(b.dropLast() + [b.last! ^ 1]) == nil)
        let s = stage()
        s.input.load = report
        #expect(s.page == .load)
        // music is not a report
        var m = LoadReport.Collector()
        #expect((0..<200).allSatisfy { !m.note(40 + $0 % 30, velocity: 90, at: Double($0)).taken })
    }

    /// The OS's own counting (0x8010a5a4, the tick at 0x801106e6), to hold the playhead to.
    struct TheOS {
        var tracks: [Playhead.Track], positions = [UInt8](repeating: 0, count: 16), step = 0
        mutating func sixteenth() {
            step = (step + 1) % 16
            for t in 0..<16 {
                let sub = Int(positions[t] & 15), s = Int(positions[t] >> 4)
                positions[t] = sub < tracks[t].length - 1 ? UInt8(s << 4 | (sub + 1)) : UInt8((s + 1) % tracks[t].count) << 4
            }
        }
    }

    @Test func thePlayheadCountsAsTheOSDoes() {
        var r = DotRandom(9)
        for clock in [true, false] { for round in 0..<20 {
            let tracks = (0..<16).map { _ in Playhead.Track(count: 1 + Int(r.unit() * 16), length: round == 0 ? 1 : 1 + Int(r.unit() * 8)) }
            var os = TheOS(tracks: tracks), p = Playhead()
            let tempo = 40 + Int(r.unit() * 160), sixteenth = 15.0 / Double(tempo)
            var now = 5000.0
            p.play(true, at: now)
            p.told(os.positions, step: 0, at: now)
            for k in 1...200 {
                for tick in 1...6 {
                    now += sixteenth / 6
                    if clock { p.tick(at: now) }
                    if tick == 6 { os.sixteenth() }
                    _ = p.advance(to: now + 1e-4, tempo: tempo, tracks: tracks)
                }
                #expect(p.step == os.step && (0..<16).allSatisfy { p.steps[$0] == os.positions[$0] >> 4 }, "clock \(clock) round \(round) at \(k)")
                if os.step == 0 { p.told(os.positions, step: 0, at: now) }          // once a pattern, as the OP-Z does
            }
            p.play(false, at: now)
            let moved = p.advance(to: now + 100, tempo: tempo, tracks: tracks)
            #expect(!moved)
        } }
    }

    @Test func thePlayheadIsPutRightByTheOPZ() {
        var p = Playhead()
        let tracks = [Playhead.Track](repeating: .init(), count: 16)
        p.play(true, at: 0)
        _ = p.advance(to: 1.0, tempo: 60, tracks: tracks)          // the tempo here is wrong: the OP-Z is faster
        #expect(p.step == 4)
        p.told([UInt8](repeating: 0x90, count: 16), step: 9, at: 1.0)
        #expect(p.step == 9 && p.steps[3] == 9)
        _ = p.advance(to: 1.26, tempo: 60, tracks: tracks)
        #expect(p.step == 10)
        // its clock stops coming: the tempo carries on from where the OP-Z last said
        p.tick(at: 1.3)
        _ = p.advance(to: 4, tempo: 60, tracks: tracks)
        #expect(p.step == (9 + 12) % 16)
        // nonsense does no harm
        p.told([1, 2], step: 99, at: 5)
        _ = p.advance(to: .infinity, tempo: -5, tracks: tracks)
        _ = p.advance(to: -1e9, tempo: 0, tracks: tracks)
        #expect(Playhead.Track(record: TrackRecord(plug: 0, stepCount: 0, timing: 0, stepLength: 9, quantize: 0, byte8: 0, noteLength: 0, lastNote: 0, byte11: 0)) == .init(count: 1, length: 16))
        #expect(Playhead.Track(record: TrackRecord(plug: 0, stepCount: 200, timing: 0, stepLength: 10, quantize: 0, byte8: 0, noteLength: 0, lastNote: 0, byte11: 0)) == .init(count: 16, length: 1))
    }

    @Test func theStagePlaysWithOneWordFromTheOPZ() {
        let s = stage(playing: false), c = DotCanvas(width: 320, height: 240)
        s.frame(c, time: 50, dt: 1 / 60)
        var i = s.input
        i.panel.playing = true
        s.input = i
        var seen: [Int] = []
        for k in 0..<240 { s.frame(c, time: 50 + Double(k) / 60, dt: 1 / 60); if seen.last != s.playhead.step { seen.append(s.playhead.step) } }
        #expect(seen.count >= 30 && zip(seen, seen.dropFirst()).allSatisfy { $1 == ($0 + 1) % 16 })     // 4 s at 120: 32 steps
        s.midi(playing: false)
        let at = s.playhead.step
        for k in 0..<60 { s.frame(c, time: 54 + Double(k) / 60, dt: 1 / 60) }
        #expect(s.playhead.step == at && !s.playhead.playing)
    }

    @Test func everyTrackHasItsOwnPages() {
        #expect((0..<16).allSatisfy { t in Palette.pages(t).allSatisfy { $0.params.count == 4 && $0.labels.count == 4 && $0.params.allSatisfy((0..<18).contains) } })
        #expect(Palette.pages(5).map(\.name) == ["SOUND", "ENVELOPE", "LFO", "SEND"] && Palette.pages(5)[3].colour == Palette.orange)
        #expect(Palette.pages(6)[2].name == "ARP" && Palette.pages(10)[1].name == "SEND" && Palette.pages(11).count == 1)
        #expect(Palette.pages(0, samples: true)[0].labels[0] == "PITCH" && Palette.pages(0)[0].labels[0] == nil)
        #expect(Palette.pages(4).flatMap(\.params).sorted() == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16])
    }

    @Test func chords() {
        #expect(Chord.name([60, 64, 67]) == "C" && Chord.name([57, 60, 64, 67]) == "AM7" && Chord.name([64, 67, 72]) == "C/E")
        #expect(Chord.name([60, 61, 62]) == nil && Chord.name([60, 67]) == nil && Chord.name([]) == nil)
    }

    @Test func aStepAtAGlanceIsTheStep() {
        let (b, a) = Self.project
        for p in [a.pattern, (a.pattern + 1) % 16] { for t in 0..<16 { for s in 0..<16 {
            let ns = b.notes(p, t, s), st = b.step(p, t, s), g = b.brief(p, t, s)
            #expect(g.notes == ns.count && g.velocity == ns.map(\.velocity).max() ?? 0 && g.component == !st.components.isEmpty && g.lock == !st.locks.isEmpty)
            if !ns.isEmpty { #expect(g.low == ns.map(\.note).min() && g.high == ns.map(\.note).max()) }
        } } }
    }

    @Test func anEditIsCheap() {
        let start = Date()
        for _ in 0..<200 { _ = PatternGrid(Self.project.0, Self.project.1.pattern) }
        print("pattern grid: \(Date().timeIntervalSince(start) / 200 * 1e6) us")
    }
}
