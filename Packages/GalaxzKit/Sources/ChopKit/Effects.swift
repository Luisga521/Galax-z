import Foundation

/// An effect of the chops' chain: what it is, whether it is on, its three dials.
public struct Effect: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: Int, CaseIterable, Codable, Sendable {
        case filter, drive, crush, ring, stutter, gate, chorus, flanger, wide, echo, space, freeze
        public var name: String { ["FILTER", "DRIVE", "CRUSH", "RING", "STUTTER", "GATE", "CHORUS", "FLANGER", "WIDE", "ECHO", "SPACE", "FREEZE"][rawValue] }
        public var dials: [String] {
            [["CUT", "RESO", "MIX"], ["DRIVE", "TONE", "MIX"], ["BITS", "RATE", "MIX"], ["PITCH", "SHAPE", "MIX"], ["RATE", "LENGTH", "MIX"], ["RATE", "OPEN", "MIX"],
             ["RATE", "DEPTH", "MIX"], ["RATE", "FEEDBACK", "MIX"], ["WIDTH", "TIME", "MIX"], ["TIME", "FEEDBACK", "MIX"], ["SIZE", "DAMP", "MIX"], ["SIZE", "HOLD", "MIX"]][rawValue]
        }
        public var start: [Double] {
            [[0.5, 0.2, 1], [0.4, 0.6, 1], [0.5, 0.3, 1], [0.4, 0, 0.5], [0.5, 0.5, 1], [0.5, 0.5, 1], [0.3, 0.5, 0.5], [0.2, 0.6, 0.5], [0.6, 0.4, 1], [0.5, 0.45, 0.35], [0.6, 0.4, 0.35], [0.5, 0.8, 0.6]][rawValue]
        }
    }
    public var kind: Kind
    public var on: Bool
    public var dials: [Double]
    public var id: Int { kind.rawValue }
    public init(_ kind: Kind, on: Bool = false) { (self.kind, self.on, dials) = (kind, on, kind.start) }
}

/// The chain as it runs, for the audio thread: nothing is allocated, nothing can blow up (what is not a number is silence).
final class Chain {
    private let rate: Float
    private let size: Int
    private let left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>          // the echo's
    private let shortL: UnsafeMutablePointer<Float>, shortR: UnsafeMutablePointer<Float>       // chorus, flanger, wide
    private let held: UnsafeMutablePointer<Float>                                              // stutter, freeze
    private let combs: UnsafeMutablePointer<Float>
    private static let combAt = [1557, 1617, 1491, 1422, 1277, 1356, 1188, 1116], allAt = [225, 556, 441, 341], shortSize = 4096
    private let heldSize: Int, combSize = 1 << 11
    private var at = 0, shortAt = 0, stutterAt = 0, stutterLen = 0, stutterLeft = 0, freezeAt = 0, freezeFull = 0, combPlace = 0
    private var lp: (Float, Float) = (0, 0), bp: (Float, Float) = (0, 0), tone: (Float, Float) = (0, 0)
    private var crushed: (Float, Float) = (0, 0), crushLeft: Float = 0
    private var ringPhase: Float = 0, lfo: Float = 0, gatePhase: Float = 0, gateNow: Float = 1
    private var damp: (Float, Float) = (0, 0)
    private var mix = [Float](repeating: 0, count: Effect.Kind.allCases.count)       // each fades in and out, so nothing clicks

    init(rate: Double) {
        self.rate = Float(rate)
        size = Int(rate * 2)
        heldSize = Int(rate)
        func make(_ n: Int) -> UnsafeMutablePointer<Float> { let p = UnsafeMutablePointer<Float>.allocate(capacity: n); p.initialize(repeating: 0, count: n); return p }
        left = make(size); right = make(size); shortL = make(Self.shortSize); shortR = make(Self.shortSize); held = make(heldSize * 2); combs = make(combSize * 24)
    }
    deinit { for p in [left, right, shortL, shortR, held, combs] { p.deallocate() } }

    func clear() {
        left.update(repeating: 0, count: size); right.update(repeating: 0, count: size)
        shortL.update(repeating: 0, count: Self.shortSize); shortR.update(repeating: 0, count: Self.shortSize)
        held.update(repeating: 0, count: heldSize * 2); combs.update(repeating: 0, count: combSize * 24)
        lp = (0, 0); bp = (0, 0); tone = (0, 0); crushed = (0, 0); damp = (0, 0)
    }

    private static let divisions: [Float] = [1, 0.75, 0.5, 1.0 / 3, 0.25, 1.0 / 6, 0.125, 0.0625]
    private func division(_ v: Float) -> Float { Self.divisions[min(7, max(0, Int(v * 7.99)))] }

    func run(_ L: UnsafeMutablePointer<Float>, _ R: UnsafeMutablePointer<Float>, _ n: Int, _ d: UnsafePointer<Float>, _ on: UnsafePointer<Bool>, tempo: Float) {
        let beat = rate * 60 / max(40, tempo)
        for k in Effect.Kind.allCases {
            let i = k.rawValue, a = d[i * 3], b = d[i * 3 + 1], wet = on[i] ? d[i * 3 + 2] : 0, from = mix[i]
            guard wet > 0 || from > 0.0005 || (k == .echo || k == .space) && on[i] else { mix[i] = 0; continue }
            let step = (wet - from) / Float(n)
            var m = from
            func put(_ j: Int, _ l: Float, _ r: Float) { m += step; L[j] += ((l.isFinite ? l : 0) - L[j]) * m; R[j] += ((r.isFinite ? r : 0) - R[j]) * m }
            switch k {
            case .filter:                                   // below the middle it closes from above, over it from below
                let f = a < 0.5 ? 60 * pow(2, a * 2 * 8.2) : 20 * pow(2, (a - 0.5) * 2 * 8), g = min(0.95, 2 * sin(Float.pi * min(f, rate * 0.16) / rate)), q = 1.9 - 1.75 * b
                for j in 0..<n {
                    lp.0 += g * bp.0; let hl = L[j] - lp.0 - q * bp.0; bp.0 += g * hl
                    lp.1 += g * bp.1; let hr = R[j] - lp.1 - q * bp.1; bp.1 += g * hr
                    if !(abs(bp.0) < 8) || !(abs(bp.1) < 8) { lp = (0, 0); bp = (0, 0) }
                    if a < 0.5 { put(j, lp.0, lp.1) } else { put(j, hl, hr) }
                }
            case .drive:
                let g = 1 + a * a * 40, c = 0.05 + b * 0.9, back = 1 / (0.6 + 0.4 * min(g, 6))
                for j in 0..<n {
                    tone.0 += (tanh(L[j] * g) - tone.0) * c; tone.1 += (tanh(R[j] * g) - tone.1) * c
                    put(j, tone.0 * back * 1.6, tone.1 * back * 1.6)
                }
            case .crush:
                let levels = pow(2, 1.5 + (1 - a) * 12), every = 1 + b * b * 60
                for j in 0..<n {
                    crushLeft -= 1
                    if crushLeft <= 0 { crushLeft += every; crushed = ((L[j] * levels).rounded() / levels, (R[j] * levels).rounded() / levels) }
                    put(j, crushed.0, crushed.1)
                }
            case .ring:
                let f = 20 * pow(2, a * 7.5) / rate
                for j in 0..<n {
                    ringPhase += f; if ringPhase >= 1 { ringPhase -= 1 }
                    let s = sin(ringPhase * 2 * .pi), w = s + ((s > 0 ? 1 : -1) - s) * b
                    put(j, L[j] * w, R[j] * w)
                }
            case .stutter:                                  // a piece caught each bar's part, said again
                let every = Int(beat * division(a) * 2), piece = max(64, min(heldSize, Int(Float(every) * (0.06 + b * 0.94) / 2)))
                for j in 0..<n {
                    if stutterLeft <= 0 { stutterLeft = max(128, every); stutterAt = 0; stutterLen = 0 }
                    if stutterLen < piece { held[stutterLen * 2] = L[j]; held[stutterLen * 2 + 1] = R[j]; stutterLen += 1; put(j, L[j], R[j]) }
                    else {
                        let edge = min(1, Float(min(stutterAt, stutterLen - stutterAt)) / 64)
                        put(j, held[stutterAt * 2] * edge, held[stutterAt * 2 + 1] * edge)
                        stutterAt += 1; if stutterAt >= stutterLen { stutterAt = 0 }
                    }
                    stutterLeft -= 1
                }
            case .gate:
                let cycle = beat * division(a)
                for j in 0..<n {
                    gatePhase += 1 / cycle; if gatePhase >= 1 { gatePhase -= 1 }
                    gateNow += ((gatePhase < 0.05 + b * 0.9 ? 1 : 0) - gateNow) * 0.01
                    put(j, L[j] * gateNow, R[j] * gateNow)
                }
            case .chorus, .flanger, .wide:
                let flanging = k == .flanger, wide = k == .wide
                let base = wide ? (0.002 + b * 0.02) * rate : flanging ? 0.0015 * rate : 0.012 * rate, depth = wide ? 0 : flanging ? 0.0012 * rate : b * 0.006 * rate
                let f = (0.05 + a * a * 6) / rate, back = flanging ? b * 0.85 : 0
                for j in 0..<n {
                    lfo += f; if lfo >= 1 { lfo -= 1 }
                    func tap(_ p: UnsafeMutablePointer<Float>, _ turn: Float) -> Float {
                        let x = Float(shortAt + Self.shortSize) - max(1, base + depth * sin((lfo + turn) * 2 * .pi)), i0 = Int(x), fr = x - Float(i0), mask = Self.shortSize - 1
                        return p[i0 & mask] * (1 - fr) + p[(i0 + 1) & mask] * fr
                    }
                    let l = tap(shortL, 0), r = tap(shortR, 0.25)
                    shortL[shortAt & (Self.shortSize - 1)] = L[j] + max(-2, min(2, l * back)); shortR[shortAt & (Self.shortSize - 1)] = R[j] + max(-2, min(2, r * back))
                    shortAt = (shortAt + 1) & (Self.shortSize - 1)
                    if wide { let mid = (L[j] + R[j]) / 2; put(j, mid + l * a * 0.8, mid - r * a * 0.8) } else { put(j, (L[j] + l) * 0.8, (R[j] + r) * 0.8) }
                }
            case .echo:
                let time = max(64, min(size - 2, Int(beat * division(a)))), back = b * 0.92
                for j in 0..<n {
                    let p = (at - time + size) % size, l = left[p], r = right[p]
                    left[at] = tanh((on[i] ? L[j] : 0) + r * back); right[at] = tanh((on[i] ? R[j] : 0) + l * back)          // to and fro
                    at += 1; if at >= size { at = 0 }
                    m += step; L[j] += l * m; R[j] += r * m
                }
            case .space:
                let back = 0.7 + a * 0.28, c = 1 - b * 0.75
                for j in 0..<n {
                    let x = (L[j] + R[j]) * 0.06
                    var outL: Float = 0, outR: Float = 0
                    for q in 0..<8 {
                        for side in 0..<2 {
                            let line = combs + combSize * (side * 8 + q), delay = Self.combAt[q] + side * 23, y = line[(combPlace - delay) & (combSize - 1)]
                            if side == 0 { outL += y; damp.0 += (y - damp.0) * c } else { outR += y; damp.1 += (y - damp.1) * c }
                            let v = x + (y * c + (side == 0 ? damp.0 : damp.1) * (1 - c)) * back
                            line[combPlace & (combSize - 1)] = v.isFinite ? max(-4, min(4, v)) : 0
                        }
                    }
                    for q in 0..<4 {
                        for side in 0..<2 {
                            let line = combs + combSize * (16 + side * 4 + q), y = line[(combPlace - Self.allAt[q] - side * 23) & (combSize - 1)], v = side == 0 ? outL : outR
                            line[combPlace & (combSize - 1)] = v + y * 0.5
                            if side == 0 { outL = y - v } else { outR = y - v }
                        }
                    }
                    combPlace &+= 1
                    m += step; L[j] += outL * m; R[j] += outR * m
                }
            case .freeze:                                   // what was there when it came on, held
                let len = max(512, min(heldSize, Int(rate * (0.04 + a * 0.6))))
                if from <= 0.0005 { freezeFull = 0; freezeAt = 0 }
                for j in 0..<n {
                    if freezeFull < len { held[freezeFull * 2] = L[j]; held[freezeFull * 2 + 1] = R[j]; freezeFull += 1; put(j, L[j], R[j]); continue }
                    let edge = min(1, Float(min(freezeAt, len - freezeAt)) / 256), l = held[freezeAt * 2], r = held[freezeAt * 2 + 1]
                    put(j, L[j] * (1 - b) + l * edge, R[j] * (1 - b) + r * edge)
                    freezeAt += 1; if freezeAt >= len { freezeAt = 0 }
                }
            }
            mix[i] = wet
        }
    }
}
