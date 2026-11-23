// From TO-2 (Model/Chords.swift), as it is there.

// The chord library. Chords are written the Nashville way: a number for the
// degree of the major scale the chord sits on, then its quality (4, 5, 3m,
// 6m7, ♭7 …), so a progression is the same in every key. The KEY chosen in
// the header says what the numbers mean today.

public struct NashChord: Hashable, Codable, Sendable {
    public enum Quality: String, Codable, Sendable {
        case major = "", minor = "m", dim = "°", dom7 = "7", maj7 = "M7", min7 = "m7", sus4 = "sus"
        case add9 = "add9", min9 = "m9", maj9 = "M9", dom9 = "9", sus2 = "sus2", aug = "+"
    }
    public let degree: Int            // 1...7
    public var quality: Quality = .major
    public var flat = false           // ♭3, ♭6, ♭7: borrowed from the minor

    public init(_ degree: Int, _ quality: Quality = .major, flat: Bool = false) {
        self.degree = max(1, min(7, degree))
        self.quality = quality
        self.flat = flat
    }

    /// "4", "6m", "♭7", "2m7"
    public var label: String { (flat ? "♭" : "") + "\(degree)" + quality.rawValue }

    /// Semitones above the tonic.
    public var root: Int { [0, 2, 4, 5, 7, 9, 11][degree - 1] - (flat ? 1 : 0) }

    public var intervals: [Int] {
        switch quality {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .dim:   return [0, 3, 6]
        case .dom7:  return [0, 4, 7, 10]
        case .maj7:  return [0, 4, 7, 11]
        case .min7:  return [0, 3, 7, 10]
        case .sus4:  return [0, 5, 7]
        case .add9:  return [0, 4, 7, 14]
        case .min9:  return [0, 3, 7, 10, 14]
        case .maj9:  return [0, 4, 7, 11, 14]
        case .dom9:  return [0, 4, 7, 10, 14]
        case .sus2:  return [0, 2, 7]
        case .aug:   return [0, 4, 8]
        }
    }

    /// The chord's name in a key: "F", "Em", "Am7".
    public func name(tonic: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let suffix: String
        switch quality {
        case .major: suffix = ""
        case .minor: suffix = "m"
        case .dim:   suffix = "dim"
        case .dom7:  suffix = "7"
        case .maj7:  suffix = "maj7"
        case .min7:  suffix = "m7"
        case .sus4:  suffix = "sus4"
        case .add9:  suffix = "add9"
        case .min9:  suffix = "m9"
        case .maj9:  suffix = "maj9"
        case .dom9:  suffix = "9"
        case .sus2:  suffix = "sus2"
        case .aug:   suffix = "aug"
        }
        return names[((tonic + root) % 12 + 12) % 12] + suffix
    }
}

public struct Progression: Identifiable, Hashable, Sendable {
    public let name: String
    public let line: String               // where it comes from, one line
    public let chords: [NashChord]
    /// A song's structure: a name for every eight chords (VERSE, CHORUS, BRIDGE …). Empty: one run.
    public var sections: [String] = []
    /// The shelf it sits on in the library (Progressions.shelves).
    public var shelf = 0
    public var id: String { name }
    /// "4 · 5 · 3m · 6m"
    public var numbers: String { chords.map(\.label).joined(separator: " · ") }
}

public enum Progressions {
    private static func c(_ d: Int, _ q: NashChord.Quality = .major, flat: Bool = false) -> NashChord { NashChord(d, q, flat: flat) }

    private static let first: [Progression] = [
        Progression(name: "ROYAL ROAD", line: "the J-pop road: bright, then it aches", chords: [c(4), c(5), c(3, .minor), c(6, .minor)]),
        Progression(name: "KOMURO", line: "90s J-pop: starts sad, ends home", chords: [c(6, .minor), c(4), c(5), c(1)]),
        Progression(name: "CITY POP", line: "sevenths that keep turning", chords: [c(4, .maj7), c(3, .dom7), c(6, .min7), c(5, .min7), c(1, .dom7)]),
        Progression(name: "AXIS", line: "four chords, a thousand songs", chords: [c(1), c(5), c(6, .minor), c(4)]),
        Progression(name: "EPIC", line: "the same four from the minor end", chords: [c(6, .minor), c(4), c(1), c(5)]),
        Progression(name: "RISE", line: "climbs to home", chords: [c(4), c(5), c(6, .minor), c(1)]),
        Progression(name: "EMOTION", line: "home is the second chord", chords: [c(4), c(1), c(5), c(6, .minor)]),
        Progression(name: "FIFTIES", line: "doo-wop", chords: [c(1), c(6, .minor), c(4), c(5)]),
        Progression(name: "CANON", line: "eight chords, the long way round", chords: [c(1), c(5), c(6, .minor), c(3, .minor), c(4), c(1), c(4), c(5)]),
        Progression(name: "NOSTALGIA", line: "the four goes minor", chords: [c(1), c(3, .minor), c(4), c(4, .minor)]),
        Progression(name: "TWO FIVE ONE", line: "the jazz cadence", chords: [c(2, .min7), c(5, .dom7), c(1, .maj7)]),
        Progression(name: "ANDALUSIAN", line: "down the steps to a major three", chords: [c(6, .minor), c(5), c(4), c(3, .dom7)]),
        Progression(name: "MIXO", line: "a borrowed flat seven", chords: [c(1), c(7, flat: true), c(4), c(1)]),
        Progression(name: "VAMP", line: "two chords, back and forth", chords: [c(1), c(4)]),
        Progression(name: "BLUES", line: "twelve bars", chords: [c(1, .dom7), c(1, .dom7), c(1, .dom7), c(1, .dom7), c(4, .dom7), c(4, .dom7),
                                                                 c(1, .dom7), c(1, .dom7), c(5, .dom7), c(4, .dom7), c(1, .dom7), c(5, .dom7)]),
        // 4.8: more, and longer runs
        Progression(name: "MARUSA", line: "the city-pop staircase: 4M7 3·7 6m7 5m7 1·7", chords: [c(4, .maj7), c(3, .dom7), c(6, .min7), c(5, .min7), c(1, .dom7)]),
        Progression(name: "ANIME CHORUS", line: "sixteen chords: the road, a turn, the road again, home", chords: [
            c(4, .maj7), c(5), c(3, .min7), c(6, .minor), c(2, .min7), c(5), c(1), c(1, .dom7),
            c(4, .maj7), c(5), c(3, .min7), c(6, .minor), c(2, .min7), c(5, .sus4), c(1), c(1)]),
        Progression(name: "ROAD HOME", line: "eight chords: the royal road twice, the second time it lands", chords: [
            c(4, .maj7), c(5), c(3, .min7), c(6, .minor), c(4, .maj7), c(5), c(1), c(1)]),
        Progression(name: "FUTURE BASS", line: "wide sevenths for supersaws", chords: [c(6, .min7), c(4, .maj7), c(1, .add9), c(5)]),
        Progression(name: "KAWAII", line: "eight chords that keep smiling", chords: [
            c(1, .maj7), c(3, .min7), c(4, .maj7), c(5, .dom7), c(6, .min7), c(3, .min7), c(4, .maj7), c(5, .sus4)]),
        Progression(name: "SAD GIRL", line: "a major three, then the four goes minor", chords: [c(1), c(3, .dom7), c(6, .minor), c(4, .minor)]),
        Progression(name: "LO-FI", line: "two five one, then down to six", chords: [c(2, .min9), c(5, .dom9), c(1, .maj9), c(6, .min7)]),
        Progression(name: "NEO SOUL", line: "major sevenths and a borrowed minor four", chords: [c(1, .maj7), c(3, .min7), c(4, .maj7), c(4, .min7)]),
        Progression(name: "GOSPEL", line: "eight chords of church", chords: [
            c(1), c(1, .dom7), c(4), c(4, .minor), c(1), c(6, .min7), c(2, .min7), c(5, .dom7)]),
        Progression(name: "JAZZ TURN", line: "the turnaround: home, six, two, five", chords: [c(1, .maj7), c(6, .min7), c(2, .min7), c(5, .dom7)]),
        Progression(name: "TRITONE", line: "two, a flat-two seven sliding home", chords: [c(2, .min7), c(2, .dom7, flat: true), c(1, .maj7), c(1, .maj7)]),
        Progression(name: "SPACE CADENCE", line: "flat six, flat seven, home: the hero lands", chords: [c(1), c(6, flat: true), c(7, flat: true), c(1)]),
        Progression(name: "BACKDOOR", line: "home through the back: minor four, flat seven", chords: [c(1, .maj7), c(4, .min7), c(7, .dom7, flat: true), c(1, .maj7)]),
        Progression(name: "CLIMB", line: "eight chords up the scale", chords: [
            c(1), c(2, .minor), c(3, .minor), c(4), c(5), c(6, .minor), c(4), c(5, .sus4)]),
        Progression(name: "FALLING", line: "eight chords down, the bass a step at a time", chords: [
            c(1), c(5), c(6, .minor), c(3, .minor), c(4), c(1), c(2, .minor), c(5)]),
        Progression(name: "DREAM VAMP", line: "two major sevenths that never decide", chords: [c(1, .maj7), c(4, .maj7)]),
        Progression(name: "MINOR EPIC", line: "eight chords: the minor road, then it rises", chords: [
            c(6, .minor), c(4), c(1), c(5), c(6, .minor), c(4), c(2, .minor), c(3, .dom7)]),
        Progression(name: "SHOEGAZE", line: "suspended, then open", chords: [c(1, .add9), c(4, .sus2), c(6, .min7), c(4, .add9)]),
        Progression(name: "CINEMA", line: "sixteen chords that build, borrowing as they go", chords: [
            c(6, .minor), c(4), c(1), c(5), c(6, .minor), c(4), c(1), c(5),
            c(4), c(4, .minor), c(1), c(6, .minor), c(2, .min7), c(6, flat: true), c(7, flat: true), c(1)]),
        Progression(name: "EUROBEAT", line: "minor and driving, eight chords", chords: [
            c(6, .minor), c(5), c(4), c(5), c(6, .minor), c(5), c(4), c(3, .dom7)]),
        Progression(name: "SUNDAY", line: "a slow hymn of four and one, eight chords", chords: [
            c(1), c(4, .add9), c(1), c(5, .sus4), c(6, .minor), c(4, .add9), c(1), c(5)]),
        // 5.1: worship. The four chords a chorus is made of, the ways a verse walks, a bridge that
        // builds, the quiet in between, and whole songs to play through on BAR, a section a row.
        Progression(name: "CHORUS 1564", line: "home, five, six, four: the chorus of half the songbook", chords: [
            c(1), c(5, .sus4), c(6, .min7), c(4, .add9)]),
        Progression(name: "QUIET VERSE", line: "home and four, home and five: plain, with room to sing", chords: [
            c(1), c(4, .add9), c(1), c(5, .sus4)]),
        Progression(name: "LIFT", line: "four, home, five, six: it keeps rising and never quite lands", chords: [
            c(4, .add9), c(1), c(5), c(6, .min7)]),
        Progression(name: "DEEP WATER", line: "from the minor side: six, four, home, five", chords: [
            c(6, .min7), c(4, .add9), c(1), c(5, .sus4)]),
        Progression(name: "WALK UP", line: "the bass climbs a step at a time to the four", chords: [
            c(1), c(2, .min7), c(3, .min7), c(4, .add9)]),
        Progression(name: "WALK DOWN", line: "eight chords, the bass coming down the stairs and round again", chords: [
            c(1), c(5), c(6, .minor), c(5), c(4), c(1), c(2, .min7), c(5, .sus4)]),
        Progression(name: "BRIDGE BUILD", line: "eight chords that climb twice; the second time they hang on the five", chords: [
            c(4), c(5), c(6, .minor), c(1), c(4), c(5), c(6, .minor), c(5, .sus4)]),
        Progression(name: "HYMN", line: "eight chords, the way the old ones go", chords: [
            c(1), c(4), c(1), c(5), c(6, .minor), c(4), c(5, .sus4), c(1)]),
        Progression(name: "SELAH", line: "open chords for the quiet between songs", chords: [
            c(1, .sus2), c(4, .add9), c(6, .min7), c(4, .add9)]),
        Progression(name: "AMEN", line: "four, the four gone minor, home: the ending", chords: [
            c(4), c(4, .minor), c(1), c(1)]),
        Progression(name: "SLOW THREE", line: "two bars a chord, for a song in 6/8", chords: [
            c(1), c(1), c(6, .min7), c(6, .min7), c(4, .add9), c(4, .add9), c(5, .sus4), c(5)]),
        Progression(name: "LAMENT", line: "minor, and it stays there: six, home, five, four", chords: [
            c(6, .minor), c(1), c(5), c(4)]),
        Progression(name: "VERSE + CHORUS", line: "sixteen bars: a verse that waits, a chorus that opens", chords: [
            c(1), c(1), c(4, .add9), c(4, .add9), c(6, .min7), c(5, .sus4), c(4, .add9), c(4, .add9),
            c(1), c(5), c(6, .min7), c(4, .add9), c(1), c(5), c(6, .min7), c(4, .add9)],
            sections: ["VERSE", "CHORUS"]),
        Progression(name: "WHOLE SONG", line: "thirty-two bars: verse, chorus, a bridge that builds, the chorus home", chords: [
            c(1), c(1), c(4, .add9), c(4, .add9), c(6, .min7), c(5, .sus4), c(4, .add9), c(4, .add9),
            c(1), c(5), c(6, .min7), c(4, .add9), c(1), c(5), c(6, .min7), c(4, .add9),
            c(4), c(5), c(6, .minor), c(1), c(4), c(5), c(6, .minor), c(5, .sus4),
            c(1), c(5), c(6, .min7), c(4, .add9), c(1), c(5, .sus4), c(4, .add9), c(1)],
            sections: ["VERSE", "CHORUS", "BRIDGE", "CHORUS"]),
    ]

    // 5.7: the rest of the songbook, shelf by shelf. They come after the first fifty, whose
    // places sessions remember by number.
    private static func p(_ name: String, _ shelf: Int, _ line: String, _ chords: [NashChord]) -> Progression {
        Progression(name: name, line: line, chords: chords, shelf: shelf)
    }

    private static let more: [Progression] = [
        // ---- POP
        p("HOPEFUL", 0, "home, four, six, five: it looks up", [c(1), c(4), c(6, .minor), c(5)]),
        p("THREE CHORDS", 0, "one, four, five, four: every garage band", [c(1), c(4), c(5), c(4)]),
        p("UPLIFT", 0, "the two where the six would be: lighter", [c(1), c(5), c(2, .minor), c(4)]),
        p("TEENAGE", 0, "one, six, two, five: round and round", [c(1), c(6, .minor), c(2, .minor), c(5)]),
        p("CREEP", 0, "a major three, then the four turns minor", [c(1), c(3), c(4), c(4, .minor)]),
        p("CLIMB AND FALL", 0, "four, five, six, and back down to five", [c(4), c(5), c(6, .minor), c(5)]),
        p("SIX FOUR", 0, "two chords from the minor side", [c(6, .minor), c(4)]),
        p("OPEN ROAD", 0, "home, five, and the four held twice as long", [c(1), c(5), c(4), c(4)]),
        p("HEARTLAND", 0, "home and four, home and five: a song round a fire", [c(1), c(4), c(1), c(5)]),
        p("TURNING", 0, "two, five, one, six: the circle, pop size", [c(2, .minor), c(5), c(1), c(6, .minor)]),
        p("POWER BALLAD", 0, "eight chords: the four chords, then a lift that hangs on the five", [
            c(1), c(5), c(6, .minor), c(4), c(2, .minor), c(4), c(5, .sus4), c(5)]),
        // ---- J-POP · ANIME
        p("ROYAL SEVENTHS", 2, "the royal road with every seventh in", [c(4, .maj7), c(5, .dom7), c(3, .min7), c(6, .min7)]),
        p("SHONEN", 2, "minor, up through four and five, and home to the minor: the hero's theme", [
            c(6, .minor), c(4), c(5), c(6, .minor)]),
        p("KIRA KIRA", 2, "four, five, six, three: the road with its last two swapped", [c(4), c(5), c(6, .minor), c(3, .minor)]),
        p("SENTIMENTAL", 2, "two, five, three, six: every chord leans on the next", [c(2, .min7), c(5), c(3, .min7), c(6, .minor)]),
        p("LAST EPISODE", 2, "eight chords: the four goes minor, then the long way home", [
            c(4), c(4, .minor), c(3, .min7), c(6, .minor), c(2, .min7), c(5, .sus4), c(1), c(1)]),
        // ---- JAZZ · SOUL
        p("MINOR TWO FIVE", 3, "the cadence into the minor", [c(7, .dim), c(3, .dom7), c(6, .min7), c(6, .min7)]),
        p("AUTUMN", 3, "eight chords: the major two five one, then the minor one", [
            c(2, .min7), c(5, .dom7), c(1, .maj7), c(4, .maj7), c(7, .dim), c(3, .dom7), c(6, .min7), c(6, .min7)]),
        p("QUIET STORM", 3, "major and minor sevenths coming down the stairs", [c(4, .maj7), c(3, .min7), c(2, .min7), c(1, .maj7)]),
        p("SOUL CYCLE", 3, "three, six, two, five: fifths all the way", [c(3, .min7), c(6, .min7), c(2, .min7), c(5, .dom7)]),
        p("SOUL STEP", 3, "up two steps and back, on sevenths", [c(1, .maj7), c(2, .min7), c(3, .min7), c(2, .min7)]),
        // ---- LO-FI · R&B
        p("CHILL", 4, "the four, and two minor sevenths rocking under it", [c(4, .maj7), c(3, .min7), c(2, .min7), c(3, .min7)]),
        p("SLOW JAM", 4, "two, three, four, five: a slow walk up", [c(2, .min7), c(3, .min7), c(4, .maj7), c(5)]),
        p("RAINY", 4, "ninths all round: one, six, two, five", [c(1, .maj9), c(6, .min9), c(2, .min9), c(5, .dom9)]),
        p("LATE NIGHT", 4, "two ninths, the minor one first", [c(6, .min9), c(4, .maj9)]),
        p("NEO TURN", 4, "six, two, five, one in ninths", [c(6, .min9), c(2, .min9), c(5, .dom9), c(1, .maj9)]),
        // ---- EDM · FUTURE
        p("DROP", 5, "four, five, and the six held: built for a drop", [c(4), c(5), c(6, .minor), c(6, .minor)]),
        p("FUTURE BOUNCE", 5, "sevenths walking up to the five", [c(2, .min7), c(3, .min7), c(4, .maj7), c(5)]),
        p("HOUSE VAMP", 10, "two minor sevenths: all a house track needs", [c(6, .min7), c(2, .min7)]),
        p("RAVE", 11, "the minor held, then four and five", [c(6, .minor), c(6, .minor), c(4), c(5)]),
        p("TRANCE", 11, "six, four, five, three: it never lands", [c(6, .minor), c(4), c(5), c(3, .minor)]),
        p("COLOUR HOUSE", 10, "piano house in sevenths", [c(4, .maj7), c(5), c(6, .min7), c(3, .min7)]),
        // ---- ROCK · BLUES
        p("QUICK BLUES", 6, "the blues in four bars", [c(1, .dom7), c(4, .dom7), c(1, .dom7), c(5, .dom7)]),
        p("MINOR BLUES", 6, "twelve bars from the minor side", [
            c(6, .min7), c(6, .min7), c(6, .min7), c(6, .min7), c(2, .min7), c(2, .min7),
            c(6, .min7), c(6, .min7), c(4, .dom7), c(3, .dom7), c(6, .min7), c(3, .dom7)]),
        p("SWEET HOME", 6, "five, four, one: southern rock", [c(5), c(4), c(1), c(1)]),
        p("INDIE", 6, "home, three, and the four held", [c(1), c(3, .minor), c(4), c(4)]),
        p("HEAVY", 6, "the minor, then four and a five that stays", [c(6, .minor), c(4), c(5), c(5)]),
        p("ADVENTURE", 6, "home, five, a borrowed flat seven, four", [c(1), c(5), c(7, flat: true), c(4)]),
        // ---- CINEMATIC
        p("LYDIAN LIFT", 7, "home and a major two: wonder", [c(1), c(2), c(1), c(2)]),
        p("SAD STRINGS", 7, "six, three, four, home: it walks away slowly", [c(6, .minor), c(3, .minor), c(4), c(1)]),
        p("TIME", 7, "six, three, five, and a major two that opens the sky", [c(6, .minor), c(3, .minor), c(5), c(2)]),
        p("ELEGY", 7, "minor, falling, and a major three to turn it round", [c(6, .minor), c(4), c(2, .minor), c(3, .dom7)]),
        p("FAREWELL", 7, "eight chords: the road, then fifths all the way home", [
            c(4), c(5), c(3, .minor), c(6, .minor), c(2, .minor), c(5), c(1), c(1)]),
        // ---- DARK · MODAL
        p("DORIAN VAMP", 8, "a minor seventh and a major four: dorian", [c(6, .min7), c(2, .dom7)]),
        p("PHRYGIAN", 8, "the minor and the chord a half step above it", [c(6, .minor), c(7, flat: true)]),
        p("HARMONIC MINOR", 8, "one, four, five, one in the minor, with its major five", [c(6, .minor), c(2, .minor), c(3, .dom7), c(6, .minor)]),
        p("DARK TRAP", 8, "the minor held, a six, and a five that pulls back", [c(6, .minor), c(6, .minor), c(4), c(3, .dom7)]),
        p("MIXO VAMP", 8, "home and a flat seven", [c(1), c(7, flat: true)]),
        p("TWO MINORS", 8, "the minor and its minor five: no light at all", [c(6, .minor), c(3, .minor)]),
        p("MINOR PLAGAL", 8, "the minor and its four", [c(6, .minor), c(2, .minor)]),
        // ---- LATIN · WORLD
        p("BOSSA", 9, "home, a major two seventh, the two, the five", [c(1, .maj7), c(2, .dom7), c(2, .min7), c(5, .dom7)]),
        p("HIGHLIFE", 9, "one, four, five, one: bright and rolling", [c(1), c(4), c(5), c(1)]),
        p("GYPSY", 9, "fifths from the minor to the major", [c(6, .minor), c(2, .minor), c(5, .dom7), c(1, .maj7)]),
        p("WATCHTOWER", 9, "minor, down a step, down another, and back up", [c(6, .minor), c(5), c(4), c(5)]),

        // ---- EDM, shelf by shelf: FUTURE · EDM
        p("SHELTER", 5, "four, home, five, six in soft colours: it never quite lands", [c(4, .maj7), c(1, .add9), c(5, .sus4), c(6, .min7)]),
        p("FUTURE NINTHS", 5, "ninths that slide down and climb back", [c(4, .maj9), c(3, .min7), c(6, .min9), c(5)]),
        p("FUTURE FUNK", 5, "two five, then three six: disco, chopped", [c(2, .min9), c(5, .dom9), c(3, .min7), c(6, .min9)]),
        p("TROPICAL", 5, "minor, home, four, five: sun on it", [c(6, .minor), c(1), c(4), c(5)]),
        p("COLOUR BASS", 5, "add nines and a suspended five: every chord glows", [c(1, .add9), c(3, .min7), c(4, .add9), c(5, .sus4)]),
        p("MELODIC BASS", 5, "eight chords: the emotional four, the second time turning on a major three", [
            c(4), c(1), c(5), c(6, .minor), c(4), c(1), c(5), c(3, .dom7)]),
        // ---- HOUSE · TECHNO
        p("DEEP HOUSE", 10, "minor ninths and a major seventh, late at night", [c(6, .min9), c(4, .maj7), c(2, .min9), c(3, .min7)]),
        p("IBIZA", 10, "piano house: minor, down a step, the four, back up", [c(6, .min7), c(5), c(4, .maj7), c(5)]),
        p("DISCO LOOP", 10, "two, five, one, four: it turns for ever", [c(2, .min7), c(5, .dom7), c(1, .maj7), c(4, .maj7)]),
        p("FRENCH TOUCH", 10, "two, four, six, five: the filter-house loop", [c(2, .min7), c(4), c(6, .min7), c(5)]),
        p("PROGRESSIVE", 10, "four, six, home, five: progressive house", [c(4), c(6, .minor), c(1), c(5)]),
        p("AFRO HOUSE", 10, "the minor, its minor five, then six and seven", [c(6, .min7), c(3, .min7), c(4, .maj7), c(5)]),
        p("MELODIC TECHNO", 10, "minor all the way down: one, six, four, five of the minor", [c(6, .minor), c(4), c(2, .minor), c(3, .minor)]),
        p("2-STEP", 10, "garage: ninths coming down to a five", [c(4, .maj9), c(3, .min7), c(2, .min9), c(5, .dom9)]),
        p("LO-FI HOUSE", 10, "major sevenths that drift to the minor", [c(4, .maj7), c(1, .maj7), c(2, .min7), c(6, .min7)]),
        p("MINOR DRONE", 10, "one minor seventh and nothing else: techno sits here", [c(6, .min7)]),
        // ---- TRANCE · BIG ROOM
        p("UPLIFTING", 11, "eight chords: the anthem, and a two before the last five", [
            c(6, .minor), c(4), c(1), c(5), c(6, .minor), c(4), c(2, .minor), c(5)]),
        p("ASCEND", 11, "minor, seven, three, six of the minor: it keeps opening", [c(6, .minor), c(5), c(1), c(4)]),
        p("BIG ROOM", 11, "the minor, four, the minor, five: built for a kick", [c(6, .minor), c(4), c(6, .minor), c(5)]),
        p("HARDSTYLE", 11, "eight chords: the anthem, then a major three to slam back in", [
            c(6, .minor), c(4), c(1), c(5), c(6, .minor), c(4), c(5), c(3, .dom7)]),
        p("PSY", 11, "the minor for three bars, then the chord a half step above", [c(6, .minor), c(6, .minor), c(6, .minor), c(7, flat: true)]),
        p("SUNRISE", 11, "eight chords: the road, then four and five home, for the breakdown", [
            c(4), c(5), c(6, .minor), c(3, .minor), c(4), c(5), c(1), c(1)]),
        // ---- BASS · DNB
        p("LIQUID", 12, "liquid drum and bass: sevenths that roll", [c(6, .min7), c(4, .maj7), c(1, .maj7), c(3, .min7)]),
        p("JUNGLE", 12, "the minor, its four, the minor, its five", [c(6, .min7), c(2, .min7), c(6, .min7), c(3, .min7)]),
        p("DUBSTEP", 12, "the minor, four, the minor, three: dark and wide", [c(6, .minor), c(4), c(6, .minor), c(3, .minor)]),
        p("HALF STEP", 12, "the minor, a half step up, the minor, a step down", [c(6, .minor), c(7, flat: true), c(6, .minor), c(5)]),
        p("TRITONE BASS", 12, "the minor and the chord furthest from it", [c(6, .minor), c(3, flat: true)]),
        p("WAVE", 12, "a minor seventh, a major seventh, and a five that hangs", [c(6, .min7), c(4, .maj7), c(5), c(5)]),
        p("FUTURE GARAGE", 12, "a minor ninth, home, and the four held", [c(6, .min9), c(1, .maj7), c(4, .maj9), c(4, .maj9)]),
    ]

    /// Progressions that belong on more shelves than their own: the four chords are a pop
    /// song and a trance anthem. They are listed there too, once each in the library.
    private static let alsoOn: [String: [Int]] = [
        "EPIC": [5, 10, 11], "AXIS": [5], "EMOTION": [5], "RISE": [5], "ROYAL ROAD": [5], "ROYAL SEVENTHS": [5],
        "KAWAII": [5], "CLIMB AND FALL": [5], "KOMURO": [11], "SHONEN": [11], "LAMENT": [11], "WATCHTOWER": [11],
        "HEAVY": [11], "MINOR EPIC": [11], "SIX FOUR": [10, 11, 12], "VAMP": [10], "DREAM VAMP": [10],
        "DORIAN VAMP": [10], "MINOR PLAGAL": [10], "LATE NIGHT": [10], "NEO TURN": [10], "PHRYGIAN": [10, 12],
        "DARK TRAP": [12], "TWO MINORS": [12], "ELEGY": [12], "HARMONIC MINOR": [12], "RAVE": [12], "DROP": [11],
    ]

    /// Is this progression on that shelf (its own, or one it is also listed on)?
    public static func onShelf(_ pr: Progression, _ shelf: Int) -> Bool {
        pr.shelf == shelf || alsoOn[pr.name]?.contains(shelf) == true
    }

    public static let shelves = ["POP", "WORSHIP", "J-POP · ANIME", "JAZZ · SOUL", "LO-FI · R&B", "FUTURE · EDM",
                          "ROCK · BLUES", "CINEMATIC", "DARK · MODAL", "LATIN · WORLD",
                          "HOUSE · TECHNO", "TRANCE · BIG ROOM", "BASS · DNB"]
    /// The order the shelves are shown in: the four electronic ones side by side.
    public static let shelfOrder = [0, 1, 2, 3, 4, 5, 10, 11, 12, 6, 7, 8, 9]

    /// Where each of the first fifty sits (the newer ones say so themselves).
    private static let firstShelves: [String: Int] = [
        "ROYAL ROAD": 2, "KOMURO": 2, "CITY POP": 2, "MARUSA": 2, "ANIME CHORUS": 2, "ROAD HOME": 2, "KAWAII": 2,
        "TWO FIVE ONE": 3, "GOSPEL": 3, "JAZZ TURN": 3, "TRITONE": 3, "BACKDOOR": 3,
        "LO-FI": 4, "NEO SOUL": 4, "DREAM VAMP": 4,
        "FUTURE BASS": 5, "EUROBEAT": 11,
        "MIXO": 6, "BLUES": 6, "SHOEGAZE": 6,
        "SPACE CADENCE": 7, "MINOR EPIC": 7, "CINEMA": 7,
        "ANDALUSIAN": 9,
    ]

    /// The whole library: the first fifty in the places they have always had, then the rest.
    public static let all: [Progression] = first.enumerated().map { i, pr in
        var q = pr
        q.shelf = i >= first.count - worshipCount || pr.name == "SUNDAY" ? 1 : (firstShelves[pr.name] ?? 0)
        return q
    } + more

    public static func named(_ name: String) -> Progression? { all.first { $0.name == name } }
    public static func index(named name: String) -> Int? { all.firstIndex { $0.name == name } }

    /// The worship shelf.
    public static let worshipCount = 14
    public static var worship: [Int] { all.indices.filter { all[$0].shelf == 1 } }

    /// NUMBERS: what each of the twelve keys of an octave plays, counted from C.
    /// The white keys are 1 2m 3m 4 5 6m 7°; the black keys the flats between
    /// them, as major chords (♭3, ♭6 and ♭7 are the ones songs borrow).
    public static let keyChords: [NashChord] = [
        c(1), c(2, flat: true), c(2, .minor), c(3, flat: true), c(3, .minor), c(4),
        c(5, flat: true), c(5), c(6, flat: true), c(6, .minor), c(7, flat: true), c(7, .dim),
    ]
    /// 1 2m 3m 4 5 6m 7°
    public static let diatonic: [NashChord] = [0, 2, 4, 5, 7, 9, 11].map { keyChords[$0] }
}

// VARY: the progression as written at 0; turned up, each chord may come out
// richer (a seventh, a ninth), as a stand-in that does the same job (6m for
// 1, 2m7 for 4, 3m for 5), borrowed from the minor (4 goes 4m), with a
// tritone for a dominant, or suspended. Rolled again every time the chord
// comes round, so the same progression never plays twice the same way.
public enum ChordVary {
    public static func vary(_ c: NashChord, amount: Float, _ dice: () -> Float = { Float.random(in: 0..<1) }) -> NashChord {
        let a = max(0, min(1, amount))
        guard a > 0.001 else { return c }
        func roll(_ p: Float) -> Bool { dice() < p }
        var out = c
        if !c.flat && roll(0.32 * a) {
            // a stand-in from the same family
            switch (c.degree, c.quality) {
            case (1, .major), (1, .maj7), (1, .add9): out = roll(0.5) ? NashChord(6, .min7) : NashChord(3, .min7)
            case (4, _) where c.quality != .minor && c.quality != .min7: out = NashChord(2, .min7)
            case (5, .major), (5, .dom7), (5, .sus4): out = roll(0.6) ? NashChord(3, .min7) : NashChord(7, .dim)
            case (6, .minor), (6, .min7): out = roll(0.5) ? NashChord(1, .maj7) : NashChord(4, .maj7)
            case (2, .minor), (2, .min7): out = NashChord(4, .add9)
            case (3, .minor), (3, .min7): out = roll(0.5) ? NashChord(1, .maj7) : NashChord(5)
            default: break
            }
        } else if !c.flat && roll(0.16 * a) {
            // borrowed from the minor
            switch c.degree {
            case 4: out = NashChord(4, .minor)
            case 1: out = roll(0.5) ? NashChord(6, flat: true) : NashChord(7, flat: true)
            case 5: out = NashChord(5, .min7)
            default: break
            }
        }
        // a dominant may slide in from a tritone away
        if out.quality == .dom7 && !out.flat && roll(0.4 * a) {
            if out.degree == 5 { out = NashChord(2, .dom7, flat: true) } else if out.degree == 1 { out = NashChord(5, .dom7, flat: true) }
        }
        // colour: sevenths and ninths, or a suspension
        if roll(0.7 * a) {
            switch out.quality {
            case .major: out.quality = roll(0.5) ? .maj7 : .add9
            case .minor: out.quality = roll(0.6) ? .min7 : .min9
            case .min7: if roll(0.5) { out.quality = .min9 }
            case .maj7: if roll(0.5) { out.quality = .maj9 }
            case .dom7: if roll(0.5) { out.quality = .dom9 }
            default: break
            }
            // the seventh of a 5 is a dominant, not a major seventh
            if out.degree == 5 && !out.flat && (out.quality == .maj7 || out.quality == .maj9) { out.quality = .dom7 }
        } else if (out.quality == .major || out.quality == .dom7) && roll(0.16 * a) {
            out.quality = roll(0.5) ? .sus4 : .sus2
        }
        return out
    }
}


// The same progression, another way: every variation is one rule applied to the whole run,
// so a section can be re-dressed in a tap and still be the song it was. `lens` are the
// chords' lengths in half bars (2 = a bar).
public enum ProgVariant: Int, CaseIterable, Sendable {
    case written, sevenths, open, suspended, borrowed, passing, turnaround, slow, fast, rotate, mirror

    public var label: String {
        ["AS WRITTEN", "SEVENTHS", "OPEN", "SUSPENDED", "BORROWED", "PASSING", "TURNAROUND",
         "TWICE AS SLOW", "TWICE AS FAST", "ROTATE", "MIRROR"][rawValue]
    }

    /// The dominant seventh that leads to a chord (the five of it), written from the song's key.
    private static func leading(to c: NashChord) -> NashChord? {
        guard !c.flat else { return nil }
        switch c.degree {
        case 6: return NashChord(3, .dom7)
        case 2: return NashChord(6, .dom7)
        case 4: return NashChord(1, .dom7)
        case 5: return NashChord(2, .dom7)
        case 3: return NashChord(7, .dom7)
        default: return nil
        }
    }

    public func apply(_ chords: [NashChord], lens given: [Int] = []) -> (chords: [NashChord], lens: [Int]) {
        var cs = chords
        var ls = given.count == chords.count ? given : [Int](repeating: 2, count: chords.count)
        guard !cs.isEmpty else { return (cs, ls) }
        switch self {
        case .written:
            break
        case .sevenths:
            cs = cs.map { c in
                var o = c
                switch c.quality {
                case .major: o.quality = !c.flat && c.degree == 5 ? .dom7 : .maj7
                case .minor: o.quality = .min7
                default: break
                }
                return o
            }
        case .open:
            cs = cs.map { c in
                var o = c
                switch c.quality {
                case .major: o.quality = !c.flat && c.degree == 5 ? .sus4 : .add9
                case .minor: o.quality = .min7
                default: break
                }
                return o
            }
        case .suspended:
            cs = cs.map { c in
                var o = c
                if c.quality == .major || c.quality == .dom7 { o.quality = !c.flat && c.degree == 5 ? .sus4 : .sus2 }
                return o
            }
        case .borrowed:
            // the last four goes minor; a five that leads home becomes the flat seven
            if let i = cs.lastIndex(where: { $0.degree == 4 && !$0.flat && ($0.quality == .major || $0.quality == .maj7 || $0.quality == .add9) }) {
                cs[i].quality = cs[i].quality == .maj7 ? .min7 : .minor
            } else if let i = cs.lastIndex(where: { $0.degree == 5 && !$0.flat }) {
                cs[i] = NashChord(7, flat: true)
            } else if let i = cs.lastIndex(where: { $0.degree == 1 && !$0.flat }) {
                cs[i] = NashChord(6, flat: true)
            }
        case .passing:
            // the second half of a bar leans into the next chord (its own five)
            var outC: [NashChord] = [], outL: [Int] = []
            for i in cs.indices {
                let next = cs[(i + 1) % cs.count]
                if ls[i] >= 2, next != cs[i], let lead = Self.leading(to: next), lead != cs[i] {
                    outC.append(cs[i]); outL.append(ls[i] - 1)
                    outC.append(lead); outL.append(1)
                } else {
                    outC.append(cs[i]); outL.append(ls[i])
                }
            }
            cs = outC; ls = outL
        case .turnaround:
            // the last bar ends on the five, so the run wants to start again
            let i = cs.count - 1
            if cs[i].degree == 5 && !cs[i].flat {
                cs[i].quality = .dom7
            } else if ls[i] >= 2 {
                ls[i] -= 1
                cs.append(NashChord(5, .dom7)); ls.append(1)
            } else {
                cs[i] = NashChord(5, .dom7)
            }
        case .slow:
            ls = ls.map { min(8, $0 * 2) }
        case .fast:
            ls = ls.map { max(1, $0 / 2) }
        case .rotate:
            cs = Array(cs.dropFirst()) + [cs[0]]
            ls = Array(ls.dropFirst()) + [ls[0]]
        case .mirror:
            cs.reverse(); ls.reverse()
        }
        return (cs, ls)
    }
}
