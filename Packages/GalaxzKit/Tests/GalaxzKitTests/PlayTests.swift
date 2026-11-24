import OPZModel
@testable import OPZPlay
import OPZLink
import Foundation
import Testing

@Suite struct PlayTests {
    @Test func commandsAreTheOPZsOwn() {
        #expect(OPZCommand.gain(track: 2, value: 100).bytes == [0xB2, 50, 100])
        #expect(OPZCommand.mute(track: 0, on: true).bytes == [0xB0, 53, 127])
        // CCs 1-18: P1 P2 filter resonance A D S R, the LFO's four, FX1 FX2 pan level, portamento, note style
        let order = ["p1", "p2", "filter", "resonance", "attack", "decay", "sustain", "release", "lfo_depth", "lfo_speed", "lfo_value", "lfo_shape", "fx1", "fx2", "pan", "level", "portamento", "note_style"]
        for (i, name) in order.enumerated() { #expect(OPZCommand.sound(track: 5, param: OPZ.params.firstIndex(of: name)!, value: 7).bytes == [0xB5, UInt8(i + 1), 7], "\(name)") }
        #expect(OPZCommand.pattern(project: 3, 9).bytes == [0xB3, 103, 9])
        #expect(OPZCommand.bend(track: 1, 0).bytes == [0xE1, 0, 64] && OPZCommand.bend(track: 1, 1).bytes == [0xE1, 127, 127] && OPZCommand.bend(track: 1, -2).bytes == [0xE1, 1, 0])
        for c: OPZCommand in [.gain(track: 16, value: 1), .noteOn(track: 0, note: 200, velocity: 9), .sound(track: 0, param: 18, value: 0), .pattern(project: 10, 0), .mute(track: -1, on: true)] { #expect(c.bytes.isEmpty) }
        #expect(OPZCommand.noteOn(track: 3, note: 60, velocity: 0).bytes == [0x93, 60, 1])            // never a note off by mistake
    }

    #if canImport(CoreMIDI)      // the Mac's MIDI packing
    @Test func shortMessagesAreWhole() {
        #expect(MIDITransport.umpWord([0xB2, 50, 100]) == 0x20B2_3264 && MIDITransport.umpWord([0xFA]) == 0x10FA_0000 && MIDITransport.umpWord([0xC1, 5]) == 0x20C1_0500)
        for b: [UInt8] in [[], [0x40, 1, 2], [0xF0, 1], [0x90, 200, 1], [0x90, 1, 2, 3]] { #expect(MIDITransport.umpWord(b) == nil) }
    }
    #endif

    /// Whatever is pressed, changed and let go, every note that began ends, once.
    @Test func everyNoteEnds() {
        var r = SystemLike(7)
        for round in 0..<300 {
            var p = Player(), sounding: [String: Int] = [:], now = 0.0, log: [Player.Event] = []
            func take(_ e: [Player.Event]) { log += e }
            for _ in 0..<60 {
                now += 0.03
                switch r.next(10) {
                case 0: take(p.select(track: r.next(16), at: now))
                case 1: p.settings.tool = Player.Tool.allCases[r.next(7)]
                case 2: p.settings.hold = Player.Hold.allCases[r.next(3)]; if p.settings.hold == .off { take(p.unhold(at: now)) }
                case 3: p.settings.strum = [0, 0.05, 0.2][r.next(3)]; p.settings.groove = r.next(4) == 0 ? "TRESILLO" : nil
                case 4: p.settings.scale = Scale(rawValue: r.next(20))!; p.settings.tonic = r.next(12)
                case 5...7: take(p.press(r.next(12), note: 40 + r.next(50), at: now))
                default: take(p.release(r.next(12), at: now))
                }
            }
            take(p.silence(at: now + 1))
            for e in log.enumerated().sorted(by: { ($0.element.at, $0.offset) < ($1.element.at, $1.offset) }).map(\.element) {
                if case .noteOn(let t, let n, _) = e.command { sounding["\(t) \(n)", default: 0] += 1 }
                if case .noteOff(let t, let n) = e.command { sounding["\(t) \(n)"] = 0 }
            }
            #expect(sounding.values.allSatisfy { $0 == 0 } && p.isEmpty, "round \(round): \(sounding.filter { $0.value > 0 })")
        }
    }

    @Test func chordsAndScales() {
        var p = Player()
        _ = p.select(track: 7, at: 0)
        func notes(_ e: [Player.Event]) -> [Int] { e.compactMap { if case .noteOn(_, let n, _) = $0.command { n } else { nil } } }
        p.settings.tool = .triad
        #expect(notes(p.press(0, note: 60, at: 0)) == [60, 64, 67])
        _ = p.silence(at: 1)
        p.settings.scale = .major                                              // D in C major is minor
        #expect(notes(p.press(0, note: 62, at: 1)) == [62, 65, 69])
        _ = p.silence(at: 2)
        p.settings.tool = .numbers
        p.settings.lead = false
        #expect(notes(p.press(0, note: 69, at: 2)).map { $0 % 12 } == [9, 0, 4])      // 6m: A C E
        _ = p.silence(at: 3)
        p.settings.tool = .progression
        p.settings.progression = "AXIS"                                        // 1 5 6m 4
        #expect(p.upNext == "C")
        var roots: [Int] = []
        for k in 0..<5 { roots.append(notes(p.press(0, note: 60, at: 3 + Double(k)))[0] % 12); _ = p.release(0, at: 3.5 + Double(k)) }
        #expect(roots == [0, 7, 9, 5, 0])
        // close voices: each chord moves less than when it is built from its root
        func moved(_ lead: Bool) -> Int {
            var q = Player(), total = 0, was: [Int] = []
            _ = q.select(track: 7, at: 0)
            q.settings.tool = .progression; q.settings.progression = "CANON"; q.settings.lead = lead
            for k in 0..<8 { let n = notes(q.press(0, note: 60, at: Double(k))); _ = q.release(0, at: Double(k) + 0.5); if !was.isEmpty { total += zip(n, was).reduce(0) { $0 + abs($1.0 - $1.1) } }; was = n }
            return total
        }
        #expect(moved(true) < moved(false))
        #expect(Progressions.all.count == 133 && Set(Progressions.all.map(\.name)).count == 133)
        #expect(Scale.minor.snap(61, tonic: 0) == 60 && Scale.major.note(7, base: 60) == 72 && Scale.major.note(-1, base: 60) == 59)
        // a drum's key is its key
        _ = p.silence(at: 20); _ = p.select(track: 0, at: 20)
        #expect(notes(p.press(0, note: 61, at: 20)) == [61])
    }

    @Test func holdDroneAndStrum() {
        var p = Player()
        _ = p.select(track: 5, at: 0)
        p.settings.hold = .hold
        #expect(p.press(1, note: 60, at: 0).count == 1 && p.release(1, at: 0.1).isEmpty)
        let next = p.press(2, note: 64, at: 1)
        #expect(next == [.init(1, .noteOff(track: 5, note: 60)), .init(1, .noteOn(track: 5, note: 64, velocity: 100))])
        _ = p.silence(at: 2)
        p.settings.hold = .drone
        for k in 0..<3 { _ = p.press(k, note: 60 + k, at: 3); _ = p.release(k, at: 3.1) }
        #expect(p.kept == [60, 61, 62])
        #expect(p.press(1, note: 61, at: 4) == [.init(4, .noteOff(track: 5, note: 61))] && p.kept == [60, 62])
        for k in 10..<22 { _ = p.press(k, note: 70 + k, at: 5); _ = p.release(k, at: 5) }
        #expect(p.kept.count == 8)
        // another track can be played over a drone
        #expect(p.select(track: 4, at: 6).isEmpty && p.kept.count == 8)
        _ = p.silence(at: 7)
        p.settings.hold = .off; p.settings.tool = .triad; p.settings.strum = 0.1
        #expect(p.press(0, note: 60, at: 8).map(\.at) == [8, 8.05, 8.1])
    }

    @Test func grooves() {
        var p = Player()
        _ = p.select(track: 7, at: 0)
        p.settings.tool = .triad; p.settings.hold = .hold; p.settings.groove = "TRESILLO"
        #expect(p.press(0, note: 60, at: 0).isEmpty)                           // the groove plays it
        _ = p.release(0, at: 0)
        var hits: [Int] = []
        for k in 0..<16 { let e = p.groove(step: k, at: Double(k), sixteenth: 1); if !e.isEmpty { hits.append(k); #expect(e.filter { if case .noteOn = $0.command { true } else { false } }.count == 3 && e.count == 6) } }
        #expect(hits == [0, 3, 6, 8, 11, 14])
        p.settings.order = .up
        let first = (0..<16).flatMap { p.groove(step: $0, at: Double($0), sixteenth: 1) }.compactMap { e -> Int? in if case .noteOn(_, let n, _) = e.command { n } else { nil } }
        #expect(first.count == 6 && Set(first) == [60, 64, 67])
        _ = p.silence(at: 99)
        #expect(p.groove(step: 0, at: 100, sixteenth: 1).isEmpty)
        #expect(Groove.library.allSatisfy { $0.steps.count == 16 && Groove.families.indices.contains($0.family) })
    }

    struct Unit: MoveSource {
        func sound(_ track: Int, _ param: Int) -> Int { 40 + param * 3 }
        func gain(_ track: Int) -> Int { 100 }
        func muted(_ track: Int) -> Bool { track == 2 }
        func lastNote(_ track: Int) -> Int { 60 + track }
    }

    /// Every move of the gallery, alone and with others: when they have ended, the OP-Z is as it was, and every note is off.
    @Test func movesPutEverythingBack() {
        var r = SystemLike(3)
        let u = Unit()
        func check(_ moves: [Move]) {
            var p = Performer(), state: [String: Int] = [:], notes: [String: Int] = [:], n = 0
            func take(_ c: [OPZCommand]) {
                n += c.count
                for x in c {
                    switch x {
                    case .sound(let t, let k, let v): state["s\(t) \(k)"] = v == u.sound(t, k) ? nil : v
                    case .gain(let t, let v): state["g\(t)"] = v == 100 ? nil : v
                    case .bend(let t, let v): state["b\(t)"] = abs(v) < 1e-6 ? nil : 1
                    case .mute(let t, let m): state["m\(t)"] = m == u.muted(t) ? nil : 1
                    case .noteOn(let t, let k, _): notes["\(t) \(k)", default: 0] += 1
                    case .noteOff(let t, let k): notes["\(t) \(k)"] = 0
                    default: Issue.record("\(x)")
                    }
                    #expect(!x.bytes.isEmpty)
                }
            }
            var beat = 3.3, down: [Int] = []
            for (i, m) in moves.enumerated() { take(p.begin(i, m, selected: r.next(8), beat: beat, from: u)); down.append(i); for _ in 0..<40 { beat += 0.035; take(p.step(beat: beat, from: u)) } }
            #expect(n > 0 || moves.allSatisfy { $0.kind == .mute })
            while !down.isEmpty { take(p.end(down.remove(at: r.next(down.count)))); beat += 0.2; take(p.step(beat: beat, from: u)) }
            #expect(p.isEmpty && state.isEmpty && notes.values.allSatisfy { $0 == 0 }, "\(moves.map(\.name)) \(state)")
        }
        for m in Move.gallery { check([m]) }
        for _ in 0..<200 { check((0..<(2 + r.next(5))).map { _ in Move.gallery[r.next(Move.gallery.count)] }) }
        #expect(Set(Move.gallery.map(\.id)).count == Move.gallery.count && Move.gallery.allSatisfy { Move.families.contains($0.family) } && Move.gallery.count >= 30)
        #expect(PerformBay().slots.allSatisfy { $0 != nil })
        let kept = try? JSONDecoder().decode(PerformBay.self, from: JSONEncoder().encode(PerformBay()))
        #expect(kept == PerformBay())
    }

    /// Not more than MIDI carries: 1,000 messages a second over USB is far; Bluetooth takes some 300.
    @Test func movesAreLightOnTheWire() {
        for m in Move.gallery {
            var p = Performer(), n = p.begin(0, m, selected: 4, beat: 0, from: Unit()).count
            for k in 1...300 { n += p.step(beat: Double(k) / 30, from: Unit()).count }          // five seconds at 120, 60 a second
            #expect(n < 1700, "\(m.name) \(n)")
        }
    }

    @Test func learning() throws {
        var l = Learned()
        let knob = Control(device: "Minilab3", channel: 0, kind: .cc, number: 74), pad = Control(device: "Minilab3", channel: 9, kind: .note, number: 36)
        let endless = Control(device: "BeatStep", channel: 0, kind: .cc, number: 10)
        l.learn(.gain(track: 2))
        #expect(l.moved(knob, 40, now: { _ in 100 }) == .none && l.moved(knob, 44, now: { _ in 100 }) == .none)
        guard case .learned(let e) = l.moved(knob, 50, now: { _ in 100 }) else { Issue.record("not learned"); return }
        #expect(e.way == .absolute && e.target == .gain(track: 2) && l.waiting == nil)
        // it takes hold where the value is: no jump
        #expect(l.moved(knob, 60, now: { _ in 100 }) == .none && l.moved(knob, 90, now: { _ in 100 }) == .none)
        #expect(l.moved(knob, 104, now: { _ in 100 }) == .set(.gain(track: 2), 104) && l.moved(knob, 108, now: { _ in 104 }) == .set(.gain(track: 2), 108))
        #expect(l.moved(knob, 109, now: { _ in 20 }) == .none)                             // moved elsewhere: it lets go
        l.learn(.sound(track: nil, param: 8))
        _ = l.moved(endless, 1, now: { _ in 64 }); _ = l.moved(endless, 1, now: { _ in 64 })
        if case .learned(let e) = l.moved(endless, 127, now: { _ in 64 }) { #expect(e.way == .relative) } else { Issue.record("not learned") }
        #expect(l.moved(endless, 2, now: { _ in 64 }) == .set(.sound(track: nil, param: 8), 66) && l.moved(endless, 125, now: { _ in 2 }) == .set(.sound(track: nil, param: 8), 0))
        l.learn(.move(pad: 3))
        if case .learned = l.moved(pad, 90, now: { _ in nil }) {} else { Issue.record("not learned") }
        #expect(l.moved(pad, 0, now: { _ in nil }) == .release(.move(pad: 3)) && l.moved(pad, 80, now: { _ in nil }) == .press(.move(pad: 3), velocity: 80))
        #expect(l.moved(Control(device: "x", channel: 0, kind: .cc, number: 74), 1, now: { _ in nil }) == .none)   // another device's
        let back = try JSONDecoder().decode(Learned.self, from: JSONEncoder().encode(l))
        #expect(back.entries == l.entries && back.entries.count == 3)
        l.forget(pad)
        #expect(l.moved(pad, 80, now: { _ in nil }) == .none)
    }
}

/// Chance for tests, the same every run.
struct SystemLike { var s: UInt64
    init(_ n: UInt64) { s = n &* 0x9E37_79B9_7F4A_7C15 | 1 }
    mutating func next(_ n: Int) -> Int { s ^= s << 13; s ^= s >> 7; s ^= s << 17; return Int(s >> 33) % n }
}
