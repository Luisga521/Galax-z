import Foundation

/// A source cut into chops (from TO-2's Chopper.swift): where the hits are, or equal pieces, each trimmed of silence.
public enum Chopper {
    public enum Mode: Int, CaseIterable, Codable, Sendable {
        case hits, eight, sixteen, twentyFour, whole
        public var name: String { ["HITS", "8 EQUAL", "16 EQUAL", "24 EQUAL", "WHOLE"][rawValue] }
    }
    public static let most = 24
    /// The longest a chop may be, and the longest a source is read, in seconds.
    public static let maxSlice = 10.0, maxSource = 120.0

    /// Where the hits are: a rise of the loudness (10 ms frames) above what came just before,
    /// at least 90 ms apart, the strongest `maxCount` of them, in time order.
    /// `sensitivity` 0 … 1: more and softer hits as it goes up.
    public static func onsets(_ x: [Float], rate: Double, maxCount: Int, sensitivity: Float) -> [Int] {
        let hop = max(128, Int(rate * 0.01))
        let nf = x.count / hop
        guard nf > 4 else { return [0] }
        var db = [Float](repeating: -120, count: nf)
        for k in 0..<nf {
            var e: Float = 0
            let base = k * hop
            for i in 0..<hop { let s = x[base + i]; e += s * s }
            db[k] = 10 * log10(e / Float(hop) + 1e-12)
        }
        let peak = db.max() ?? 0
        let floorDB = peak - 42
        let rise = 13 - 9 * max(0, min(1, sensitivity))          // 13 dB … 4 dB
        let gap = max(1, Int(0.09 * rate) / hop)
        var cands: [(at: Int, strength: Float)] = []
        var last = -gap
        for k in 1..<nf {
            let before = (max(0, k - 3)..<k).map { db[$0] }
            let mean = before.reduce(0, +) / Float(max(1, before.count))
            let d = db[k] - mean
            if d > rise && db[k] > floorDB && k - last >= gap {
                // a little before the frame, so the attack is whole
                cands.append((max(0, k * hop - hop / 2), d + (db[k] - floorDB) * 0.2))
                last = k
            }
        }
        // a source that starts on a sound has a hit at its very start (nothing rises before it)
        if let first = db.firstIndex(where: { $0 > floorDB }), first < gap,
           cands.first.map({ $0.at > first * hop + hop }) ?? true {
            cands.insert((max(0, first * hop - hop / 2), 20), at: 0)
        }
        if cands.isEmpty { return [0] }
        let picked = cands.count > maxCount ? Array(cands.sorted { $0.strength > $1.strength }.prefix(maxCount)) : cands
        return picked.map(\.at).sorted()
    }

    /// One piece of a source, cut, trimmed of silence at both ends and kept short enough.
    public static func piece(_ x: ArraySlice<Float>, rate: Double) -> [Float] {
        var a = x.startIndex, b = x.endIndex
        guard b - a > 32 else { return [] }
        let peak = x.reduce(Float(0)) { max($0, abs($1)) }
        guard peak > 0.0005 else { return [] }
        let head = peak * 0.02, tail = peak * 0.0018            // -34 dB in, -55 dB out
        while a < b - 32 && abs(x[a]) < head { a += 1 }
        a = max(x.startIndex, a - Int(rate * 0.002))            // keep 2 ms before the hit
        while b > a + 32 && abs(x[b - 1]) < tail { b -= 1 }
        b = min(b, a + Int(maxSlice * rate))
        return Array(x[a..<b])
    }

    /// A source's chops.
    public static func cut(_ x: [Float], rate: Double, mode: Mode, sensitivity: Float = 0.5, name: String = "CHOPS") -> Kit {
        let x = Array(x.prefix(Int(maxSource * rate)))
        let cuts: [Int] = switch mode {
        case .hits: onsets(x, rate: rate, maxCount: most, sensitivity: sensitivity)
        case .eight: (0..<8).map { $0 * x.count / 8 }
        case .sixteen: (0..<16).map { $0 * x.count / 16 }
        case .twentyFour: (0..<24).map { $0 * x.count / 24 }
        case .whole: [0]
        }
        var audio: [Float] = [], chops: [Kit.Chop] = []
        for (k, c) in cuts.enumerated() {
            let e = k + 1 < cuts.count ? cuts[k + 1] : x.count
            guard e > c else { continue }
            let p = mode == .hits || mode == .whole ? piece(x[c..<e], rate: rate) : Array(x[c..<min(e, c + Int(maxSlice * rate))])
            guard !p.isEmpty else { continue }
            chops.append(.init(name: "\(chops.count + 1)", start: audio.count, end: audio.count + p.count))
            audio += p
            audio += [Float](repeating: 0, count: 32)
        }
        let peak = audio.reduce(Float(0)) { max($0, abs($1)) }
        if peak > 0.0001 { let g = 0.89 / peak; for i in audio.indices { audio[i] *= g } }
        return Kit(name: name, rate: rate, audio: audio, chops: chops)
    }
}

/// Chops of one sound, mono.
public struct Kit: Sendable, Equatable {
    public struct Chop: Codable, Equatable, Sendable {
        public var name: String
        public var start: Int, end: Int
        /// Semitones; 0-1; 0-1.
        public var pitch = 0, level = 1.0, pan = 0.5
        public var reverse = false, on = true
        /// It stops what another chop of it plays.
        public var choke = false
        public init(name: String, start: Int, end: Int) { (self.name, self.start, self.end) = (name, start, end) }
    }
    public var name: String
    public var rate: Double
    public var audio: [Float]
    public var chops: [Chop]
    public init(name: String, rate: Double, audio: [Float], chops: [Chop]) { (self.name, self.rate, self.audio, self.chops) = (name, rate, audio, chops) }
    /// For drawing: the loudest of each of `n` parts.
    public func shape(_ n: Int) -> [Float] {
        guard !audio.isEmpty, n > 0 else { return [] }
        return (0..<n).map { k in
            let a = k * audio.count / n, b = max(a + 1, (k + 1) * audio.count / n)
            return stride(from: a, to: min(b, audio.count), by: max(1, (b - a) / 64)).reduce(Float(0)) { max($0, abs(audio[$1])) }
        }
    }
}
