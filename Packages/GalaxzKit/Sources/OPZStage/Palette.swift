import DotKit

/// The colours of the lights: off-white ink, one yellow, a colour a track, the OP-Z's pages.
public enum Palette {
    public static let ink = DotColor(0xEDEBE6)
    public static let yellow = DotColor(0xFFD23F)
    public static let red = DotColor(0xFF4A2E)
    public static let green = DotColor(0x2FD18B)
    public static let blue = DotColor(0x3D7BFF)
    public static let purple = DotColor(0x9B6BFF)
    /// The tumbler's page and EUCLID's.
    public static let pink = DotColor(0xFF3D8B)
    /// The seventh page, GROOVE: light green, apart from teal and the envelope's green.
    public static let lime = DotColor(0xA6FF6B)
    public static let teal = DotColor(0x1FE5C0)

    public static let tracks: [DotColor] = [
        DotColor(0xFF4A2E), DotColor(0xFF6A2E), DotColor(0xFF8A34), DotColor(0xFFA63F),     // kick snare perc sample
        DotColor(0x2F63FF), DotColor(0x2F8CFF), DotColor(0x38B2FF), DotColor(0x52D6F5),     // bass lead arp chord
        DotColor(0x2FD18B), DotColor(0x6FE06A),                                             // fx1 fx2
        DotColor(0xFFD23F), DotColor(0xFFE58A),                                             // tape master
        DotColor(0xFF5FA8), DotColor(0xC58BFF), DotColor(0xF2F0EA), DotColor(0xA9A59C),     // perform module lights motion
    ]
    public static func track(_ t: Int) -> DotColor { tracks[t & 15] }

    /// A parameter page: its name, its light, what its four dials are (indices into the 18 sound values), and what they are called
    /// where that is not the value's own name.
    public struct ParamPage: Sendable {
        public let name: String
        public let colour: DotColor
        public let params: [Int]
        public var labels: [String?] = [nil, nil, nil, nil]
    }

    public static let orange = DotColor(0xFF8A34)
    static let soundPage = ParamPage(name: "SOUND", colour: ink, params: [0, 1, 8, 9])
    static let envelopePage = ParamPage(name: "ENVELOPE", colour: green, params: [2, 3, 4, 5])
    static let lfoPage = ParamPage(name: "LFO", colour: purple, params: [13, 14, 15, 16])
    static let sendPage = ParamPage(name: "SEND", colour: orange, params: [6, 7, 10, 11])

    /// A track's pages, in the order SHIFT turns them (TE's manual, p. 21). `samples`: it plays a sample pack.
    public static func pages(_ track: Int, samples: Bool = false) -> [ParamPage] {
        func named(_ p: ParamPage, _ l: [String?]) -> ParamPage { ParamPage(name: p.name, colour: p.colour, params: p.params, labels: l) }
        switch track {
        case 0...3: return [samples ? named(soundPage, ["PITCH", "REVERSE", nil, nil]) : soundPage, envelopePage, lfoPage, sendPage]
        case 6: return [soundPage, envelopePage, ParamPage(name: "ARP", colour: blue, params: [13, 14, 15, 16], labels: ["SPEED", "PATTERN", "STYLE", "RANGE"]), sendPage]
        case 10: return [named(soundPage, ["SPEED", "FINE", nil, nil]), sendPage]
        case 11: return [named(soundPage, ["CHORUS", "DRIVE", nil, nil])]
        default: return [soundPage, envelopePage, lfoPage, sendPage]
        }
    }
    public static let paramNames = ["P1", "P2", "ATTACK", "DECAY", "SUSTAIN", "RELEASE", "FX 1", "FX 2", "FILTER", "RESO",
                                    "PAN", "LEVEL", "GLIDE", "DEPTH", "RATE", "DEST", "SHAPE", "STYLE"]
    public static let shortNames = ["KD", "SD", "PC", "SM", "BS", "LD", "AR", "CH", "F1", "F2", "TP", "MA", "PF", "MO", "LI", "MT"]
    public static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    public static func note(_ n: Int) -> String { noteNames[((n % 12) + 12) % 12] + String(n / 12 - 1) }
}
