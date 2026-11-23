/// What the OP-Z's own panel is doing, as it tells a StateSync replica while it changes (`$03 $04 $05 $06 $12 $13`).
/// Layouts read in the OS's own getters and setters (1.2.45: 0x80108a48, 0x80108f74, 0x80107a44, 0x80107a08).
public struct PanelState: Equatable, Sendable {
    /// `$03`: the selected track, whether it plays, the track's octave byte.
    public var track: Int?
    public var playing = false
    public var octave = 0
    /// `$05`, at a start and once a pattern: where every track is (the step in bits 4–7, the sixteenths within it below) and the
    /// pattern's own sixteenth; `told` counts how often. `Playhead` counts on from it.
    public var positions = [UInt8](repeating: 0, count: 16)
    public var step = 0
    public var told = 0
    /// `$06`: the parameter page (0–3, as SHIFT turns them; Galax-z OS's fifth and sixth read as 0 and 1), the step held (nil: none), SHIFT, recording.
    public var page = 0
    public var heldStep: Int?
    public var shift = false
    public var recording = false
    /// Keys held down: SCREEN, TRACK, PROJECT, MIXER, TEMPO (`$06`; read in the OS, op-free's names).
    public var screen = false, trackKey = false, projectKey = false, mixerKey = false, tempoKey = false
    /// `$12`: the mixer's 16 bytes.
    public var levels: [UInt8]?

    public init() {}

    /// Take a message's payload in; false if it is not one of these or has the wrong size.
    public mutating func receive(_ id: UInt8, _ p: [UInt8]) -> Bool {
        switch id {
        case 0x03 where p.count == 2:
            track = Int(p[1] & 0x0F)
            playing = p[1] & 0x10 != 0
            octave = Int(Int8(bitPattern: p[0]))
        case 0x05 where p.count == 17:
            positions = Array(p[..<16])
            step = Int(p[16] & 0x0F)
            told &+= 1
        case 0x06 where p.count == 4:
            page = Int(p[0] >> 6)
            let held = p[1] & 0x1F
            heldStep = held < 16 ? Int(held) : nil
            shift = p[1] & 0x20 != 0
            recording = p[2] & 0x80 != 0
            (tempoKey, mixerKey, screen) = (p[1] & 0x40 != 0, p[1] & 0x80 != 0, p[2] & 0x20 != 0)
            (trackKey, projectKey) = (p[3] & 1 != 0, p[3] & 2 != 0)
        case 0x12 where p.count == 18:
            levels = Array(p[..<16])
        default:
            return false
        }
        return true
    }
}
