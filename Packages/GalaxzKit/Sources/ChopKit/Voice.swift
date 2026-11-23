import Foundation

/// Sixteen sung syllables, made here (TO-2's CHOP): a voice before anything is recorded.
public enum SungVoice {
    static let names = ["A", "I", "U", "E", "O", "KA", "SA", "TA", "NA", "HA", "MA", "YA", "RA", "WA", "NE", "YO"]
    static let kitSR: Float = 48000
    static let sliceLen = 17280

    public static let kit: Kit = {
        var k = Kit(name: "VOX", rate: Double(kitSR), audio: sing(), chops: names.enumerated().map { .init(name: $1, start: $0 * sliceLen, end: ($0 + 1) * sliceLen) })
        // the last eight again, an octave up and backwards: a kit is twenty-four
        k.chops += (0..<8).map { i in var c = k.chops[i * 2]; c.name = names[i * 2] + (i & 1 == 0 ? "+" : "<"); if i & 1 == 0 { c.pitch = 12 } else { c.reverse = true }; return c }
        return k
    }()

    // MARK: the voice: a pulse through three moving formants

    private struct Syllable {
        var consonant: Character?
        var vowel: Character
    }

    private static let syllables: [Syllable] = [
        Syllable(consonant: nil, vowel: "a"), Syllable(consonant: nil, vowel: "i"),
        Syllable(consonant: nil, vowel: "u"), Syllable(consonant: nil, vowel: "e"),
        Syllable(consonant: nil, vowel: "o"), Syllable(consonant: "k", vowel: "a"),
        Syllable(consonant: "s", vowel: "a"), Syllable(consonant: "t", vowel: "a"),
        Syllable(consonant: "n", vowel: "a"), Syllable(consonant: "h", vowel: "a"),
        Syllable(consonant: "m", vowel: "a"), Syllable(consonant: "y", vowel: "a"),
        Syllable(consonant: "r", vowel: "a"), Syllable(consonant: "w", vowel: "a"),
        Syllable(consonant: "n", vowel: "e"), Syllable(consonant: "y", vowel: "o"),
    ]

    /// F1, F2, F3 of a small bright voice (the Japanese five).
    private static func formants(_ v: Character) -> (Float, Float, Float) {
        switch v {
        case "i": return (330, 2850, 3550)
        case "u": return (380, 1450, 2750)
        case "e": return (560, 2350, 3050)
        case "o": return (560, 980, 2900)
        default:  return (920, 1480, 3000)      // a
        }
    }

    /// A two-pole band-pass (constant skirt), enough for a formant.
    private struct Band {
        var b0: Float = 0, a1: Float = 0, a2: Float = 0
        var x1: Float = 0, x2: Float = 0, y1: Float = 0, y2: Float = 0
        mutating func set(_ f: Float, q: Float, sr: Float) {
            let w = 2 * Float.pi * min(f, sr * 0.45) / sr
            let alpha = sin(w) / (2 * q)
            let a0 = 1 + alpha
            b0 = alpha / a0
            a1 = -2 * cos(w) / a0
            a2 = (1 - alpha) / a0
        }
        mutating func run(_ x: Float) -> Float {
            let y = b0 * (x - x2) - a1 * y1 - a2 * y2
            x2 = x1; x1 = x
            y2 = y1; y1 = y
            return y
        }
    }

    private static func sing() -> [Float] {
        let sr = kitSR
        var buf = [Float](repeating: 0, count: names.count * sliceLen + 8)
        var seed: UInt32 = 0x1234ABCD
        func noise() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(Int32(bitPattern: seed)) / 2147483648
        }
        let f0: Float = 261.63                       // every syllable is sung on C4
        for (si, syl) in syllables.enumerated() {
            let target = formants(syl.vowel)
            // where the formants start, how long they take to reach the vowel, when the voice starts
            var from = target
            var glide: Float = 0.001
            var voiceOn: Float = 0.006
            var nasalUntil: Float = 0
            switch syl.consonant {
            case "k": voiceOn = 0.046
            case "s": voiceOn = 0.078
            case "t": voiceOn = 0.030
            case "h": voiceOn = 0.062
            case "n": from = (270, 1500, 2500); glide = 0.045; nasalUntil = 0.070
            case "m": from = (270, 1050, 2400); glide = 0.050; nasalUntil = 0.075
            case "y": from = (300, 2700, 3400); glide = 0.090
            case "r": from = (420, 1600, 2500); glide = 0.040
            case "w": from = (340, 800, 2400); glide = 0.090
            default: break
            }
            var bands = [Band(), Band(), Band(), Band()]
            var fric = Band()
            switch syl.consonant {
            case "s": fric.set(6500, q: 1.1, sr: sr)
            case "k": fric.set(2800, q: 2.0, sr: sr)
            case "t": fric.set(4800, q: 1.4, sr: sr)
            default: fric.set(3000, q: 1, sr: sr)
            }
            var phase: Float = 0
            var tilt: Float = 0                       // the source's one-pole low-pass
            var power: Float = 0                      // of the settled vowel, for the level
            var powerCount: Float = 0
            let base = si * sliceLen
            for i in 0..<sliceLen {
                let t = Float(i) / sr
                if i % 32 == 0 {
                    // formants travel from the consonant's place to the vowel
                    let k = min(1, max(0, (t - voiceOn) / glide))
                    let s = k * k * (3 - 2 * k)
                    let f1 = from.0 + (target.0 - from.0) * s
                    let f2 = from.1 + (target.1 - from.1) * s
                    let f3 = from.2 + (target.2 - from.2) * s
                    bands[0].set(f1, q: f1 / 90, sr: sr)
                    bands[1].set(f2, q: f2 / 120, sr: sr)
                    bands[2].set(f3, q: f3 / 170, sr: sr)
                    bands[3].set(4300, q: 18, sr: sr)
                }
                // the pulse: a band-limited saw, scooping up into the note, a little vibrato once it settles
                let scoop = -0.45 * exp(-max(0, t - voiceOn) / 0.03)
                let vibDepth = 0.10 * min(1, max(0, (t - 0.13) / 0.12))
                let semis = scoop + vibDepth * sin(2 * Float.pi * 5.7 * t)
                let inc = f0 * pow(2, semis / 12) / sr
                phase += inc
                if phase >= 1 { phase -= 1 }
                var saw = 2 * phase - 1
                if phase < inc { let x = phase / inc; saw -= x + x - x * x - 1 }
                else if phase > 1 - inc { let x = (phase - 1) / inc; saw -= x * x + x + x + 1 }
                tilt += (saw - tilt) * 0.27
                // the voice's level: in after the consonant, out before the end of the slice
                let vin = min(1, max(0, (t - voiceOn) / 0.012))
                let vout = min(1, max(0, (0.345 - t) / 0.05))
                var voiced = vin * vout
                if syl.consonant == "r" { voiced *= 0.45 + 0.55 * min(1, max(0, (t - voiceOn - 0.012) / 0.02)) }   // the tap
                var src = (tilt + noise() * 0.035) * voiced
                // h: breath through the vowel's own formants
                if syl.consonant == "h" {
                    let b = min(1, t / 0.01) * min(1, max(0, (0.075 - t) / 0.02))
                    src += noise() * 0.5 * b
                }
                let nasal: Float = t < nasalUntil ? 1 : max(0, 1 - (t - nasalUntil) / 0.015)
                var y = bands[0].run(src) * 1.0
                y += bands[1].run(src) * (0.72 - 0.5 * nasal)
                y += bands[2].run(src) * (0.38 - 0.3 * nasal)
                y += bands[3].run(src) * 0.16 * (1 - nasal)
                y *= 1 - 0.45 * nasal
                // k, s, t: noise at the front
                switch syl.consonant {
                case "s":
                    let e = min(1, t / 0.015) * min(1, max(0, (0.09 - t) / 0.02))
                    y += fric.run(noise()) * 0.4 * e
                case "k":
                    let e = t < 0.008 ? 0 : exp(-(t - 0.008) / 0.012)
                    y += fric.run(noise()) * 0.5 * e
                case "t":
                    let e = t < 0.008 ? 0 : exp(-(t - 0.008) / 0.006)
                    y += fric.run(noise()) * 0.42 * e
                default:
                    break
                }
                buf[base + i] = y
                if t > 0.14 && t < 0.30 { power += y * y; powerCount += 1 }
            }
            // every syllable's vowel as loud as the next (a burst no longer sets the
            // level), peaks rounded off, clean edges
            let rms = powerCount > 0 ? (power / powerCount).squareRoot() : 0
            let g: Float = rms > 0.00001 ? 0.27 / rms : 0
            let edge = 96
            for i in 0..<sliceLen {
                var w: Float = 1
                if i < edge { w = Float(i) / Float(edge) }
                if i >= sliceLen - edge { w = Float(sliceLen - 1 - i) / Float(edge) }
                buf[base + i] = tanh(buf[base + i] * g * 1.1) * 0.86 * w
            }
        }
        return buf
    }
}
