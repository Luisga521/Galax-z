@testable import ChopKit
import Foundation
import Testing

@Suite struct ChopTests {
    /// Clicks of sound with silence between.
    static func hits(_ at: [Double], rate: Double = 44_100, seconds: Double = 2) -> [Float] {
        var x = [Float](repeating: 0, count: Int(seconds * rate))
        for (k, t) in at.enumerated() { for i in 0..<Int(0.12 * rate) where Int(t * rate) + i < x.count { x[Int(t * rate) + i] = sin(Float(i) * (0.05 + 0.03 * Float(k))) * exp(-Float(i) / 1500) * 0.8 } }
        return x
    }
    final class Out {
        let e: ChopEngine
        var L = [Float](), R = [Float](), worst = 0.0
        init(_ kit: Kit? = SungVoice.kit, rate: Double = 48_000) { e = ChopEngine(rate: rate); if let kit { e.load(kit) } }
        func run(_ seconds: Double, block: Int = 256) {
            var l = [Float](repeating: 9, count: block), r = l
            for _ in 0..<Int(seconds * e.rate / Double(block)) {
                let t = DispatchTime.now().uptimeNanoseconds
                l.withUnsafeMutableBufferPointer { a in r.withUnsafeMutableBufferPointer { b in e.render(a.baseAddress!, b.baseAddress!, block) } }
                worst = max(worst, Double(DispatchTime.now().uptimeNanoseconds - t) / 1e9)
                L += l; R += r
            }
        }
        func power(_ from: Double = 0, _ to: Double = 99) -> Float {
            let a = min(L.count, Int(from * e.rate)), b = min(L.count, Int(to * e.rate))
            return b > a ? (L[a..<b].reduce(0) { $0 + $1 * $1 } / Float(b - a)).squareRoot() : 0
        }
        var whole: Bool { (L + R).allSatisfy { $0.isFinite && abs($0) <= 1.001 } }
        /// The biggest jump from a sample to the next.
        var jump: Float { zip(L, L.dropFirst()).reduce(0) { max($0, abs($1.1 - $1.0)) } }
    }

    @Test func aSourceIsCutWhereItsHitsAre() {
        let at = [0.1, 0.5, 0.9, 1.4], k = Chopper.cut(Self.hits(at), rate: 44_100, mode: .hits)
        #expect(k.chops.count == 4)
        #expect(zip(k.chops, k.chops.dropFirst()).allSatisfy { $0.end <= $1.start } && k.chops.last!.end <= k.audio.count)
        #expect(k.audio.map(abs).max()! > 0.88 && k.audio.map(abs).max()! < 0.9)
        for (m, n) in [(Chopper.Mode.eight, 8), (.sixteen, 16), (.twentyFour, 24), (.whole, 1)] { #expect(Chopper.cut(Self.hits(at), rate: 44_100, mode: m).chops.count == n, "\(m)") }
        // nothing, silence, very short, too long
        #expect(Chopper.cut([], rate: 44_100, mode: .hits).chops.isEmpty && Chopper.cut([Float](repeating: 0, count: 9000), rate: 44_100, mode: .sixteen).chops.count == 16)
        #expect(Chopper.cut([Float](repeating: 0, count: 9000), rate: 44_100, mode: .hits).chops.isEmpty)
        for n in [1, 7, 31, 100] { _ = Chopper.cut([Float](repeating: 0.5, count: n), rate: 44_100, mode: .twentyFour) }
        #expect(Chopper.cut([Float](repeating: 0.2, count: 200 * 8000), rate: 8000, mode: .whole).audio.count <= Int(10 * 8000) + 32)
        #expect(k.shape(40).count == 40 && k.shape(0).isEmpty)
    }

    @Test func theVoiceSings() {
        let k = SungVoice.kit
        #expect(k.chops.count == 24 && k.audio.allSatisfy { $0.isFinite && abs($0) < 1 })
        for c in k.chops.prefix(16) { let a = k.audio[c.start..<c.end]; #expect((a.reduce(0) { $0 + $1 * $1 } / Float(a.count)).squareRoot() > 0.05, "\(c.name)") }
    }

    @Test func aChopSoundsAndEnds() {
        let o = Out()
        o.run(0.1)
        #expect(o.power() == 0)
        o.e.start(0, velocity: 1, id: 1)
        o.run(0.3)
        #expect(o.power(0.1, 0.4) > 0.03 && o.e.sounding & 1 == 1 && o.e.takeLevel() > 0.05)
        o.run(1)
        #expect(o.power(1, 1.4) == 0 && o.e.sounding == 0 && o.whole)
        // softer
        let soft = Out(); soft.e.start(0, velocity: 0.1, id: 1); soft.run(0.3)
        let loud = Out(); loud.e.start(0, velocity: 1, id: 1); loud.run(0.3)
        #expect(soft.power() < loud.power() * 0.6)
        // a loop goes on until it is let go
        let l = Out(); l.e.set(.tail, 1); l.e.start(0, velocity: 1, id: 7); l.run(2)
        #expect(l.power(1.5, 2) > 0.02)
        l.e.stop(id: 6); l.run(0.2); #expect(l.e.sounding != 0)
        l.e.stop(id: 7); l.run(0.2); l.run(0.1)
        #expect(l.e.sounding == 0)
    }

    @Test func pitchAndDirection() {
        func crossings(_ semis: Double, _ dial: Double = 0.5) -> Int {
            let o = Out(); o.e.set(.pitch, dial); o.e.set(.spread, 0); o.e.start(0, velocity: 1, id: 1, semitones: semis); o.run(0.15)
            let x = Array(o.L[2400...])
            return zip(x, x.dropFirst()).filter { $0 < 0 && $1 >= 0 }.count
        }
        let base = crossings(0)
        #expect(crossings(12) > base * 3 / 2 && crossings(-12) < base * 2 / 3 && crossings(0, 0.75) > base * 3 / 2)
        // backwards is the same sound the other way about
        var k = Kit(name: "", rate: 48_000, audio: (0..<9600).map { Float($0) / 9600 * 0.5 }, chops: [.init(name: "", start: 0, end: 9600)])
        func start(_ k: Kit) -> Float { let o = Out(k); o.e.set(.spread, 0); o.e.start(0, velocity: 1, id: 1); o.run(0.05); return o.power(0.01, 0.03) }
        let forwards = start(k)
        k.chops[0].reverse = true
        #expect(start(k) > forwards * 3)
        k.chops[0].on = false
        #expect(start(k) == 0)
    }

    @Test func theDialsDoWhatTheySay() {
        func run(_ set: [ChopDial: Double], _ seconds: Double = 1.2) -> Out { let o = Out(); for (d, x) in set { o.e.set(d, x) }; o.e.start(0, velocity: 1, id: 1); o.run(seconds); return o }
        #expect(run([.tail: 0.05]).power(0.2, 1) < run([.tail: 0.74]).power(0.2, 1))
        #expect(run([.bloom: 0.6]).power(0.6, 1.2) > 0.01 && run([:]).power(0.6, 1.2) == 0)            // struck again while held
        #expect(run([.level: 0]).power(0.2, 1) < 0.002)
        #expect(run([.tone: 0.05]).jump < run([.tone: 0.5]).jump && run([.tone: 0.98]).power() > 0.002 && run([.tone: 0.98]).power() < run([.tone: 0.5]).power())
        #expect(run([.attack: 0.9]).power(0, 0.05) < run([:]).power(0, 0.05) * 0.5)
        for d in ChopDial.allCases { for x in [0.0, 0.3, 0.76, 1, -5, 9, .nan] { #expect(run([d: x], 0.2).whole, "\(d) \(x)") } }
    }

    /// Each effect, at every extreme, alone and together: finite, not too loud, heard when on, gone when off, and no thump when it comes and goes.
    @Test func effects() {
        for k in Effect.Kind.allCases {
            #expect(k.dials.count == 3 && k.start.count == 3)
            func run(_ e: Effect?, _ s: Double = 0.6) -> Out { let o = Out(); o.e.set(.tail, 1); o.e.set(.spread, 0); if let e { o.e.set(e) }; o.e.start(2, velocity: 1, id: 1); o.run(s); return o }
            let dry = run(nil), wet = run(Effect(k, on: true))
            let d = zip(dry.L, wet.L).reduce(Float(0)) { $0 + abs($1.0 - $1.1) } / Float(dry.L.count)
            #expect(d > 0.002, "\(k.name) does nothing: \(d)")
            for a in [0.0, 1] { for b in [0.0, 1] { for m in [0.0, 1] { var e = Effect(k, on: true); e.dials = [a, b, m]; #expect(run(e, 1).whole, "\(k.name) \(a) \(b) \(m)") } } }
            let o = Out(); o.e.set(.tail, 1); o.e.start(2, velocity: 1, id: 1); o.run(0.2)
            let clean = o.jump
            var e = Effect(k, on: true)
            if k == .crush || k == .ring || k == .stutter || k == .drive || k == .freeze { e.dials[2] = 0.3 }                 // (rough by themselves)
            o.e.set(e); o.run(0.3); e.on = false; o.e.set(e); o.run(0.3)
            #expect(o.jump < max(0.6, clean * 4), "\(k.name) thumps: \(o.jump) over \(clean)")
            // off and nothing playing: silence, in the end
            o.e.silence(); o.run(0.4); let n = o.L.count; o.run(0.2)
            #expect(o.L[n...].allSatisfy { abs($0) < 1e-4 }, "\(k.name) goes on")
        }
        let all = Out()
        for k in Effect.Kind.allCases { var e = Effect(k, on: true); e.dials = [0.9, 0.95, 1]; all.e.set(e) }
        for i in 0..<40 { all.e.start(i, velocity: 1, id: i); all.run(0.1) }
        #expect(all.whole)
    }

    /// A storm of keys, dials, kits and nonsense: it goes on, and silence ends it all.
    @Test func aStorm() {
        var r = SystemLike(5)
        let o = Out(nil)
        o.e.start(0, velocity: 1, id: 1); o.run(0.05)                           // no kit
        #expect(o.power() == 0)
        let small = Kit(name: "", rate: 8000, audio: [0.1, 0.2, 0.3], chops: [.init(name: "", start: -5, end: 900), .init(name: "", start: 2, end: 1), .init(name: "", start: 50, end: 60)])
        let kits = [SungVoice.kit, Chopper.cut(Self.hits([0.1, 0.4]), rate: 44_100, mode: .hits), small, Kit(name: "", rate: 44_100, audio: [], chops: [])]
        for _ in 0..<600 {
            switch r.next(9) {
            case 0: o.e.load(kits[r.next(4)])
            case 1...3: o.e.start(r.next(200) - 60, velocity: Double(r.next(300)) / 100 - 1, id: r.next(20), semitones: Double(r.next(120) - 60))
            case 4: o.e.stop(id: r.next(20))
            case 5: o.e.set(ChopDial.allCases[r.next(8)], Double(r.next(100)) / 99)
            case 6: var e = Effect(Effect.Kind.allCases[r.next(12)], on: r.next(2) == 0); e.dials = [0, 1, 2].map { _ in Double(r.next(100)) / 99 }; o.e.set(e)
            case 7: o.e.set(tempo: Double(r.next(400)))
            default: break
            }
            o.run(0.02, block: [64, 128, 256, 480][r.next(4)])
        }
        #expect(o.whole)
        for k in Effect.Kind.allCases { o.e.set(Effect(k)) }
        o.e.silence(); o.run(0.5)
        #expect(o.e.sounding == 0)
    }

    /// A block's sound is made in far less than a block's time.
    @Test func itIsQuick() {
        let o = Out()
        for k in Effect.Kind.allCases { o.e.set(Effect(k, on: true)) }
        o.e.set(.tail, 1)
        for i in 0..<16 { o.e.start(i, velocity: 1, id: i) }
        o.run(0.2)
        let t = DispatchTime.now().uptimeNanoseconds
        o.run(2)
        let share = Double(DispatchTime.now().uptimeNanoseconds - t) / 2e9
        print("CHOPS \(share * 100) % of real time (debug), worst block \(o.worst * 1000) ms")
        #expect(share < 5)                                                      // (unoptimised, and beside the other tests: a tenth of this by itself)
    }
}
