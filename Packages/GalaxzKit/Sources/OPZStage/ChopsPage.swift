import ChopKit
import DotKit
import OPZModel

/// The chops as the screen shows them.
public struct ChopDesk: Equatable, Sendable {
    public enum Source: Int, CaseIterable, Sendable { case mic, opz, file; public var name: String { ["MIC", "OP-Z", "FILE"][rawValue] } }
    public enum View: Int, CaseIterable, Sendable { case dials, effects, chop; var name: String { ["DIALS", "EFFECTS", "CHOP"][rawValue] } }
    public var name = "VOX"
    public var list: [Kit.Chop] = []
    public var shape: [Float] = []
    /// Where each chop is in the shape, 0-1.
    public var length = 1
    public var dials = ChopDial.allCases.map(\.start)
    public var effects = Effect.Kind.allCases.map { Effect($0) }
    public var source = Source.mic, view = View.dials, cut = Chopper.Mode.hits
    public var chosen = 0, effect = 0
    /// MODULE plays them; its notes are pitches of the chosen one.
    public var module = true, keys = false
    public var recording = false, seconds = 0.0, level = 0.0
    public var sounding: UInt32 = 0
    /// It can be taken away (VOX cannot), and what there is to say.
    public var own = false
    public var line = ""
    public init() {}
}

/// What the chops are asked for.
public enum ChopAsk: Equatable, Sendable {
    case start(Int, velocity: Double, id: Int, semitones: Double), stop(id: Int), silence
    case dial(Int, Double), effect(Effect), edited([Kit.Chop])
    case kit(Int), cut(Chopper.Mode), removeKit
    case record(ChopDesk.Source), stopRecording, open
    /// The dials and effects as they are: keep them.
    case keep
}

extension Stage {
    // MARK: CHOPS: a voice in pieces

    func chopsPage(_ c: DotCanvas, _ r: DotRect, _ dt: Double) {
        let d = chops, colour = Palette.track(13), tall = r.h > r.w
        func row(_ y: Int, _ all: [(Choice, String, String, DotColor, Bool)]) {
            let w = r.w / all.count
            for (i, a) in all.enumerated() { chooser(c, DotRect(r.x + i * w, y, w - 3, 19), a.0, a.1, a.2, a.3, on: a.4) }
        }
        let record = d.recording ? "STOP \(Int(d.seconds))" : d.source == .file ? "OPEN" : "START"
        row(r.y, [(.kit, "KIT", d.name.uppercased(), colour, false), (.source, "FROM", d.source.name, Palette.yellow, false),
                  (.record, d.source == .file ? "A FILE" : "RECORD", record, Palette.red, d.recording), (.cut, "CUT", d.cut.name, Palette.yellow, false)]
            + (tall ? [] : [(.module, "MODULE", d.module ? "PLAYS" : "OFF", colour, d.module), (.keys, "ITS KEYS", d.keys ? "PITCH" : "CHOPS", colour, d.keys), (.view, "SHOW", d.view.name, Palette.teal, true)]))
        var y = r.y + 21
        if tall {
            row(y, [(.module, "MODULE", d.module ? "PLAYS" : "OFF", colour, d.module), (.keys, "ITS KEYS", d.keys ? "PITCH" : "CHOPS", colour, d.keys), (.view, "SHOW", d.view.name, Palette.teal, true)])
            y += 21
        }
        // the sound, its chops, what sounds of it
        let strip = DotRect(r.x, y, r.w, 24)
        if d.recording {
            c.frame(strip, Palette.red, 0.5 + 0.4 * Turn.sine(time), radius: 2)
            c.fill(DotRect(strip.x + 2, strip.midY - 3, Int(Double(strip.w - 4) * min(1, d.level)), 6), Palette.red, 0.8)
            c.text("RECORDING \(d.source.name)", strip.midX, strip.y + 4, .white, 0.9, font: .tiny, align: .center)
        } else {
            for x in 0..<strip.w where !d.shape.isEmpty {
                let at = x * d.shape.count / strip.w, sample = x * d.length / strip.w, k = d.list.firstIndex { $0.start <= sample && sample < $0.end } ?? -1
                let h = max(0, Int(d.shape[at] * 11)), lit = k >= 0 && k < 24 && d.sounding >> UInt32(k) & 1 == 1
                for j in -h...h { c.set(strip.x + x, strip.midY + j, lit ? .white : k == d.chosen ? Palette.yellow : colour, lit ? 1 : k == d.chosen ? 0.8 : 0.4) }
            }
            for k in d.list where d.length > 0 { c.column(strip.x + k.start * strip.w / d.length, strip.y, strip.h, Palette.ink, 0.25, step: 2) }
            if !d.line.isEmpty { c.text(DotFont.tiny.fitted(d.line, strip.w - 6), strip.midX, strip.y + 1, Palette.yellow, 0.9, font: .tiny, align: .center) }
        }
        y = strip.maxY + 3
        let rest = DotRect(r.x, y, r.w, r.maxY - y)
        guard rest.h > 40 else { return }
        let side = tall ? 0 : max(118, rest.w * 42 / 100), below = tall ? max(96, rest.h * 42 / 100) : 0
        let pads = DotRect(rest.x, rest.y, rest.w - side - (tall ? 0 : 5), rest.h - below - (tall ? 4 : 0)), cols = tall ? 4 : 6, rows = 24 / cols
        let pw = pads.w / cols, ph = pads.h / rows
        for k in 0..<24 {
            let box = DotRect(pads.x + k % cols * pw, pads.y + (rows - 1 - k / cols) * ph, pw - 2, ph - 2)
            guard k < d.list.count else { c.frame(box, Palette.ink, 0.08, radius: 2); continue }
            let lit = d.sounding >> UInt32(k) & 1 == 1, chop = d.list[k]
            c.pill(box, lit ? .white : colour, lit ? 0.9 : chop.on ? 0.2 : 0.05, radius: 2)
            if k == d.chosen { c.frame(box, Palette.yellow, 0.9, radius: 2) }
            c.text(DotFont.tiny.fitted(chop.name.uppercased(), box.w - 4), box.x + 3, box.y + 3, lit ? .black : Palette.ink, lit ? 1 : chop.on ? 0.85 : 0.3, font: .tiny)
            touches.append((box, .grip(.chop(k))))
        }
        let panel = tall ? DotRect(rest.x, pads.maxY + 4, rest.w, below) : DotRect(pads.maxX + 5, rest.y, side, rest.h)
        switch d.view {
        case .dials:
            let n = tall || panel.w > panel.h * 3 / 2 ? 4 : 2, w = panel.w / n, h = panel.h / (8 / n)
            for k in ChopDial.allCases {
                let box = DotRect(panel.x + k.rawValue % n * w, panel.y + k.rawValue / n * h, w, h), v = d.dials[k.rawValue]
                let text = switch k {
                case .pitch: { let s = Int(((v - 0.5) * 48).rounded()); return s > 0 ? "+\(s)" : "\(s)" }()
                case .bloom: ChopDial.blooms[min(7, Int(v * 7.99))]
                case .tail: v > 0.75 ? "LOOP" : "\(Int((0.06 + v / 0.75 * 0.94) * 100))"
                default: "\(Int((v * 100).rounded()))"
                }
                gauge(c, box, v, text, k.name, k.rawValue < 4 ? Palette.ink : Palette.green)
                touches.append((box, .grip(.chopDial(k.rawValue))))
            }
        case .effects:
            let n = tall ? 4 : 3, rowsE = (12 + n - 1) / n, dialH = min(52, panel.h / 2), bh = max(9, (panel.h - dialH) / rowsE), bw = panel.w / n
            for (k, e) in d.effects.enumerated() {
                let box = DotRect(panel.x + k % n * bw, panel.y + k / n * bh, bw - 2, bh - 2)
                c.pill(box, Palette.teal, e.on ? 0.65 : 0.12, radius: 2)
                if k == d.effect { c.frame(box, Palette.yellow, 0.9, radius: 2) }
                c.text(DotFont.tiny.fitted(e.kind.name, box.w - 6), box.x + 3, box.midY - 2, e.on ? .white : Palette.ink, e.on ? 1 : 0.6, font: .tiny)
                touches.append((box, .grip(.effect(k))))
            }
            let e = d.effects[min(d.effect, 11)], top = panel.maxY - dialH, w = panel.w / 3
            for k in 0..<3 {
                let box = DotRect(panel.x + k * w, top + 2, w, dialH - 2)
                gauge(c, box, e.dials[k], "\(Int((e.dials[k] * 100).rounded()))", e.kind.dials[k], e.on ? Palette.teal : Palette.ink)
                touches.append((box, .grip(.effectDial(k))))
            }
        case .chop:
            guard d.list.indices.contains(d.chosen) else { break }
            let chop = d.list[d.chosen], w = panel.w / 3, h = max(40, min(56, panel.h - 44))
            for (k, (name, v, text)) in [("PITCH", Double(chop.pitch + 24) / 48, "\(chop.pitch)"), ("LEVEL", chop.level, "\(Int(chop.level * 100))"), ("PAN", chop.pan, "\(Int((chop.pan - 0.5) * 200))")].enumerated() {
                let box = DotRect(panel.x + k * w, panel.y, w, h)
                gauge(c, box, v, text, name, Palette.yellow)
                touches.append((box, .grip(.edit(k))))
            }
            let yy = panel.y + h + 2
            chooser(c, DotRect(panel.x, yy, w - 2, 19), .reverse, "WAY", chop.reverse ? "BACK" : "FORTH", Palette.pink, on: chop.reverse)
            chooser(c, DotRect(panel.x + w, yy, w - 2, 19), .choke, "CHOKE", chop.choke ? "ON" : "OFF", Palette.pink, on: chop.choke)
            chooser(c, DotRect(panel.x + w * 2, yy, w, 19), .chopOn, "CHOP", chop.on ? "ON" : "OFF", Palette.green, on: chop.on)
            if d.own, yy + 41 <= panel.maxY { chooser(c, DotRect(panel.x, yy + 22, panel.w, 19), .remove, "THIS KIT", "TAKE IT AWAY", Palette.red) }
        }
    }
}
