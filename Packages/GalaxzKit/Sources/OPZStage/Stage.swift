import DotKit
import OPZModel
import OPZPlay

/// The screen: what is known of the OP-Z, what moves, and the pages that draw it. Give it the input when it changes and a
/// canvas when a picture is due. All on one thread.
public final class Stage {
    public enum Page: Int, CaseIterable, Sendable {
        case track, grid, mix, play, chops, perform, fx, song, notes, load, sky
        public var name: String { ["TRACK", "GRID", "MIX", "PLAY", "CHOPS", "PERFORM", "FX", "SONG", "NOTES", "LOAD", "SKY"][rawValue] }
    }

    /// What a touch asks the app for.
    public enum Action: Equatable, Sendable { case none, hub, settings, pair, sound }

    public var input = StageInput() { didSet { changed(from: oldValue) } }
    public var page = Page.track { didSet { if page != oldValue { turned = 0 } } }
    /// Show the track selected on the OP-Z. Choosing one here lets go until one is chosen there.
    public private(set) var track = 0
    public var showsPairing = false

    // what moves
    var time = 0.0
    var turned = 1.0                               // seconds since the page turned
    var hitFlashes = [Flash](repeating: Flash(life: 0.16), count: 16)
    var levels = [Flash](repeating: Flash(life: 0.55), count: 16)
    var lastNote = [Int](repeating: 60, count: 16)
    var lastVelocity = [Double](repeating: 0, count: 16)
    var strikes: [[Double]] = [[Double]](repeating: [], count: 16)      // when, newest last
    var pulse = Flash(life: 0.18)
    var knobs = [[Spring]](repeating: [Spring](repeating: Spring(0, stiffness: 320, damping: 30), count: 18), count: 16)
    var tabX = Spring(0, stiffness: 420, damping: 34)
    var trackY = Spring(0, stiffness: 420, damping: 34)
    var linkFade = Spring(0, stiffness: 60, damping: 16)
    var trail = Trail()
    var sky = Sky()
    var field = Field()
    var loads: [Double] = []                       // the meter's means, for a history
    var tombola = Tombola()
    private var ballOff: [(x: Double, y: Double)] = []
    var ballTrail: [[Machines.Ball]] = []               // where the balls were
    private var trailAt = 0.0, ballsAt = -10.0
    var machineDials = [Spring](repeating: Spring(0, stiffness: 320, damping: 30), count: 12)
    var grid = PatternGrid()
    var thumbnails = Thumbnails()
    private var gridRevision = -1
    private var gridAddress: PatternAddress?
    private var lastSteps = [Int](repeating: -1, count: 16)
    private var lastBegun = [Int](repeating: -1, count: 16)
    private var lastBeat = -1
    public private(set) var playhead = Playhead()
    /// What struck each track, for the link check.
    enum Striker: Int, CaseIterable { case midi, pattern, euclid, tumbler }
    private var struck = [[Int]](repeating: [Int](repeating: 0, count: Striker.allCases.count), count: 16)
    private var foretold = [Double](repeating: -10, count: 16)      // when the pattern struck a track, until the OP-Z's note of it comes
    private var midiHeard = [Double](repeating: -10, count: 16)     // when the OP-Z last sent a note of a track itself
    var touches: [(DotRect, Touch)] = []
    enum Touch { case page(Page), track(Int), action(Action), grip(Grip) }

    // what is played and held here
    /// Where what is played here goes, each at its time.
    public var out: (Player.Event) -> Void = { _ in }
    /// What is chosen on PLAY and loaded on PERFORM changed: keep it.
    public var kept: () -> Void = {}
    public var player = Player()
    public var bay = PerformBay()
    var performer = Performer()
    /// The chops, as they are, and what is asked of them.
    public var chops = ChopDesk()
    public var ask: (ChopAsk) -> Void = { _ in }
    /// LIGHTS' notes begin the moves of PERFORM.
    public var lights = false
    var grips: [Int: Held] = [:]
    var gains = [Double?](repeating: nil, count: 16)
    var octave = 0, pad = 0, gallery = false, latch = false, shelf = 0
    private var grooved = -1, jog = 0.0

    /// How lit each track is by what it plays.
    public var hits: [Double] { hitFlashes.map(\.level) }

    /// What the pages need to be laid out.
    static let smallest = (w: 180, h: 140)

    /// The time frames are drawn by, for what comes while none are (a still or covered screen).
    public var clock: () -> Double = { 0 }
    /// Now, by the clock: a frame is drawn for a little later.
    var moment: Double { let t = clock(); return t > 0 ? t : time }
    func wake() { time = max(time, clock()) }

    public init() {}

    // MARK: in

    private func changed(from old: StageInput) {
        wake()
        if input.revision != gridRevision || input.address != gridAddress {
            let same = input.address == gridAddress, was = grid.sound[track]
            gridRevision = input.revision
            gridAddress = input.address
            defer { if same, input.panel.screen { jogged(was) } }
            grid = input.bank.map { PatternGrid($0, input.address?.pattern ?? 0) } ?? PatternGrid()
            for t in 0..<16 { for k in 0..<18 { knobs[t][k].target = grid.sound[t][k] } }
        }
        if !input.panel.screen { jog = 0 }
        if input.panel.levels != old.panel.levels { gains = [Double?](repeating: nil, count: 16) }
        if input.panel.track != old.panel.track, let t = input.panel.track { select(track: t) }
        if input.panel.playing != old.panel.playing { play(input.panel.playing) }
        if input.panel.told != old.panel.told {
            playhead.heardPosition(input.panel.positions, step: input.panel.step, at: time)
            stepped()
        }
        if input.machines != old.machines {
            if input.machines?.track != old.machines?.track || input.machines == nil { tombola = Tombola(); ballTrail = []; ballOff = [] }
            if let m = input.machines {
                if m.told != old.machines?.told || m.balls.isEmpty {
                    // where each is drawn now stays, and goes over to where it is (a bounce off a scatter was another way than thought)
                    let drawn = tombola.balls.indices.map { (tombola.balls[$0].x + ballOff[$0].x, tombola.balls[$0].y + ballOff[$0].y) }
                    // a bounce of its own (1 at once, gone in 0.2 s; two balls meeting make 0.6 and no note) that was not seen here
                    for (i, b) in m.balls.enumerated() where b.flash > 0.65 && m.track < 8 {
                        if !tombola.balls.indices.contains(i) || tombola.balls[i].flash < 0.3 { machineStruck(m.track, b.note, 0.8, by: .tumbler) }
                    }
                    ballOff = m.balls.indices.map { i in
                        guard drawn.count == m.balls.count, tombola.balls[i].note == m.balls[i].note else { return (0, 0) }
                        let dx = drawn[i].0 - m.balls[i].x, dy = drawn[i].1 - m.balls[i].y
                        return dx * dx + dy * dy < 0.16 ? (dx, dy) : (0, 0)
                    }
                    tombola.balls = m.balls
                    tombola.turn = m.turn
                    ballsAt = time
                }
                for k in 0..<12 { machineDials[k].target = m.turned(k) }
                if let o = old.machines, o.track == m.track { pulsed(m, after: o) }
            }
        }
        if let l = input.load, l != old.load {
            loads.append(Double(l.instrumentsTop) / Double(LoadReport.line))
            if loads.count > 48 { loads.removeFirst() }
            page = .load
        }
    }

    private func play(_ on: Bool, at: Double? = nil) {
        guard on != playhead.playing else { return }
        playhead.play(on, at: at.map { min(time, max($0, time - 0.2)) } ?? time)
        midiHeard = [Double](repeating: -10, count: 16)
        lastSteps = [Int](repeating: -1, count: 16)
        lastBeat = -1
        if on { stepped() }
    }

    /// MIDI start and stop, and the clock, from the OP-Z.
    public func midi(playing on: Bool, at: Double? = nil) { wake(); play(on, at: at) }
    public func midiClock(at: Double? = nil) { wake(); playhead.tick(at: at ?? time); count() }

    /// Count the playhead on.
    private func count() {
        if playhead.advance(to: time, tempo: input.tempo ?? 120, tracks: grid.tracks) { stepped() }
    }

    /// Where the tracks are now: what their pattern has there sounds.
    private func stepped() {
        guard playhead.playing else { return }
        if playhead.step != lastBeat {
            lastBeat = playhead.step
            if lastBeat % 4 == 0 { pulse.hit(lastBeat == 0 ? 1 : 0.6) }
        }
        for t in 0..<16 {
            let s = Int(playhead.steps[t])
            let stepSeconds = 15.0 / Double(max(30, input.tempo ?? 120)), one = grid.tracks[t].count == 1
            guard s != lastSteps[t] || (one && playhead.begun[t] != lastBegun[t]) else { continue }
            // a track of one step: told of a start it was just counted to
            let again = one && s == lastSteps[t] && time - (strikes[t].last ?? -10) < 0.5 * stepSeconds * Double(grid.tracks[t].length)
            lastSteps[t] = s
            lastBegun[t] = playhead.begun[t]
            guard !again, !grid.muted[t], s < 16 else { continue }
            // A note on its step is struck as the count gets there, before the OP-Z's message can have come. What only the OP-Z knows
            // (a step component's chance, a note off its step) waits for the message, if this track's come.
            let told = time - midiHeard[t] < 8, swung = s & 1 == 1 && abs((input.swing ?? 127) - 127) > 2
            for (step, n) in grid.notes[t] where step == s {
                if told, swung || grid.cells[t * 16 + s].component || abs(n.micro) > 12 { continue }
                guard time - (strikes[t].last ?? -10) > 0.05 || lastNote[t] != n.note else { continue }
                sounded(t, n.note, Double(n.velocity) / 127, for: Double(n.duration) / 6200 * stepSeconds * Double(grid.tracks[t].length), by: .pattern)
                foretold[t] = time
            }
        }
    }

    /// EUCLID's steps since the last telling: what it plays of the selected track goes by no pattern and no MIDI. The OS's own rule
    /// (`Firmware/pages/pages.c`, euclid_step), but for CHANCE, which only the OP-Z knows: the less likely, the less it shows.
    private func pulsed(_ m: Machines, after o: Machines) {
        guard m.track < 8, !m.rings.isEmpty, !m.waiting, m.dials[10] > 0, o.waiting || m.steps != o.steps else { return }
        let first = !o.waiting && m.steps > o.steps && m.steps - o.steps < 4 ? o.steps + 1 : m.steps
        let chance = m.dials[10] >= 254 ? 1 : Double(m.dials[10]) / 255
        for at in first...m.steps {
            if m.track < 4 {
                for r in m.rings where Machines.isPulse(at % r.steps, r.steps, r.pulses, r.rotation) {
                    let v = at % r.steps == 0 ? 109 + ((m.dials[9] * 18) >> 8) : 109 - ((m.dials[9] * 51) >> 8)
                    machineStruck(m.track, r.key, Double(v) / 127 * chance, by: .euclid)
                }
            } else {
                let r = m.ring, i = at % r.steps
                guard Machines.isPulse(i, r.steps, r.pulses, r.rotation) else { continue }
                let before = at / r.steps * r.pulses + (0..<i).filter { Machines.isPulse($0, r.steps, r.pulses, r.rotation) }.count
                machineStruck(m.track, m.rings[before % m.rings.count].key, (i == 0 ? 0.95 : 0.8) * chance, by: .euclid)
            }
        }
    }

    /// By a machine: not again if the OP-Z said so too.
    private func machineStruck(_ t: Int, _ note: Int, _ velocity: Double, by what: Striker) {
        guard !grid.muted[t], time - (strikes[t].last ?? -10) > 0.06 else { return }
        sounded(t, note, velocity, for: 0.15, by: what)
    }

    /// Each of the first eight tracks in a line, for the link check.
    public var report: [String] {
        (0..<8).map { t in
            let k = VisualKind(track: t, sound: input.sounds[t]), n = struck[t]
            return "\(t + 1) \(OPZ.trackNames[t]): \(input.sounds[t]?.name ?? "no sound") (\(k)), \(grid.noteCount[t]) notes, \(grid.tracks[t].count) steps of \(grid.tracks[t].length)"
                + (grid.audioMuted[t] ? ", audio mute" : grid.muted[t] ? ", mute" : "")
                + "; struck by MIDI \(n[0]), pattern \(n[1]), EUCLID \(n[2]), tumbler \(n[3])"
        }
    }

    /// A note the OP-Z sent over MIDI (channel 0–15 is the track, as it is set from the factory).
    public func noteOn(channel: Int, note: Int, velocity: Int, at: Double? = nil) {
        guard (0..<16).contains(channel) else { return }
        wake()
        let said = at.map { min(time, max($0, time - 0.2)) } ?? time
        // The note the pattern has here, and struck already: it is the same one.
        if playhead.playing, time - foretold[channel] < 0.11 {
            midiHeard[channel] = time
            foretold[channel] = -10
            return
        }
        // ... or is about to: the count is behind what sounds.
        if playhead.playing, let next = playhead.untilNext(said), next < 0.07, starts(channel, note) { playhead.hurry(next) }
        midiHeard[channel] = time
        sounded(channel, note, Double(velocity) / 127, for: nil, by: .midi)
    }

    /// The pattern has this note, on its step, on the track's next step.
    private func starts(_ t: Int, _ note: Int) -> Bool {
        let next = (Int(playhead.steps[t]) + 1) % max(1, grid.tracks[t].count)
        return grid.tracks[t].length == 1 && !grid.cells[t * 16 + next].component && grid.notes[t].contains { $0.step == next && $0.note.note == note && abs($0.note.micro) <= 12 }
    }

    public func noteOff(channel: Int, note: Int) { wake(); trail.end(track: channel, note: note, at: time) }

    private func sounded(_ t: Int, _ note: Int, _ velocity: Double, for seconds: Double?, by what: Striker) {
        struck[t][what.rawValue] += 1
        hitFlashes[t].hit(0.35 + 0.65 * velocity)
        levels[t].hit(0.25 + 0.75 * velocity)
        lastNote[t] = note
        lastVelocity[t] = velocity
        strikes[t].append(time)
        if strikes[t].count > 8 { strikes[t].removeFirst() }
        trail.add(track: t, note: note, velocity: velocity, at: time, until: seconds.map { time + min(30, max(0.04, $0)) })
        sky.hit(t, velocity)
    }

    public func select(track t: Int) {
        track = max(0, min(15, t))
        for e in player.select(track: track, at: moment) { out(e) }
    }

    /// SCREEN held and the first dial turned: the pages go by, as in TE's app.
    private func jogged(_ was: [Double]) {
        let pages = Palette.pages(track, samples: input.sounds[track]?.origin == .samples), k = pages[min(input.panel.page & 3, pages.count - 1)].params[0]
        jog += (grid.sound[track][k] - was[k]) * 255
        while abs(jog) >= 8 { turn(jog > 0 ? 1 : -1); jog += jog > 0 ? -8 : 8 }
    }

    /// The beat the moves go by: the pattern's, or a free one at its tempo.
    var beat: Double { (playhead.place(time) ?? time * Double(max(40, input.tempo ?? 120)) / 15) / 4 }

    /// On with what is held: the moves, and the groove a little ahead of its time.
    private func playOn() {
        if !performer.isEmpty { for c in performer.step(beat: beat, from: Here(self)) { out(.init(moment, c)) } }
        guard player.settings.groove != nil, !player.kept.isEmpty else { grooved = -1; return }
        let sixteenth = 15 / Double(max(40, input.tempo ?? 120)), at = beat * 4, next = Int((at + 0.045 / sixteenth).rounded(.down))
        guard next != grooved else { return }
        grooved = next
        for e in player.groove(step: ((next % 16) + 16) % 16, at: max(time, time + (Double(next) - at) * sixteenth), sixteenth: sixteenth) { out(e) }
    }

    /// Everything played or held here ends (the screen is covered, the OP-Z goes).
    public func letGo() {
        grips = [:]
        for e in player.silence(at: moment) { out(e) }
        for c in performer.endAll() { out(.init(moment, c)) }
    }
    public func turn(_ by: Int) {
        let n = Page.allCases.count
        page = Page(rawValue: ((page.rawValue + by) % n + n) % n)!
    }

    /// A touch or click at a dot.
    public func tap(_ x: Int, _ y: Int) -> Action {
        for (r, what) in touches.reversed() where r.contains(x, y) {
            switch what {
            case .page(let p): page = p
            case .track(let t):
                if page != .track, page != .play, page != .chops, page != .perform, track == t { page = .track } else { select(track: t) }
            case .action(let a): return a
            case .grip: continue
            }
            return .none
        }
        return .none
    }

    /// Nothing on screen moves: the picture can wait for the next change.
    public var still: Bool {
        guard input.link == .live, !playhead.playing, page != .sky, page != .fx, page != .chops, grips.isEmpty, performer.isEmpty, player.isEmpty, machinePage == nil, turned > 1, linkFade.settled, tabX.settled else { return false }
        guard hitFlashes.allSatisfy({ $0.level == 0 }), levels.allSatisfy({ $0.level == 0 }), trail.isEmpty(at: time) else { return false }
        return page != .track && knobs[track].allSatisfy(\.settled)
    }

    // MARK: out

    public func frame(_ c: DotCanvas, time now: Double, dt: Double) {
        time = now
        turned += dt
        count()
        for t in 0..<16 { hitFlashes[t].step(dt); levels[t].step(dt) }
        for k in 0..<18 { knobs[track][k].step(dt) }
        tumble(dt)
        playOn()
        pulse.step(dt)
        trail.tidy(now)
        let searching = input.link == .searching || input.bank == nil
        linkFade.target = searching ? 0 : 1
        linkFade.step(dt)
        c.clear()
        touches.removeAll(keepingCapacity: true)
        guard c.width >= Self.smallest.w, c.height >= Self.smallest.h else {
            if c.width > 20, c.height > 8 { c.text("GALAX-Z", c.width / 2, c.height / 2 - 2, Palette.yellow, font: .tiny, align: .center) }
            return
        }
        if linkFade.value < 0.98 { connect(c, dt) }
        guard linkFade.value > 0.02, input.bank != nil else { return }
        if linkFade.value < 0.98 { touches.removeAll(keepingCapacity: true); c.clear() ; if linkFade.value < 0.5 { connect(c, dt); return } }
        let head = 15, foot = 13
        let body = DotRect(4, head + 2, c.width - 8, c.height - head - foot - 4)
        header(c, DotRect(4, 2, c.width - 8, head - 2))
        switch page {
        case .track: trackPage(c, body, dt)
        case .grid: gridPage(c, body, dt)
        case .mix: mixPage(c, body, dt)
        case .play: playPage(c, body, dt)
        case .chops: chopsPage(c, body, dt)
        case .perform: performPage(c, body, dt)
        case .fx: fxPage(c, body, dt)
        case .song: songPage(c, body, dt)
        case .notes: notesPage(c, body, dt)
        case .load: loadPage(c, body, dt)
        case .sky: skyPage(c, body, dt)
        }
        tabs(c, DotRect(4, c.height - foot, c.width - 8, foot - 2), dt)
        // a page comes in row by row, like a screen being written
        if turned < 0.22 {
            let shown = Int(Ease.out(turned / 0.22) * Double(body.h + 2))
            c.fill(DotRect(0, body.y + shown, c.width, max(0, body.h - shown)), .black, 0.85)
            c.rule(body.x, body.y + shown, body.w, Palette.ink, 0.5)
        }
    }

    /// The balls, on from where the OP-Z last said they are (for half a second at the most).
    private func tumble(_ dt: Double) {
        guard let m = input.machines else { return }
        for k in 0..<12 { machineDials[k].step(dt) }
        guard !tombola.balls.isEmpty, time - ballsAt < 0.5 else { return }
        var bounces: [(Machines.Ball, Double)] = []
        tombola.step(dt, dials: m.dials) { bounces.append(($0, $1)) }
        for (b, speed) in bounces where m.track < 8 { machineStruck(m.track, b.note, min(1, 0.45 + speed / 8), by: .tumbler) }
        let keep = max(0, 1 - dt / 0.08)
        for i in ballOff.indices { ballOff[i].x *= keep; ballOff[i].y *= keep }
        if time - trailAt > 0.02 {
            trailAt = time
            ballTrail.append(drawnBalls)
            if ballTrail.count > 14 { ballTrail.removeFirst() }
        }
    }

    /// The balls as they are drawn.
    var drawnBalls: [Machines.Ball] {
        guard ballOff.count == tombola.balls.count else { return tombola.balls }
        return zip(tombola.balls, ballOff).map { b, o in var b = b; b.x += o.x; b.y += o.y; return b }
    }

    private func header(_ c: DotCanvas, _ r: DotRect) {
        var x = r.x
        // the mark: a ring and its satellite, on the beat
        let a = playhead.playing ? time * 0.6 : 0.12
        c.arc(Double(x) + 4.5, Double(r.y) + 4.5, 3.6, Palette.yellow, 0.55 + 0.45 * pulse.level)
        let s = Turn.of(a)
        c.disc(Double(x) + 4.5 + s.x * 3.6, Double(r.y) + 4.5 + s.y * 3.6, 1.0, Palette.ink, 1)
        x += 14
        x += c.text("GALAX-Z", x, r.y + 1, Palette.yellow, font: .small) + 10
        let project = input.address.map { pad($0.project + 1) } ?? "--", pattern = input.address.map { pad($0.pattern + 1) } ?? "--"
        x = readout(c, "PRJ", project, x, r.y)
        x = readout(c, "PAT", pattern, x, r.y)
        x = readout(c, "BPM", input.tempo.map(String.init) ?? "---", x, r.y)
        if playhead.playing {
            c.text("▶", x, r.y + 1, Palette.green, 0.5 + 0.5 * pulse.level)
            x += 10
        }
        if input.panel.recording {
            c.disc(Double(x) + 2.5, Double(r.y) + 4.5, 2.4, Palette.red, Turn.sine(time * 1.5) > -0.3 ? 1 : 0.35)
            x += 10
        }
        // the link, at the right
        let (text, colour): (String, DotColor) = switch input.link {
        case .live: (input.linkName, Palette.green)
        case .loading(let n): ("READING \(n)", Palette.yellow)
        case .hello: ("HELLO", Palette.yellow)
        case .lost: ("LOST", Palette.red)
        case .searching: ("NO OP-Z", Palette.ink)
        }
        let w = DotFont.tiny.width(text)
        c.text(text, r.maxX - w, r.y + 2, colour, 0.8, font: .tiny)
        let pulse = input.link == .live ? 1 : 0.35 + 0.65 * max(0, Turn.sine(time * 1.4))
        c.disc(Double(r.maxX - w) - 5, Double(r.y) + 4.2, 1.6, colour, pulse)
        var right = r.maxX - w - 14
        if let o = input.out, right - DotFont.tiny.width(o) - 8 > x {          // where it is heard: touched, the other
            let ow = DotFont.tiny.width(o) + 8, box = DotRect(right - ow, r.y - 1, ow, 11), here = !o.hasSuffix("OP-Z")
            c.frame(box, here ? Palette.green : Palette.ink, here ? 0.7 : 0.3, radius: 2)
            c.text(o, box.x + 4, box.y + 3, here ? Palette.green : Palette.ink, here ? 1 : 0.6, font: .tiny)
            touches.append((box.inset(-3, -4), .action(.sound)))
            right = box.x - 5
        }
        if let n = input.notice {
            let nw = DotFont.tiny.width(n) + 8, box = DotRect(right - nw, r.y - 1, nw, 11)
            if box.x > x {
                c.frame(box, Palette.yellow, 0.55 + 0.45 * Turn.sine(time * 0.5), radius: 2)
                c.text(n, box.x + 4, box.y + 3, Palette.yellow, font: .tiny)
                touches.append((box.inset(-3, -3), .action(.hub)))
            }
        }
        c.rule(r.x, r.maxY, r.w, Palette.ink, 0.28, step: 3)
    }

    @discardableResult
    func readout(_ c: DotCanvas, _ label: String, _ value: String, _ x: Int, _ y: Int) -> Int {
        let w = c.text(label, x, y + 3, Palette.ink, 0.45, font: .tiny)
        return x + w + 3 + c.text(value, x + w + 3, y + 1, Palette.ink, 0.95) + 9
    }

    private func tabs(_ c: DotCanvas, _ r: DotRect, _ dt: Double) {
        c.rule(r.x, r.y - 1, r.w, Palette.ink, 0.28, step: 3)
        let tight = r.w < 290, reach = tight ? 8 : 3          // a finger on a phone
        let others: [(String, Action)] = [(tight ? "SET" : "SETTINGS", input.notice == nil ? .settings : .hub)]
        func names(_ short: Bool) -> [String] { Page.allCases.map { short ? String($0.name.prefix(3)) : $0.name } }
        func needs(_ n: [String]) -> Int { n.reduce(0) { $0 + DotFont.tiny.width($1) } + others.reduce(0) { $0 + DotFont.tiny.width($1.0) } }
        let count = Page.allCases.count + others.count, labels = needs(names(false)) + 3 * count > r.w ? names(true) : names(false)
        let gap = max(3, min(12, (r.w - needs(labels)) / count))
        var x = r.x
        for p in Page.allCases {
            let label = labels[p.rawValue], w = DotFont.tiny.width(label), on = p == page
            if on { tabX.target = Double(x); if tabX.value == 0 { tabX.jump(Double(x)) } }
            c.text(label, x, r.y + 2, on ? Palette.yellow : Palette.ink, on ? 1 : 0.5, font: .tiny)
            touches.append((DotRect(x - gap / 2, r.y - reach, w + gap, r.h + reach + 2), .page(p)))
            x += w + gap
        }
        tabX.step(dt)
        c.fill(DotRect(Int(tabX.value.rounded()), r.y + 9, DotFont.tiny.width(labels[page.rawValue]), 1), Palette.yellow)
        var right = r.maxX
        for (name, a) in others.reversed() {
            let w = DotFont.tiny.width(name)
            let news = input.notice != nil
            c.text(name, right - w, r.y + 2, news ? Palette.yellow : Palette.ink, news ? 0.6 + 0.4 * Turn.sine(time * 0.5) : 0.5, font: .tiny)
            touches.append((DotRect(right - w - gap / 2, r.y - reach, w + gap, r.h + reach + 2), .action(a)))
            right -= w + gap
        }
    }

    /// The screen in words.
    public var spoken: String {
        guard input.bank != nil else { return "Galax-z. " + input.linkLine }
        let sound = input.sounds[track]?.name ?? ""
        return "\(page.name) page. Track \(track + 1), \(OPZ.trackNames[track]) \(sound). Project \((input.address?.project ?? 0) + 1), "
            + "pattern \((input.address?.pattern ?? 0) + 1), \(input.tempo ?? 0) beats a minute, \(playhead.playing ? "playing" : "stopped")."
    }

    func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }

    /// The step a track is on, if it plays.
    func playhead(_ t: Int) -> Int? { playhead.playing ? Int(playhead.steps[t]) : nil }
}

/// Notes as they went by.
struct Trail {
    struct Note { var track, note: Int; var velocity, start: Double; var end: Double? }
    private(set) var notes: [Note] = []
    static let keep = 8.0

    mutating func add(track: Int, note: Int, velocity: Double, at: Double, until: Double?) {
        end(track: track, note: note, at: at)
        notes.append(Note(track: track, note: note, velocity: velocity, start: at, end: until))
        if notes.count > 600 { notes.removeFirst(200) }
    }

    mutating func end(track: Int, note: Int, at: Double) {
        for i in notes.indices.reversed().prefix(64) where notes[i].track == track && notes[i].note == note && (notes[i].end ?? .infinity) > at {
            notes[i].end = at
            return
        }
    }

    mutating func tidy(_ now: Double) { notes.removeAll { now - ($0.end ?? now) > Self.keep || now - $0.start > 60 } }
    func isEmpty(at now: Double) -> Bool { notes.allSatisfy { now - ($0.end ?? now) > Self.keep } }
    func sounding(_ now: Double) -> [Note] { notes.filter { $0.start <= now && ($0.end ?? .infinity) > now && now - $0.start < 30 } }
}
