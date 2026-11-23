import OPZModel

/// What the screens show: the OP-Z as the app knows it.
public struct StageInput: Sendable {
    public enum Link: Equatable, Sendable { case searching, hello, loading(Int), live, lost }

    public var link = Link.searching
    /// Under the name while there is no OP-Z.
    public var linkLine = "LOOKING FOR YOUR OP-Z"
    public var linkHint = ""
    /// USB, BLUETOOTH, DEMO
    public var linkName = ""
    public var bank: Bank?
    /// Changes whenever the bank does.
    public var revision = 0
    public var address: PatternAddress?
    public var tempo: Int?
    public var swing: Int?
    public var panel = PanelState()
    /// The tumbler and EUCLID: nil if the OP-Z's OS does not tell of them.
    public var machines: Machines?
    public var sounds = [Sound?](repeating: nil, count: 16)
    public var slots = [Int?](repeating: nil, count: 16)
    public var load: LoadReport?
    /// Its red page (v11).
    public var red: RedPage?
    /// The OP-Z's MIDI settings, when it has said them.
    public var midi: MIDISettings?
    /// What the hub wants to say in the corner (a new Galax-z OS).
    public var notice: String?
    /// Where the OP-Z is heard, if that can be chosen now.
    public var out: String?

    public init() {}
}

/// The pattern on screen, laid out once per change so drawing it allocates nothing.
struct PatternGrid {
    struct Cell {
        var velocity: UInt8 = 0        // of the loudest note; 0: none
        var notes: UInt8 = 0
        var low: UInt8 = 0, high: UInt8 = 0
        var component = false, lock = false
    }

    var cells = [Cell](repeating: Cell(), count: 256)
    var lengths = [Int](repeating: 16, count: 16)
    var tracks = [Playhead.Track](repeating: .init(), count: 16)
    /// Its notes do not play, or its sound is off: nothing of it is heard.
    var muted = [Bool](repeating: false, count: 16)
    var audioMuted = [Bool](repeating: false, count: 16)
    var sound = [[Double]](repeating: [Double](repeating: 0, count: 18), count: 16)
    var noteCount = [Int](repeating: 0, count: 16)
    var notes = [[(step: Int, note: Note)]](repeating: [], count: 16)

    init() {}

    init(_ bank: Bank, _ p: Int) {
        for t in 0..<16 {
            tracks[t] = Playhead.Track(record: bank.track(p, t))
            lengths[t] = tracks[t].count
            audioMuted[t] = bank.audioMuted(p, t)
            muted[t] = bank.muted(p, t) || audioMuted[t]
            sound[t] = bank.sound(p, t).map { Double($0) / 255 }
            for s in 0..<16 {
                let b = bank.brief(p, t, s)
                cells[t * 16 + s] = Cell(velocity: UInt8(clamping: b.velocity), notes: UInt8(min(b.notes, 8)), low: UInt8(clamping: b.low),
                                         high: UInt8(clamping: b.high), component: b.component, lock: b.lock)
                guard b.notes > 0 else { continue }
                noteCount[t] += b.notes
                for n in bank.notes(p, t, s) { notes[t].append((s, n)) }
            }
        }
    }

    @inline(__always) subscript(_ t: Int, _ s: Int) -> Cell { cells[t &* 16 &+ s] }
}
