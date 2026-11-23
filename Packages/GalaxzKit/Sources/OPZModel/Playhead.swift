/// Where every track is while the OP-Z plays.
///
/// The OP-Z says so (`$05`) when it starts and once each time its pattern comes round, not at every step (OS 1.2.45: the flag is set
/// at 0x80107ec8 and 0x801109f8 only). Between, a replica counts for itself, as the OS does (0x8010a5a4): every sixteenth a track's
/// count within its step goes up, and after its step length the track goes to its next step. The counting follows the OP-Z's MIDI
/// clock if it sends it (6 ticks a sixteenth), and the tempo if not.
public struct Playhead: Equatable, Sendable {
    /// A track's steps and how many sixteenths each lasts.
    public struct Track: Equatable, Sendable {
        public var count, length: Int
        public init(count: Int = 16, length: Int = 1) { (self.count, self.length) = (count, length) }
        /// From a track record: step length 0 and 10 last one sixteenth, 9 lasts sixteen.
        public init(record: TrackRecord) {
            count = max(1, min(16, record.stepCount))
            length = switch record.stepLength { case 0, 10: 1; case 9: 16; default: record.stepLength }
        }
    }

    public private(set) var playing = false
    /// The step each track is on, and the pattern's own sixteenth.
    public private(set) var steps = [UInt8](repeating: 0, count: 16)
    public private(set) var step = 0
    /// Counts each track's steps as they begin: a track of one step never changes its step, and still begins it.
    public private(set) var begun = [Int](repeating: 0, count: 16)

    private var on = [Int](repeating: 0, count: 16)          // steps since it was told
    private var from = [UInt8](repeating: 0, count: 16)      // as the OP-Z last said: step in bits 4–7, count within it below
    private var fromStep = 0
    private var since = 0.0                                   // when, and ticks since
    private var ticks = 0
    private var lastTick = -Double.infinity
    private var lateness: [Double] = []                       // of the last `$05`s behind the count, in seconds
    private var pace = 0                                      // the tempo the count goes by
    /// Ticks stop counting as a clock after this long without one.
    static let clockLost = 0.6

    public init() {}

    /// Playing or not, as `$03` or a MIDI start or stop says.
    public mutating func play(_ on: Bool, at now: Double) {
        guard on != playing else { return }
        playing = on
        lateness = []
        if on { told([UInt8](repeating: 0, count: 16), step: 0, at: now) }
    }

    /// How long a sixteenth is.
    private var sixteenth: Double { 15 / Double(max(1, pace)) }

    /// `$05` while the count goes on. A message only ever comes late, and this one waits for the OP-Z's own loop, so one that fits the
    /// count does not hold it back: only what they are all late by at the least (the count was really early) is taken. One that does
    /// not fit says where the OP-Z is.
    public mutating func heardPosition(_ positions: [UInt8], step s: Int, at now: Double) {
        guard playing, pace > 0, positions.count == 16, now - lastTick >= Self.clockLost else { return told(positions, step: s, at: now) }
        var ahead = (now - since) / sixteenth + Double(fromStep - (s & 15))
        ahead -= (ahead / 16).rounded() * 16
        guard ahead > -0.5, ahead < min(0.75, 0.09 / sixteenth) else { lateness = []; return told(positions, step: s, at: now) }
        lateness.append(ahead * sixteenth)
        if lateness.count > 6 { lateness.removeFirst() }
        // early: at once. Late: by what the quickest of them shows, when there are enough to tell
        let least = lateness.min()!, back = ahead < 0 ? ahead * sixteenth : lateness.count == 6 && least > Self.quickest ? (least - Self.quickest) * 0.5 : 0
        if back > 0 { lateness = lateness.map { $0 - back } }
        let start = now - ahead * sixteenth + back
        told(positions, step: s, at: start)
        if back < 0 { lateness = [] }
    }
    /// The least a `$05` takes to come.
    static let quickest = 0.012

    /// A note of the OP-Z's own that starts a step was heard: `early` seconds before the count had it. A note cannot come before it
    /// sounds, so the count was behind.
    public mutating func hurry(_ early: Double) {
        guard playing, early > 0, early < 0.5 * sixteenth else { return }
        since -= early
        lateness = lateness.map { $0 + early }
    }

    /// How far the pattern is, in sixteenths; nil while it does not play or its tempo is not known.
    public func place(_ now: Double) -> Double? {
        guard playing, pace > 0 else { return nil }
        if now - lastTick < Self.clockLost { return Double(fromStep) + Double(ticks) / 6 }
        return Double(fromStep) + (now - since) / sixteenth
    }

    /// Until the next sixteenth begins, by the count.
    public func untilNext(_ now: Double) -> Double? {
        guard playing, pace > 0, now - lastTick >= Self.clockLost else { return nil }
        let x = (now - since) / sixteenth
        return (x.rounded(.down) + 1 - x) * sixteenth
    }

    /// `$05`: where the tracks are.
    public mutating func told(_ positions: [UInt8], step s: Int, at now: Double) {
        guard positions.count == 16 else { return }
        from = positions
        fromStep = s & 15
        since = now
        ticks = 0
        for t in 0..<16 { steps[t] = positions[t] >> 4; on[t] = 0; begun[t] &+= 1 }
        step = fromStep
    }

    /// A tick of the OP-Z's MIDI clock.
    public mutating func tick(at now: Double) {
        lastTick = now
        ticks += 1
    }

    /// Count on to now; true if a step changed.
    public mutating func advance(to now: Double, tempo: Int, tracks: [Track]) -> Bool {
        guard playing, tracks.count == 16 else { return false }
        let tempo = max(1, min(999, tempo))
        if tempo != pace {                                      // from here on at the new tempo, not as if it had always been
            if pace > 0, now > since, now - since < 1e5 { since = now - (now - since) * Double(pace) / Double(tempo) }
            pace = tempo
        }
        let n: Int
        if now - lastTick < Self.clockLost { n = ticks / 6 } else { n = max(0, Int(min(1e6, (now - since) * Double(tempo) / 15))) }
        var changed = false
        for t in 0..<16 {
            let length = max(1, tracks[t].length), count = max(1, tracks[t].count)
            let inner = Int(from[t] & 15) + n
            let s = UInt8((Int(from[t] >> 4) + inner / length) % count)
            if inner / length != on[t] { on[t] = inner / length; begun[t] &+= 1; changed = true }
            if s != steps[t] { steps[t] = s; changed = true }
        }
        let s = (fromStep + n) % 16
        if s != step { step = s; changed = true }
        return changed
    }
}
