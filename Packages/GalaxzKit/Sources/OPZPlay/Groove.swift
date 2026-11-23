// From TO-2 (Model/Patches.swift), as it is there.

/// GROOVE: one-bar, sixteen-step rhythms for the notes you latch, the
/// syncopations a piano roll is full of, on shelves by feel. A pattern is
/// sixteen characters: X an accent, x a hit, o a ghost, . a rest. Each bay
/// keeps the pattern it plays (its steps, not only a number), so a session
/// keeps its groove even when the library changes; your own patterns sit after
/// the factory ones.
public enum Groove {
    public struct Pattern: Codable, Equatable, Identifiable, Sendable {
        public var id: String { name + steps }
        public var name: String
        public var family: Int
        public var steps: String
    }
    public static let families = ["PIANO", "FUTURE", "CUTE", "DANCE", "LATIN", "HALF TIME", "CHOP", "SPARSE", "MOTION"]
    public static let library: [Pattern] = [
        Pattern(name: "TRESILLO", family: 0, steps: "X..x..x.X..x..x."),
        Pattern(name: "ANTHEM", family: 1, steps: "X..x..x..x..X..x"),
        Pattern(name: "BOUNCE", family: 1, steps: "X..x..x..x..X.x."),
        Pattern(name: "SWAY", family: 0, steps: "X..x.x..X..x.x.."),
        Pattern(name: "SKIP", family: 0, steps: "X.x..x.x.x..X.x."),
        Pattern(name: "CHOPPY", family: 6, steps: "Xx.x.xx.X.xx.x.x"),
        Pattern(name: "KAWAII", family: 2, steps: "X.x.Xx.x..x.Xx.x"),
        Pattern(name: "STAB", family: 1, steps: "X.....x...x..x.."),
        Pattern(name: "PUSH", family: 0, steps: "X..x...x..x...x."),
        Pattern(name: "ROLL", family: 8, steps: "X...X...X.x.Xxxx"),
        Pattern(name: "GALLOP", family: 8, steps: "X.xxX.xxX.xxX.xx"),
        Pattern(name: "RUN", family: 8, steps: "XxxxXxxxXxxxXxxx"),
        Pattern(name: "BALLAD", family: 0, steps: "X.....x.X.....x."),
        Pattern(name: "HYMN", family: 0, steps: "X...x...X...x.x."),
        Pattern(name: "POP 8THS", family: 0, steps: "X.x.x.X.X.x.x.X."),
        Pattern(name: "ANTICIPATE", family: 0, steps: "X..x..X...x...X."),
        Pattern(name: "GOSPEL", family: 0, steps: "X..oX..oX..oX..o"),
        Pattern(name: "CITY POP", family: 0, steps: "X.ox..X.o.Xx..X."),
        Pattern(name: "SHELTER", family: 1, steps: "X..x..X...X..x.."),
        Pattern(name: "FB CHORDS", family: 1, steps: "X..x..x...X.x..."),
        Pattern(name: "LIFT", family: 1, steps: "X..x..X..xx.Xxxx"),
        Pattern(name: "DROP", family: 1, steps: "X.xx..X.X.xx..X."),
        Pattern(name: "WOBBLE", family: 1, steps: "X.oxX.x.X.oxX.x."),
        Pattern(name: "PUMPED", family: 1, steps: "..Xx..Xx..Xx..Xx"),
        Pattern(name: "TWINKLE", family: 2, steps: "X.x.X.x.Xxx.X.x."),
        Pattern(name: "BUNNY HOP", family: 2, steps: "Xx..xx..Xx..xx.."),
        Pattern(name: "SKIPPY", family: 2, steps: "X..xX..xX..xX..x"),
        Pattern(name: "CANDY", family: 2, steps: "X.xx.x..X.xx.x.."),
        Pattern(name: "MUSIC BOX", family: 2, steps: "X...X.x.X...X.x."),
        Pattern(name: "PIKO", family: 2, steps: "Xxx.X...Xxx.X..."),
        Pattern(name: "SPARKLE", family: 2, steps: "X..x.o.xX..x.o.x"),
        Pattern(name: "FOUR FLOOR", family: 3, steps: "X...X...X...X..."),
        Pattern(name: "OFFBEAT", family: 3, steps: "..X...X...X...X."),
        Pattern(name: "HOUSE", family: 3, steps: "..x.X..x..x.X..x"),
        Pattern(name: "2-STEP", family: 3, steps: "X..o...x..Xx..x."),
        Pattern(name: "DISCO", family: 3, steps: "x.X.x.X.x.X.x.X."),
        Pattern(name: "GARAGE", family: 3, steps: "X.....xx..X...x."),
        Pattern(name: "TRANCE GATE", family: 3, steps: "Xx.xX.xx.xx.Xx.x"),
        Pattern(name: "UK FUNKY", family: 3, steps: "X..x..x.X.x..o.."),
        Pattern(name: "SON CLAVE", family: 4, steps: "X..x..X...x.X..."),
        Pattern(name: "RUMBA", family: 4, steps: "X..x...X..x.X..."),
        Pattern(name: "BOSSA", family: 4, steps: "X..x..x...X..x.."),
        Pattern(name: "CINQUILLO", family: 4, steps: "X.xx.xx.X.xx.xx."),
        Pattern(name: "DEMBOW", family: 4, steps: "X..xX.o.X..xX.o."),
        Pattern(name: "AFRO", family: 4, steps: "X..x..Xo..x.X.x."),
        Pattern(name: "SAMBA", family: 4, steps: "X..xX..xX.xx..x."),
        Pattern(name: "HALF TIME", family: 5, steps: "X.........x....."),
        Pattern(name: "TRAP ROLL", family: 5, steps: "X.x.x.x.X.xxxxxx"),
        Pattern(name: "TRIPLETISH", family: 5, steps: "X.x..x..X.x..x.."),
        Pattern(name: "DRILL", family: 5, steps: "X..x..X.x..o..x."),
        Pattern(name: "LO-FI", family: 5, steps: "X....o.x..X...x."),
        Pattern(name: "STUTTER", family: 6, steps: "Xxx.....Xxx....."),
        Pattern(name: "PAIRS", family: 6, steps: "Xx..Xx..Xx..Xx.."),
        Pattern(name: "GATED", family: 6, steps: "Xxxx....Xxxx...."),
        Pattern(name: "LASER", family: 6, steps: "XxxxXxxx........"),
        Pattern(name: "CALL ANSWER", family: 6, steps: "X.xx....X...X.xx"),
        Pattern(name: "ECHO", family: 6, steps: "X..o..o.Xo......"),
        Pattern(name: "ONE", family: 7, steps: "X..............."),
        Pattern(name: "TWO", family: 7, steps: "X.......X......."),
        Pattern(name: "DOTTED", family: 7, steps: "X.....x.....X..."),
        Pattern(name: "LATE", family: 7, steps: "X.........x....."),
        Pattern(name: "BREATH", family: 7, steps: "X......x...x...."),
        Pattern(name: "SIGH", family: 7, steps: "...X.......X...."),
        Pattern(name: "EIGHTHS", family: 8, steps: "X.x.X.x.X.x.X.x."),
        Pattern(name: "QUINT", family: 8, steps: "X....x....x....x"),
        Pattern(name: "SEPT", family: 8, steps: "X......x......x."),
        Pattern(name: "ACCEL", family: 8, steps: "X.....x...x..x.x"),
        Pattern(name: "RITARD", family: 8, steps: "Xx.x..x...x....."),
        Pattern(name: "TUMBLE", family: 8, steps: "Xx.xx.Xx.xx.Xx.x"),
    ]
    public static var names: [String] { library.map(\.name) }
    /// The steps as masks: hits (accents and ghosts included), accents, ghosts.
    public static func masks(_ steps: String) -> (hit: UInt16, accent: UInt16, ghost: UInt16) {
        var h: UInt16 = 0, a: UInt16 = 0, g: UInt16 = 0
        for (i, ch) in steps.prefix(16).enumerated() {
            let bit = UInt16(1) << UInt16(i)
            switch ch {
            case "X": h |= bit; a |= bit
            case "x": h |= bit
            case "o": h |= bit; g |= bit
            default: break
            }
        }
        return (h, a, g)
    }
    /// A step's next state in the editor: rest, hit, accent, ghost, rest.
    public static func cycle(_ ch: Character) -> Character {
        switch ch { case ".": return "x"; case "x": return "X"; case "X": return "o"; default: return "." }
    }
    /// The pattern a variation's second bar plays: the next one on its shelf.
    public static func sister(of index: Int) -> Int {
        guard index >= 0 && index < library.count else { return index }
        let f = library[index].family
        let shelf = library.indices.filter { library[$0].family == f }
        guard let k = shelf.firstIndex(of: index), shelf.count > 1 else { return index }
        return shelf[(k + 1) % shelf.count]
    }
    public static let orders = ["UP", "DOWN", "PLAYED", "RANDOM", "CHORD"]
    public static func order(_ v: Float) -> Int { min(orders.count - 1, Int(v * Float(orders.count) * 0.999)) }
    /// The pedal: a root note the groove keeps coming back to.
    public static let pedals = ["OFF", "BEATS", "OFFBEATS", "EVERY HIT", "GAPS", "TAKE TURNS"]
    /// What the bars after the first do.
    public static let varies = ["AS DRAWN", "FILL /4", "FILL /2", "A/B", "SHIFT", "MIRROR B", "SPARSE B"]
}

