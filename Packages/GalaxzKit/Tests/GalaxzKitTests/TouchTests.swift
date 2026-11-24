import DotKit
@testable import OPZModel
import ChopKit
@testable import OPZPlay
@testable import OPZStage
import Testing

/// What fingers do on the screens, as the MIDI that goes to the OP-Z.
@Suite struct TouchTests {
    final class Desk {
        let s = StageTests().stage(), c: DotCanvas
        var sent: [OPZCommand] = [], t = 100.0
        init(_ page: Stage.Page, _ w: Int = 360, _ h: Int = 240, track: Int = 5) {
            c = DotCanvas(width: w, height: h)
            s.linkFade.jump(1)
            s.out = { [unowned self] in sent.append($0.command) }
            s.select(track: track)
            s.page = page
            draw(40)
            sent = []
        }
        func draw(_ n: Int = 1) { for _ in 0..<n { t += 1 / 60; s.frame(c, time: t, dt: 1 / 60) } }
        func box(_ want: (Grip) -> Bool) -> DotRect? { for (r, w) in s.touches { if case .grip(let g) = w, want(g) { return r } }; return nil }
        func tap(_ r: DotRect, left: Bool = false) { let x = left ? r.x + 2 : r.midX + 2; #expect(s.grab(1, x, r.midY)); s.release(1, x, r.midY); draw() }
        /// A chooser's left edge goes back, its right edge on.
        func tap(_ c: Choice, left: Bool = false) {
            let r = box { $0 == .choose(c) }!, x = left ? r.x + 2 : r.maxX - 3
            #expect(s.grab(1, x, r.midY)); s.release(1, x, r.midY); draw()
        }
    }

    @Test func theMixer() {
        for (w, h) in [(360, 240), (235, 460)] {
            let d = Desk(.mix, w, h)
            let fader = d.box { $0 == .gain(2) }!
            // Touching is not moving
            #expect(d.s.grab(1, fader.midX, fader.midY) && d.sent.isEmpty)
            let was = Int((d.s.gain(2) * 127).rounded())
            for k in 1...20 { d.s.drag(1, fader.midX, fader.midY + k * 2); d.draw() }
            d.s.release(1, fader.midX, fader.midY + 40)
            let values = d.sent.compactMap { if case .gain(2, let v) = $0 { v } else { nil } }
            #expect(values.count > 4 && values.count == d.sent.count && values.first! < was && zip(values, values.dropFirst()).allSatisfy { $1 < $0 })
            // two at once
            d.sent = []
            let a = d.box { $0 == .gain(0) }!, b = d.box { $0 == .gain(7) }!
            _ = d.s.grab(1, a.midX, a.midY); _ = d.s.grab(2, b.midX, b.midY)
            d.s.drag(1, a.midX, a.midY + 30); d.s.drag(2, b.midX, b.midY + 60)
            d.s.release(1, 0, 0); d.s.release(2, 0, 0)
            #expect(d.sent.contains { if case .gain(0, _) = $0 { true } else { false } } && d.sent.contains { if case .gain(7, _) = $0 { true } else { false } })
            d.sent = []
            let m = d.box { $0 == .mute(1) }!, muted = d.s.grid.muted[1]
            d.tap(m)
            #expect(d.sent == [.mute(track: 1, on: !muted)])
            d.sent = []
            let pan = d.box { $0 == .sound(4, 10, across: true) }!
            _ = d.s.grab(1, pan.midX, pan.midY); d.s.drag(1, pan.midX + 15, pan.midY); d.s.release(1, pan.midX + 15, pan.midY)
            #expect(d.sent.contains { if case .sound(4, 10, _) = $0 { true } else { false } })
            // a tap on a column is what it was: the track, and again its page
            d.sent = []
            d.s.select(track: 0)
            d.tap(d.box { $0 == .gain(3) }!)
            #expect(d.s.track == 3 && d.s.page == .mix)
            d.tap(d.box { $0 == .gain(3) }!)
            #expect(d.s.page == .track && d.sent.isEmpty)
        }
    }

    @Test func dialsAndPatterns() {
        let d = Desk(.track)
        let dial = d.box { if case .sound(5, _, _) = $0 { true } else { false } }!
        _ = d.s.grab(1, dial.midX, dial.midY)
        d.s.drag(1, dial.midX, dial.midY - 30)
        d.s.release(1, dial.midX, dial.midY - 30)
        #expect(!d.sent.isEmpty && d.sent.allSatisfy { if case .sound(5, _, _) = $0 { true } else { false } })
        let e = Desk(.song)
        e.tap(e.box { $0 == .pattern(6) }!)
        #expect(e.sent == [.pattern(project: e.s.input.address!.project, 6)])
    }

    @Test func padsPlayTheTrack() {
        for (w, h) in [(360, 240), (235, 460)] { for track in [0, 5, 7, 13] {
            let d = Desk(.play, w, h, track: track)
            let boxes = d.s.touches.compactMap { r, g -> (DotRect, Int, Int)? in if case .grip(.key(let k, let n)) = g { (r, k, n) } else { nil } }
            #expect(boxes.count >= (track < 4 ? 24 : 30) && boxes.allSatisfy { $0.0.w >= 12 && $0.0.h >= 8 }, "\(boxes.count)")
            #expect(zip(boxes, boxes.dropFirst()).allSatisfy { $0.2 < $1.2 })
            let (a, b) = (boxes[2], boxes[9])
            #expect(d.s.grab(1, a.0.midX, a.0.midY) && d.s.grab(2, b.0.midX, b.0.midY))
            d.draw(3)
            d.s.release(1, a.0.midX, a.0.midY)
            d.s.drag(2, boxes[10].0.midX, boxes[10].0.midY)                               // over to the next pad
            d.s.release(2, 0, 0)
            let on = d.sent.compactMap { if case .noteOn(track, let n, let v) = $0, v > 0 { n } else { nil } }, off = d.sent.compactMap { if case .noteOff(track, let n) = $0 { n } else { nil } }
            #expect(on == [a.2, b.2, boxes[10].2] && Set(off) == Set(on) && d.sent.count == 6)
        } }
    }

    @Test func chordsHoldAndDroneOnThePads() {
        let d = Desk(.play, track: 7)
        d.tap(.tool)
        #expect(d.s.player.settings.tool == .triad)
        d.tap(.tool, left: true)
        #expect(d.s.player.settings.tool == .off)
        for _ in 0..<6 { d.tap(.tool) }
        #expect(d.s.player.settings.tool == .progression)
        let first = d.s.player.settings.progression
        d.tap(.progression)
        #expect(d.s.player.settings.progression != first)
        d.tap(.hold)
        let pad = d.box { if case .key(8, _) = $0 { true } else { false } }!
        d.sent = []
        d.tap(pad)
        #expect(d.sent.filter { if case .noteOn = $0 { true } else { false } }.count >= 3 && !d.sent.contains { if case .noteOff = $0 { true } else { false } })
        let begun = d.sent.count
        d.tap(.panic)
        #expect(d.sent.count == begun * 2 && d.s.player.isEmpty)
        // a groove plays what is kept, with the pattern, and stops with it
        d.tap(.hold, left: true); d.tap(.hold)
        d.tap(.groove)
        #expect(d.s.player.settings.groove != nil)
        d.tap(pad)
        d.sent = []
        d.draw(240)
        #expect(d.sent.filter { if case .noteOn = $0 { true } else { false } }.count > 8)
        d.s.letGo()
        d.sent = []
        d.draw(60)
        #expect(d.sent.isEmpty)
    }

    @Test func thePerformanceBay() {
        for (w, h) in [(360, 240), (235, 460)] {
            let d = Desk(.perform, w, h)
            let pads = (0..<16).compactMap { p in d.box { $0 == .move(p) } }
            #expect(pads.count == 16 && pads.allSatisfy { $0.maxX <= w && $0.maxY <= h })
            let gate = pads[0]
            _ = d.s.grab(1, gate.midX, gate.midY)
            d.draw(120)
            #expect(d.sent.contains { if case .gain(_, 0) = $0 { true } else { false } })
            d.s.release(1, gate.midX, gate.midY)
            var gains: [Int: Int] = [:]
            for c in d.sent { if case .gain(let t, let v) = c { gains[t] = v } }
            #expect(gains.count == 8 && gains.values.allSatisfy { $0 == 127 })             // put back
            // the gallery loads another, and takes it off
            d.tap(.gallery)
            d.tap(d.box { if case .load(let m) = $0 { m == "tresillo" } else { false } }!)
            #expect(d.s.bay.slots[0]?.id == "tresillo")
            if let off = d.box({ $0 == .load(nil) }) { d.tap(off); #expect(d.s.bay.slots[0] == nil) }
            d.tap(.gallery)
            // latched
            d.tap(.latch)
            d.tap(pads[9])
            #expect(!d.s.performer.isEmpty)
            d.tap(pads[9])
            #expect(d.s.performer.isEmpty)
            d.tap(pads[2])
            let bar = d.box { $0 == .amount }!
            _ = d.s.grab(1, bar.x + bar.w / 2, bar.midY); d.s.drag(1, bar.x - 40, bar.midY); d.s.release(1, 0, 0)
            #expect(d.s.bay.slots[2]!.amount < 0.6)
            d.s.letGo()
            #expect(d.s.performer.isEmpty)
        }
    }

    @Test func chops() {
        for (w, h) in [(360, 240), (235, 460), (303, 228), (720, 300)] {
            let d = Desk(.chops, w, h)
            d.s.chops.list = SungVoice.kit.chops; d.s.chops.shape = SungVoice.kit.shape(320); d.s.chops.length = SungVoice.kit.audio.count; d.s.chops.own = true
            var asked: [ChopAsk] = []
            d.s.ask = { asked.append($0) }
            d.draw(2)
            let pads = (0..<24).compactMap { k in d.box { $0 == .chop(k) } }
            #expect(pads.count == 24 && pads.allSatisfy { $0.w >= 14 && $0.h >= 8 && $0.maxX <= w && $0.maxY <= h }, "\(w)x\(h)")
            _ = d.s.grab(1, pads[5].midX, pads[5].midY); _ = d.s.grab(2, pads[6].midX, pads[6].midY)
            d.s.release(1, 0, 0); d.s.release(2, 0, 0)
            #expect(asked.count == 4 && d.s.chops.chosen == 6)
            if case .start(5, _, let id, 0) = asked[0] { #expect(asked[2] == .stop(id: id)) } else { Issue.record("\(asked)") }
            asked = []
            let dial = d.box { $0 == .chopDial(2) }!
            _ = d.s.grab(1, dial.midX, dial.midY); d.s.drag(1, dial.midX, dial.midY - 40); d.s.release(1, 0, 0)
            #expect(asked.last == .keep && asked.contains { if case .dial(2, let x) = $0 { abs(x - 0.5) < 0.02 } else { false } })
            d.tap(.view); asked = []
            let echo = d.box { $0 == .effect(Effect.Kind.echo.rawValue) }!
            _ = d.s.grab(1, echo.x + 3, echo.midY); d.s.release(1, echo.x + 3, echo.midY)      // shown
            #expect(d.s.chops.effect == 9 && !d.s.chops.effects[9].on)
            d.tap(echo)                                                      // touched again: on
            #expect(d.s.chops.effects[9].on && asked.contains(.effect(d.s.chops.effects[9])))
            let e = d.box { $0 == .effectDial(1) }!
            _ = d.s.grab(1, e.midX, e.midY); d.s.drag(1, e.midX, e.midY - 20); d.s.release(1, 0, 0)
            #expect(d.s.chops.effects[9].dials[1] > 0.6)
            d.tap(.view); asked = []
            d.tap(.reverse)
            #expect(asked == [.edited(d.s.chops.list)] && d.s.chops.list[6].reverse)
            let p = d.box { $0 == .edit(0) }!
            _ = d.s.grab(1, p.midX, p.midY); d.s.drag(1, p.midX, p.midY - 20); d.s.release(1, 0, 0)
            #expect(d.s.chops.list[6].pitch == 12)
            asked = []
            d.tap(.record); #expect(asked == [.record(.mic)])
            d.s.chops.recording = true; d.draw(); asked = []; d.tap(.record); #expect(asked == [.stopRecording])
            d.s.chops.recording = false; d.tap(.source); d.tap(.source); asked = []; d.tap(.record); #expect(asked == [.open])
            asked = []; d.tap(.kit, left: true); d.tap(.cut); #expect(asked == [.kit(-1), .cut(.eight)])
            // MODULE
            asked = []
            d.s.module(note: 53, velocity: 127); d.s.module(note: 76, velocity: 127); d.s.module(note: 77, velocity: 1); d.s.module(note: 52, velocity: 1); d.s.moduleOff(note: 53)
            #expect(asked.compactMap { if case .start(let n, _, _, _) = $0 { n } else { nil } } == [0, 23, 0, 23])
            asked = []; d.tap(.keys); asked = []
            d.s.module(note: 67, velocity: 127)
            #expect(asked == [.start(6, velocity: 1, id: 5067, semitones: 7)])
            d.s.module(cc: 1, value: 127)
            #expect(d.s.chops.dials[0] == 1)
            d.tap(.module); asked = []
            d.s.module(note: 60, velocity: 1); d.s.module(cc: 1, value: 0)
            #expect(asked.isEmpty && d.s.chops.dials[0] == 1)
        }
    }

    /// LIGHTS' notes are PERFORM's pads, when that is on.
    @Test func lightsPlayThePads() {
        let d = Desk(.perform)
        d.s.light(note: 53, on: true)
        #expect(d.s.performer.isEmpty)
        d.tap(.lights)
        d.s.light(note: 53, on: true); d.draw(30)
        #expect(d.s.performer.active == [0] && !d.sent.isEmpty)
        d.s.light(note: 69, on: false)                                      // sixteen on: the same pad
        #expect(d.s.performer.isEmpty)
        d.s.light(note: 60, on: true); d.tap(.lights)
        #expect(d.s.performer.isEmpty)
    }

    /// SCREEN held, the first dial: the tabs go by. Not held: they do not.
    /// While SCREEN is down the dials do not reach the sound (the OS's SCREEN screen sends them as CC 105-108): a sound value that
    /// changes then is not a page.
    @Test func screenAndTheFirstDialTurnThePages() {
        let d = Desk(.track)
        var i = d.s.input
        var b = i.bank!.bytes; b[i.address!.pattern * OPZ.patternSize + OPZ.soundAt + 5 * 18] = 200; i.bank = Bank(b); i.revision += 1; i.panel.screen = true
        d.s.input = i
        #expect(d.s.page == .track)
        for _ in 0..<2 * Int(Stage.jogClicks) { _ = d.s.screenDial(0, value: 1) }
        #expect(d.s.page == .mix)
        for _ in 0..<Int(Stage.jogClicks) { _ = d.s.screenDial(0, value: 127) }
        #expect(d.s.page == .grid)
    }

    @Test func thePanelsKeys() {
        var p = PanelState()
        #expect(p.receive(0x06, [0x00, 0x1F, 0x1F, 0x00]) && !p.screen && !p.shift && !p.trackKey && p.heldStep == nil)
        #expect(p.receive(0x06, [0x40, 0x3F, 0x3F, 0x01]) && p.screen && p.shift && p.trackKey && !p.recording && p.page == 1)
    }

    /// Learned controls do what their target says.
    @Test func targets() {
        let d = Desk(.track)
        d.s.set(.gain(track: 3), to: 64); d.s.set(.sound(track: nil, param: 8), to: 10)
        #expect(d.sent == [.gain(track: 3, value: 64), .sound(track: 5, param: 8, value: 10)] && d.s.value(of: .gain(track: 3)) == 64)
        d.sent = []
        #expect(d.s.press(.mute(track: 0), velocity: 1) && d.s.press(.nextPattern, velocity: 1) && d.s.press(.play, velocity: 1) && d.s.press(.play, velocity: 0))
        #expect(d.sent.count == 3)
        _ = d.s.press(.page(by: 1), velocity: 1)
        #expect(d.s.page == .grid && !d.s.press(.keys, velocity: 1))
        d.sent = []
        d.s.keyDown(60, velocity: 90); d.s.keyUp(60)
        #expect(d.sent == [.noteOn(track: 5, note: 60, velocity: 90), .noteOff(track: 5, note: 60)])
        // the encoders turn what the selected track's page shows: SOUND's P1 P2 FILTER RESO, then ENVELOPE's
        d.sent = []
        d.s.set(.encoder(2), to: 30)
        #expect(d.sent == [.sound(track: 5, param: 8, value: 30)] && d.s.value(of: .encoder(2)) == 30 && Target.encoder(2).continuous)
        d.s.input.panel.page = 1
        d.sent = []
        d.s.set(.encoder(0), to: 99)
        #expect(d.sent == [.sound(track: 5, param: 2, value: 99)] && d.s.value(of: .encoder(0)) == 99)
    }

    /// A finger dragged along a chooser goes through its values as it goes, and they are kept once, when it lets go.
    @Test func draggingGoesThroughTheValues() {
        for (w, h) in [(360, 240), (235, 460), (180, 140), (453, 228)] {
            let d = Desk(.play, w, h, track: 7)
            var keeps = 0
            d.s.kept = { keeps += 1 }
            d.s.player.settings.tool = .progression
            d.draw()
            let r = d.box { $0 == .choose(.progression) }!, first = Progressions.index(named: d.s.player.settings.progression)!
            #expect(d.s.grab(1, r.x + 3, r.midY))
            var seen = Set<String>()
            for k in 1...10 { d.s.drag(1, r.x + 3 + k * 4, r.midY); d.draw(); seen.insert(d.s.player.settings.progression) }
            #expect(seen.count == 10 && keeps == 0, "\(w)x\(h)")                            // live, one a step
            d.s.release(1, r.x + 43, r.midY)
            #expect(Progressions.index(named: d.s.player.settings.progression) == first + 10 && keeps == 1)
            // up goes on too, down back; past the first it comes round
            _ = d.s.grab(1, r.midX, r.midY); d.s.drag(1, r.midX, r.midY + 60); d.s.release(1, r.midX, r.midY + 60)
            #expect(Progressions.index(named: d.s.player.settings.progression) == (first + 10 - 15 + Progressions.all.count) % Progressions.all.count)
            // a short list goes slower; OCTAVE stops at its end
            let o = d.box { $0 == .choose(.octave) }!
            _ = d.s.grab(2, o.midX, o.midY); d.s.drag(2, o.midX - 200, o.midY); d.s.release(2, o.midX - 200, o.midY)
            #expect(d.s.octave == -3)
            d.s.letGo()
            // a switch is not dragged through
            d.draw()
            let p = d.box { $0 == .choose(.panic) }!
            d.sent = []; keeps = 0
            _ = d.s.grab(1, p.x + 2, p.midY); d.s.drag(1, p.x + 40, p.midY); d.s.release(1, p.x + 40, p.midY)
            #expect(keeps == 0)
        }
        // a groove dragged through ends its notes the way a tap does
        let d = Desk(.play, track: 7)
        d.s.player.settings.groove = Groove.library[0].name
        d.draw()
        let g = d.box { $0 == .choose(.groove) }!
        _ = d.s.grab(1, g.x + 3, g.midY); d.s.drag(1, g.x + 3 + 20, g.midY); d.s.release(1, g.x + 23, g.midY)
        #expect(d.s.player.settings.groove == Groove.library[5].name)
    }

    /// The middle of a long choice opens all its values: one tapped is chosen and it closes; dragged, it scrolls; its top closes it.
    @Test func pickingFromTheList() {
        for (w, h) in [(360, 240), (235, 460), (180, 140), (453, 228)] {
            let d = Desk(.play, w, h, track: 7)
            d.s.player.settings.tool = .progression
            d.draw()
            let r = d.box { $0 == .choose(.progression) }!
            d.tap(r)                                                                     // its middle
            #expect(d.s.picking?.choice == .progression, "\(w)x\(h)")
            func cells() -> [(DotRect, Int)] { d.s.touches.compactMap { if case .grip(.pick(let i)) = $0.1, i >= 0 { ($0.0, i) } else { nil } } }
            let body = d.box { $0 == .pick(-1) }!
            #expect(cells().count >= 8 && cells().allSatisfy { $0.0.w >= 20 && $0.0.h >= 8 && body.contains($0.0.x, $0.0.y) && $0.0.maxX <= body.maxX && $0.0.maxY <= body.maxY }, "\(cells().map(\.0)) \(body)")
            // scrolled down, others come into sight
            let last = cells().map(\.1).max()!
            #expect(d.s.grab(1, body.midX, body.midY + 30)); for k in 1...20 { d.s.drag(1, body.midX, body.midY + 30 - k * 4) }; d.s.release(1, body.midX, body.midY - 50)
            d.draw()
            #expect(d.s.picking != nil && cells().map(\.1).max()! > last, "\(w)x\(h)")
            // one chosen: what a tap chooses, and closed
            let (cell, i) = cells().last!
            d.tap(cell)
            #expect(d.s.player.settings.progression == Progressions.all[i].name && d.s.picking == nil)
            // the grooves; the top closes them
            d.tap(d.box { $0 == .choose(.groove) }!)
            #expect(d.s.picking?.choice == .groove)
            d.tap(d.box { $0 == .unpick }!)
            #expect(d.s.picking == nil && d.s.player.settings.groove == nil)
            d.tap(d.box { $0 == .choose(.groove) }!)
            d.tap(cells().first { $0.1 == 3 }!.0)
            #expect(d.s.player.settings.groove == Groove.library[2].name)
            // the edges still go one at a time; a short list's middle goes on
            d.tap(.scale); d.tap(.scale); d.tap(.scale, left: true)
            #expect(d.s.player.settings.scale == .major && d.s.picking == nil)
            d.tap(d.box { $0 == .choose(.hold) }!)
            #expect(d.s.player.settings.hold == .hold && d.s.picking == nil)
            // another page closes it
            d.tap(d.box { $0 == .choose(.key) }!)
            #expect(d.s.picking?.choice == .key)
            d.s.page = .mix; d.draw(); d.s.page = .play; d.draw()
            #expect(d.s.picking == nil)
        }
    }
}
