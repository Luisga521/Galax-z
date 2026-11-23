import DotKit
@testable import OPZModel
@testable import OPZStage
import Testing

/// How far what is drawn is from what sounds: an OP-Z that plays by a clock of its own, whose messages take as long as they do.
@Suite struct TightnessTests {
    struct Result { var lateness: [Double] = [], doubles = 0, missed = 0, steps: [Double] = []
        func at(_ q: Double) -> Double { let s = lateness.sorted(); return s.isEmpty ? 9 : s[min(s.count - 1, Int(q * Double(s.count)))] }
        var worstStep: Double { steps.map(abs).max() ?? 9 }
    }

    /// Notes on the kick (every beat) and the snare (once a bar: two seconds apart), `midi`: they come over MIDI too.
    static func run(midi: Bool, position: ClosedRange<Double> = 0.004...0.03, note: ClosedRange<Double> = 0.002...0.012, tempo: Int = 120, told: Int? = nil, bars: Int = 12) -> Result {
        var bytes = [UInt8](StageTests.project.0.bytes)
        let p = StageTests.project.1.pattern, at = p * OPZ.patternSize
        for s in 0..<16 { for slot in 0..<OPZ.slotsPerStep { bytes[at + OPZ.notesAt + (s * OPZ.slotsPerStep + slot) * 8 + 4] = 0xFF } }
        func put(_ t: Int, _ s: Int) {
            let n = at + OPZ.notesAt + (s * OPZ.slotsPerStep + OPZ.noteOffsets[t]) * 8
            bytes.replaceSubrange(n..<n + 8, with: [0x10, 0x27, 0, 0, 60, 100, 0, 0])
        }
        for s in [0, 4, 8, 12] { put(0, s) }
        put(1, 6)
        for t in 0..<16 { bytes[at + t * OPZ.trackRecord + 4] = 16; bytes[at + t * OPZ.trackRecord + 6] = 1 }
        for g in 0..<40 { bytes[at + 21_344 + g] = 0 }
        var r = DotRandom(5), out = Result()
        let s = Stage(), c = DotCanvas(width: 200, height: 160), t0 = 100.0, sixteenth = 15.0 / Double(tempo)
        var i = StageInput()
        i.link = .live; i.bank = Bank(bytes); i.address = StageTests.project.1; i.revision = 1; i.tempo = told ?? tempo
        var clock = t0 - 1
        s.clock = { clock }
        s.frame(c, time: clock, dt: 1 / 120)
        s.input = i
        // what comes, and when
        enum Event { case start, position, note(Int) }
        var events: [(at: Double, Event)] = [(t0 + r.range(note.lowerBound, note.upperBound), .start)], truth: [(at: Double, track: Int)] = []
        for k in 0..<bars * 16 {
            let time = t0 + Double(k) * sixteenth
            if k % 16 == 0 { events.append((time + r.range(position.lowerBound, position.upperBound), .position)) }
            for (t, hit) in [(0, k % 4 == 0), (1, k % 16 == 6)] where hit {
                truth.append((time, t))
                if midi { events.append((time + r.range(note.lowerBound, note.upperBound), .note(t))) }
            }
        }
        events.sort { $0.at < $1.at }
        var frame = t0 - 0.5, last = [0.0, 0.0], seen: [(at: Double, track: Int)] = [], step = -1
        while frame < t0 + Double(bars * 16) * sixteenth - 0.05 {
            frame += 1.0 / 120
            while let e = events.first, e.at <= frame {
                events.removeFirst()
                clock = e.at
                switch e.1 {
                case .start: s.midi(playing: true, at: e.at)
                case .position: i.panel.playing = true; i.panel.told += 1; i.panel.positions = [UInt8](repeating: 0, count: 16); i.panel.step = 0; s.input = i
                case .note(let t): s.noteOn(channel: t, note: 60, velocity: 100, at: e.at)
                }
            }
            clock = frame
            s.frame(c, time: frame, dt: 1.0 / 120)
            for t in 0..<2 { if s.hits[t] > last[t] + 0.02 { seen.append((frame, t)) }; last[t] = s.hits[t] }
            if s.playhead.playing, s.playhead.step != step {
                step = s.playhead.step
                let k = ((frame - t0) / sixteenth).rounded(), true0 = t0 + k * sixteenth
                if frame > t0 + 0.5 { out.steps.append(frame - true0) }
            }
        }
        for x in truth where x.at < frame - 0.1 {
            let near = seen.filter { $0.track == x.track && $0.at > x.at - 0.05 && $0.at < x.at + 0.2 }
            if let f = near.first { out.lateness.append(f.at - x.at); out.doubles += near.count - 1 } else { out.missed += 1 }
        }
        return out
    }

    @Test func whatIsDrawnIsWithWhatSounds() {
        // (the middle, all but one in twenty, the worst step, in ms; a frame is 8. Before the count was held to what sounds: 8 16 33, 25 33 33, 33 50 58, 12 16 48)
        for (name, r, middle, most, step) in [("midi", Self.run(midi: true), 10, 18, 18), ("no midi", Self.run(midi: false), 10, 18, 18),
                                              ("bluetooth", Self.run(midi: true, position: 0.015...0.06, note: 0.01...0.045), 20, 34, 34),
                                              ("tempo a little off", Self.run(midi: true, tempo: 121, told: 120), 14, 20, 26)] {
            #expect(r.at(0.5) * 1000 < Double(middle) && r.at(0.95) * 1000 < Double(most) && r.worstStep * 1000 < Double(step), "\(name): \(r.at(0.5)) \(r.at(0.95)) \(r.worstStep)")
            #expect(r.doubles == 0 && r.missed == 0, "\(name): twice \(r.doubles), not \(r.missed)")
        }
    }
}
