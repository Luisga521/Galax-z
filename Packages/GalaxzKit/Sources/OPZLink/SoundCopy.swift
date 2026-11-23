import Foundation

/// The OP-Z's sound from one buffer to another, for the audio thread: no locks, nothing allocated.
public struct SoundCopy: Sendable {
    /// The gain now; it goes to the one wanted over about 20 ms, so nothing clicks.
    public private(set) var gain: Float = 0
    /// The loudest sample since it was last taken.
    public var peak: Float = 0

    public init() {}

    /// `frames` of interleaved samples: the first two channels go to the first two, one channel to both; the rest are silent.
    public mutating func copy(_ from: UnsafePointer<Float>, channels inChannels: Int, to out: UnsafeMutablePointer<Float>, channels outChannels: Int, frames: Int, wanted: Float) {
        guard inChannels > 0, outChannels > 0 else { return }
        let target = wanted.isFinite ? min(1, max(0, wanted)) : 0
        for i in 0..<frames {
            gain += (target - gain) * 0.002
            let l = from[i * inChannels], r = inChannels > 1 ? from[i * inChannels + 1] : l
            let a = (l.isFinite ? min(1, max(-1, l)) : 0) * gain, b = (r.isFinite ? min(1, max(-1, r)) : 0) * gain
            peak = max(peak, abs(a), abs(b))
            if outChannels == 1 { out[i] = (a + b) / 2; continue }
            out[i * outChannels] = a
            out[i * outChannels + 1] = b
            for c in 2..<max(2, outChannels) { out[i * outChannels + c] = 0 }
        }
    }

    /// Whether an audio device's name is an OP-Z's (TE writes it with either dash).
    public static func isOPZ(_ name: String) -> Bool {
        let n = name.lowercased().replacingOccurrences(of: "\u{2013}", with: "-").replacingOccurrences(of: "\u{2011}", with: "-")
        return n.contains("op-z") && !n.contains("boot")
    }
}
