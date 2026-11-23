import Foundation
import Synchronization

/// The chops' dials, 0-1: what MODULE's first two pages turn.
public enum ChopDial: Int, CaseIterable, Codable, Sendable {
    case pitch, mutate, bloom, tail, tone, attack, spread, level
    public var name: String { ["PITCH", "MUTATE", "BLOOM", "TAIL", "TONE", "ATTACK", "SPREAD", "LEVEL"][rawValue] }
    public var start: Double { [0.5, 0, 0, 0.75, 0.5, 0, 0.3, 0.8][rawValue] }
    public static let blooms = ["OFF", "1/4", "1/8", "1/8T", "1/16", "1/16T", "1/32", "SCATTER"]
}

/// Plays chops. `render` runs on the audio thread and neither waits nor allocates; everything else may be called from one other thread.
public final class ChopEngine: @unchecked Sendable {
    public static let voices = 16
    private struct Voice {
        var on = false, gate = false
        var id: Int32 = 0, chop = 0, base = 0
        var pos = 0.0, step = 0.0, start = 0.0, end = 0.0
        var gain: Float = 0, fade: Float = 0, left: Float = 0, right: Float = 0, lp: Float = 0
        var played = 0.0, strike: Float = 0, age: UInt32 = 0, dying = false, pick = false
    }
    private struct Command { var kind: UInt8 = 0; var a: Int32 = 0, b: Int32 = 0; var x: Float = 0 }
    /// A kit as the audio thread reads it.
    private final class Loaded {
        let audio: UnsafeMutablePointer<Float>, count: Int, rate: Double
        let n: Int
        struct Plain { var start: Int32, end: Int32; var pitch: Float, level: Float, pan: Float; var reverse: Bool, on: Bool, choke: Bool }
        let plain: UnsafeMutablePointer<Plain>
        init(_ k: Kit) {
            count = k.audio.count; rate = k.rate; n = min(k.chops.count, Chopper.most)
            audio = .allocate(capacity: count + 2); audio.initialize(repeating: 0, count: count + 2)
            plain = .allocate(capacity: max(1, n))
            for (i, c) in k.chops.prefix(n).enumerated() {
                let a = max(0, min(count, c.start)), b = max(a, min(count, c.end))
                (plain + i).initialize(to: Plain(start: Int32(a), end: Int32(b), pitch: Float(c.pitch), level: Float(c.level), pan: Float(c.pan), reverse: c.reverse, on: c.on && b - a > 8, choke: c.choke))
            }
            k.audio.withUnsafeBufferPointer { if let from = $0.baseAddress { audio.update(from: from, count: count) } }
        }
        deinit { audio.deallocate(); plain.deallocate() }
    }

    public let rate: Double
    private var v = [Voice](repeating: Voice(), count: ChopEngine.voices)
    private let ring: UnsafeMutablePointer<Command>, ringSize = 512
    private let head = Atomic<Int>(0), tail = Atomic<Int>(0)
    private let pending = Atomic<UInt>(0)                       // the kit to take, retained
    private let current = Atomic<UInt>(0)
    private var alive: [Loaded] = []                            // kept until surely not read
    private let dials: UnsafeMutablePointer<Float>, effects: UnsafeMutablePointer<Float>, effectOn: UnsafeMutablePointer<Bool>
    private var tempo: Float = 120
    private var rnd: UInt32 = 0x1234_5678, clock: UInt32 = 0, nextID: Int32 = 1
    private let chain: Chain
    private let meter = Atomic<UInt32>(0), playing = Atomic<UInt32>(0)
    private var smooth: Float = 0.8

    public init(rate: Double) {
        self.rate = rate
        ring = .allocate(capacity: ringSize); ring.initialize(repeating: Command(), count: ringSize)
        dials = .allocate(capacity: 8); for d in ChopDial.allCases { (dials + d.rawValue).initialize(to: Float(d.start)) }
        let n = Effect.Kind.allCases.count
        effects = .allocate(capacity: n * 3); effectOn = .allocate(capacity: n); effectOn.initialize(repeating: false, count: n)
        for k in Effect.Kind.allCases { for i in 0..<3 { (effects + k.rawValue * 3 + i).initialize(to: Float(k.start[i])) } }
        chain = Chain(rate: rate)
    }
    deinit { ring.deallocate(); dials.deallocate(); effects.deallocate(); effectOn.deallocate() }

    // MARK: from the other thread

    private func put(_ c: Command) {
        let h = head.load(ordering: .relaxed)
        guard h - tail.load(ordering: .acquiring) < ringSize else { return }
        ring[h % ringSize] = c
        head.store(h + 1, ordering: .releasing)
    }
    public func load(_ k: Kit) {
        let l = Loaded(k)
        alive.append(l)
        pending.store(UInt(bitPattern: Unmanaged.passUnretained(l).toOpaque()), ordering: .releasing)
        // a kit is let go only when a later one has been taken, and the one after it
        let now = current.load(ordering: .acquiring)
        if alive.count > 3 { alive = alive.enumerated().filter { $0.offset >= alive.count - 2 || UInt(bitPattern: Unmanaged.passUnretained($0.element).toOpaque()) == now }.map(\.element) }
    }
    /// A chop begins: `id` ends it. `semitones` beside its own pitch.
    public func start(_ chop: Int, velocity: Double, id: Int, semitones: Double = 0) { put(Command(kind: 1, a: Int32(truncatingIfNeeded: chop), b: Int32(truncatingIfNeeded: id), x: Float(max(0, min(1, velocity))) + Float((semitones + 64).rounded()) * 2)) }
    public func stop(id: Int) { put(Command(kind: 2, b: Int32(truncatingIfNeeded: id))) }
    public func silence() { put(Command(kind: 3)) }
    public func set(_ d: ChopDial, _ x: Double) { put(Command(kind: 4, a: Int32(d.rawValue), x: Float(max(0, min(1, x))))) }
    public func set(_ e: Effect) {
        put(Command(kind: 6, a: Int32(e.kind.rawValue), b: e.on ? 1 : 0))
        for (i, x) in e.dials.prefix(3).enumerated() { put(Command(kind: 5, a: Int32(e.kind.rawValue * 3 + i), x: Float(max(0, min(1, x))))) }
    }
    public func set(tempo: Double) { put(Command(kind: 7, x: Float(max(30, min(300, tempo))))) }
    /// The loudest since it was last asked; how many chops sound, a bit each (the first 24).
    public func takeLevel() -> Float { Float(bitPattern: meter.exchange(0, ordering: .relaxed)) }
    public var sounding: UInt32 { playing.load(ordering: .relaxed) }

    // MARK: on the audio thread

    private func uni() -> Float { rnd = rnd &* 1_664_525 &+ 1_013_904_223; return Float(rnd >> 8) / 16_777_216 }

    private func take(_ kit: UnsafeMutablePointer<Loaded.Plain>?, _ n: Int, _ kitRate: Double, _ c: Command) {
        switch c.kind {
        case 1:
            guard let kit, n > 0 else { return }
            let semis = Float(Int(c.x / 2)) - 64, vel = c.x - Float(Int(c.x / 2)) * 2, chop = ((Int(c.a) % n) + n) % n
            guard kit[chop].on else { return }
            if kit[chop].choke { for i in v.indices where v[i].on && v[i].base == chop { v[i].dying = true } }
            // a free voice, else one that is ending, else the oldest
            var best = 0, score = UInt32.max
            for i in v.indices {
                if !v[i].on { best = i; break }
                let s = v[i].dying ? v[i].age / 4 : v[i].gate ? v[i].age : v[i].age / 2
                if s < score { score = s; best = i }
            }
            clock &+= 1
            var x = Voice()
            x.on = true; x.gate = true; x.id = c.b; x.base = chop; x.chop = chop; x.age = clock
            x.gain = 0.35 + 0.65 * vel; x.start = Double(semis); x.pick = true
            v[best] = x
            begin(best, kit, n, kitRate)
        case 2: for i in v.indices where v[i].on && v[i].id == c.b { v[i].gate = false }
        case 3: for i in v.indices { v[i].dying = true; v[i].gate = false }
        case 4: if (0..<8).contains(c.a) { dials[Int(c.a)] = c.x }
        case 5: if (0..<Int32(Effect.Kind.allCases.count * 3)).contains(c.a) { effects[Int(c.a)] = c.x }
        case 6: if (0..<Int32(Effect.Kind.allCases.count)).contains(c.a) { effectOn[Int(c.a)] = c.b != 0 }
        case 7: tempo = c.x
        default: break
        }
    }

    /// A strike: which chop, which way, how fast.
    private func begin(_ i: Int, _ kit: UnsafeMutablePointer<Loaded.Plain>, _ n: Int, _ kitRate: Double) {
        let mutate = dials[1]
        var chop = v[i].base, back = false, octave: Float = 0
        if mutate > 0.02, uni() < min(1, mutate * 2) {
            let reach = 1 + Int(min(1, mutate * 2) * 7.99)
            chop = ((chop + Int((uni() * 2 - 1) * Float(reach + 1))) % n + n) % n
        }
        if mutate > 0.5 { let wild = (mutate - 0.5) * 2; back = uni() < wild * 0.35; if uni() < wild * 0.3 { octave = 12 } }
        if !kit[chop].on { chop = v[i].base }
        let p = kit[chop]
        back = back != p.reverse
        let semis = Float(v[i].start) + p.pitch + octave + ((dials[0] - 0.5) * 48).rounded()
        let speed = kitRate / rate * Double(pow(2, semis / 12))
        v[i].chop = chop
        v[i].end = Double(p.end - p.start)
        v[i].pos = back ? v[i].end - 2 : 0
        v[i].step = back ? -speed : speed
        v[i].played = 0
        v[i].fade = 0
        let pan = max(0, min(1, p.pan + (uni() - 0.5) * dials[6]))
        v[i].left = cos(pan * .pi / 2) * 1.4 * p.level
        v[i].right = sin(pan * .pi / 2) * 1.4 * p.level
        v[i].pick = false
        v[i].strike = interval()
    }

    private func interval() -> Float {
        let b = min(7, Int(dials[2] * 7.99))
        if b == 0 { return 0 }
        if b == 7 { return Float(rate) * 0.05 * (0.4 + uni() * 1.2) }
        let beats: Float = switch b { case 1: 1; case 2: 0.5; case 3: 1 / 3; case 4: 0.25; case 5: 1 / 6; default: 0.125 }
        return Float(rate) * 60 / tempo * beats
    }

    public func render(_ L: UnsafeMutablePointer<Float>, _ R: UnsafeMutablePointer<Float>, _ n: Int) {
        let p = pending.exchange(0, ordering: .acquiringAndReleasing)
        if p != 0 { current.store(p, ordering: .releasing); for i in v.indices { v[i].on = false } }
        let k = UnsafeRawPointer(bitPattern: current.load(ordering: .relaxed)).map { Unmanaged<Loaded>.fromOpaque($0).takeUnretainedValue() }
        let h = head.load(ordering: .acquiring)
        var t = tail.load(ordering: .relaxed)
        while t < h { take(k?.plain, k?.n ?? 0, k?.rate ?? rate, ring[t % ringSize]); t += 1 }
        tail.store(t, ordering: .releasing)
        L.update(repeating: 0, count: n); R.update(repeating: 0, count: n)
        var bits: UInt32 = 0
        if let k, k.n > 0 {
            let tailDial = dials[3], loops = tailDial > 0.75, open = 0.06 + Double(min(1, tailDial / 0.75)) * 0.94
            let rise = 1 / (Float(rate) * (0.002 + dials[5] * dials[5] * 0.6)), fall = 1 / (Float(rate) * 0.006)
            let bright = dials[4], high: Float = bright > 0.5 ? (bright - 0.5) * 2 : 0
            let c: Float = bright < 0.5 ? min(1, 0.015 + bright * bright * 3.94) : 0.004 + high * high * 0.5
            for i in v.indices where v[i].on {
                var x = v[i]
                let plain = k.plain[min(k.n - 1, x.chop)], base = k.audio + Int(plain.start), blooming = dials[2] > 0.125
                for j in 0..<n {
                    if blooming, x.gate, x.strike > 0 {
                        x.strike -= 1
                        if x.strike <= 0 { x.pick = true }
                    }
                    let len = x.end, inside = x.pos >= 0 && x.pos < len - 1
                    var s: Float = 0
                    if inside { let a = Int(x.pos), f = Float(x.pos - Double(a)); s = base[a] + (base[a + 1] - base[a]) * f }
                    let shut = x.dying || x.pick || (!x.gate && loops) || (!loops && x.played > len * open) || !inside
                    if shut { x.fade -= fall; if x.fade <= 0 { x.fade = 0; if x.pick && !x.dying { break } ; x.on = false; break } } else if x.fade < 1 { x.fade = min(1, x.fade + rise) }
                    x.lp += (s - x.lp) * c
                    let y = (bright < 0.5 ? x.lp : bright < 0.505 ? s : s - x.lp * min(1, high * 4)) * x.fade * x.gain
                    L[j] += y * x.left; R[j] += y * x.right
                    x.pos += x.step
                    x.played += abs(x.step)
                    if loops, x.gate {                          // the middle, back and forth
                        if x.step > 0, x.pos >= len * 0.85 { x.step = -x.step } else if x.step < 0, x.pos <= len * 0.45 { x.step = -x.step }
                    }
                }
                v[i] = x
                if x.on, x.pick, x.fade <= 0 { begin(i, k.plain, k.n, k.rate) }
                if v[i].on, v[i].chop < 24 { bits |= 1 << UInt32(v[i].chop) }
            }
        }
        playing.store(bits, ordering: .relaxed)
        chain.run(L, R, n, effects, effectOn, tempo: tempo)
        var peak: Float = 0
        let to = dials[7] * dials[7] * 1.5
        for j in 0..<n {
            smooth += (to - smooth) * 0.002
            func safe(_ x: Float) -> Float { let y = x * smooth; return y.isFinite ? (abs(y) < 0.8 ? y : (y > 0 ? 1 : -1) * (0.8 + 0.2 * tanh((abs(y) - 0.8) / 0.2))) : 0 }
            L[j] = safe(L[j]); R[j] = safe(R[j])
            peak = max(peak, abs(L[j]), abs(R[j]))
        }
        if peak > Float(bitPattern: meter.load(ordering: .relaxed)) { meter.store(peak.bitPattern, ordering: .relaxed) }
    }
}
