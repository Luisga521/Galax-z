import DotKit
import OPZModel

/// What SHOW and the motion track's reel keep between frames.
struct Show {
    static let scenes = ["WARP", "STAGE", "HORIZON", "BLOOM", "REEL"]
    var scene = 0
    /// On to the next scene every eight bars, or at a note of the motion track once two have gone.
    var auto = true
    var sceneAt = -10.0, sceneBar = 0.0, cue = -10.0
    // the reel
    var slide = 0, slideAt = -10.0, seen = -10.0, tick = Int.min, shake = 0.0
    var lens = Lens.plain

    mutating func turn(_ by: Int, at t: Double, bar: Double) {
        scene = ((scene + by) % Self.scenes.count + Self.scenes.count) % Self.scenes.count
        sceneAt = t
        sceneBar = bar
    }
}

extension Stage {
    // MARK: SHOW: the whole song as a light show

    /// SHOW's scene, and whether the scenes go by themselves.
    public var showScene: Int {
        get { show.scene }
        set { show.turn(newValue - show.scene, at: time, bar: showBar.rounded(.down)) }
    }
    /// The bars SHOW counts its scenes by: the song's, or stopped, one every three seconds.
    var showBar: Double { playhead.playing ? beat / 4 : time / 3 }
    public var showAuto: Bool { get { show.auto } set { show.auto = newValue } }
    public static let showScenes = Show.scenes

    func showPage(_ c: DotCanvas, _ r: DotRect, _ dt: Double) {
        let bar = showBar
        if show.auto {
            if bar - show.sceneBar >= 8 || bar < show.sceneBar { show.turn(1, at: time, bar: bar.rounded(.down)) }
            if let s = strikes[15].last, s > show.cue { show.cue = s; if bar - show.sceneBar >= 2 { show.turn(1, at: time, bar: bar.rounded(.down)) } }
        }
        let kick = hitFlashes[0].level, snare = hitFlashes[1].level, colour = keyColour(4..<8), drive = playhead.playing ? Double(max(40, input.tempo ?? 120)) / 120 : 0.3
        let cx = Double(r.midX), cy = Double(r.midY), w = Double(r.w), h = Double(r.h)
        c.clipped(r) {
            switch show.scene {
            case 0:     // WARP: down a tunnel, the kick widening it, stars going by
                starfield(c, r, colour.mixed(.white, 0.5), speed: 0.05 + 0.08 * drive, count: r.w * r.h / 130, streak: 0.08)
                tunnel(c, cx, cy, max(w, h) * 0.62, colour, speed: 0.08 * drive, punch: max(kick, levels[0].level * 0.7), sides: 6 + (Int(bar / 4) % 2) * 2, rings: 16)
            case 1:     // STAGE: the rig, big, over a crowd
                rig(c, r, rigNow(), universe: false, crowd: true)
            case 2:     // HORIZON: a wire landscape under a banded sun
                starfield(c, DotRect(r.x, r.y, r.w, r.h / 2), Palette.ink, speed: 0.01, count: r.w / 3)
                terrain(c, r, colour, speed: 0.6 * drive, swell: 0.3 + 0.7 * levels[4].level, sun: DotColor(0xFFC23D).mixed(.white, kick * 0.4))
            case 3:     // BLOOM: a flower of the tracks, each note a ring going out
                bloom(c, r, kick: kick)
            default:    // REEL: the motion track's pictures, as prints
                reelOn()
                starfield(c, r, colour, speed: 0.02, count: r.w * r.h / 200)
                let ph = min(r.h - 22, Int(Double(r.w) * 0.42)), pw = min(r.w - 24, Int(Double(ph) * 1.6))
                let box = DotRect(r.midX - pw / 2, r.midY - ph / 2 - 3, pw, ph)
                c.fill(box.inset(-3, -3), DotColor(0xF2EEE4), 0.92)
                c.fill(DotRect(box.x - 3, box.maxY, box.w + 6, 9), DotColor(0xF2EEE4), 0.92)
                c.fill(box, .black)
                reel(c, box, p1: knobs[15][0].value, p2: knobs[15][1].value, caption: false)
                let slide = Slide.allCases[((show.slide % Slide.allCases.count) + Slide.allCases.count) % Slide.allCases.count]
                c.text(slide.name + (show.lens.shows(on: slide) ? " · " + show.lens.name : ""), box.midX, box.maxY + 2, DotColor(0x2A2620), 0.9, font: .tiny, align: .center)
            }
            // the lights track's beams, on every scene but the one that is all beams
            if show.scene != 1, levels[14].level > 0.02 {
                let g = rigNow(), a = levels[14].level * 0.5
                for s in [-1.0, 1.0] {
                    let x0 = s < 0 ? Double(r.x) + 2 : Double(r.maxX) - 2, aim = 0.5 + s * (0.1 + 0.06 * Turn.sine(g.phase))
                    for k in 0..<5 {
                        let q = Turn.of(aim + Double(k - 2) * 0.012)
                        c.line(x0, Double(r.y), x0 + q.x * h * 1.4, Double(r.y) + q.y * h * 1.4, k % 2 == 0 ? g.colour : g.other, a * (k == 2 ? 0.6 : 0.3))
                    }
                }
            }
            // the snare: a flash at the edges
            if snare > 0.05 {
                c.frame(r, .white, snare)
                c.frame(r.inset(1, 1), colour.mixed(.white, 0.5), snare * 0.6)
                c.frame(r.inset(2, 2), colour, snare * 0.3)
            }
        }
        // a new scene comes in from a line, like a page
        let age = time - show.sceneAt
        if age < 0.3 {
            let shown = Int(Ease.out(age / 0.3) * Double(r.w))
            c.fill(DotRect(r.x + shown, r.y, r.w - shown, r.h), .black, 0.9)
            c.column(r.x + shown, r.y, r.h, .white, 0.8)
        }
        // which scene, and whether it goes by itself
        let name = "< " + Show.scenes[show.scene] + " >", nw = DotFont.tiny.width(name)
        c.fill(DotRect(r.x, r.y, nw + 6, 9), .black, 0.6)
        c.text(name, r.x + 3, r.y + 2, Palette.ink, 0.75, font: .tiny)
        touches.append((DotRect(r.x - 2, r.y - 2, nw + 14, 15), .grip(.choose(.scene))))
        let aw = DotFont.tiny.width("AUTO") + 6, auto = DotRect(r.maxX - aw, r.y, aw, 9)
        c.fill(auto, .black, 0.6)
        c.frame(auto, show.auto ? Palette.yellow : Palette.ink, show.auto ? 0.8 : 0.3, radius: 2)
        c.text("AUTO", auto.x + 3, auto.y + 2, show.auto ? Palette.yellow : Palette.ink, show.auto ? 0.9 : 0.45, font: .tiny)
        touches.append((auto.inset(-4, -3), .grip(.choose(.showAuto))))
        for i in 0..<Show.scenes.count { c.fill(DotRect(r.x + nw + 10 + i * 4, r.y + 3, 2, 2), Palette.ink, i == show.scene ? 0.9 : 0.25) }
    }

    /// Sixteen petals, a track each, as long as it is loud; every note sends a ring out in its colour.
    private func bloom(_ c: DotCanvas, _ r: DotRect, kick: Double) {
        let cx = Double(r.midX), cy = Double(r.midY), R = Double(min(r.w, r.h * 3 / 2)) * 0.42, squash = 0.68, t = time
        field.drift(c, r, Palette.ink, t, density: r.w * r.h / 140, speed: 0.01, seed: 4)
        for n in trail.notes.reversed().prefix(24) {
            let age = time - n.start
            guard age < 1.6, age >= 0 else { continue }
            let f = age / 1.6
            c.arc(cx, cy, R * (0.18 + 1.1 * Ease.out(f)), Palette.track(n.track), (1 - f) * (1 - f) * (0.4 + 0.6 * n.velocity), squash: squash, dash: 3)
        }
        for tr in 0..<16 {
            let level = levels[tr].level, a0 = Double(tr) / 16 + t * 0.006, len = R * (0.3 + 0.7 * level) * (0.85 + 0.15 * Turn.sine(t * 0.1 + Double(tr) * 0.3))
            let colour = Palette.track(tr)
            for side in [-1.0, 1.0] {
                var last = (cx, cy)
                for s in 1...14 {
                    let f = Double(s) / 14, bend = side * 0.018 * Turn.sine(f * 0.5) * (1 + level)
                    let p = Turn.of(a0 + bend), x = cx + p.x * len * f, y = cy + p.y * len * f * squash
                    c.line(last.0, last.1, x, y, colour, (0.18 + 0.7 * level) * (1 - f * 0.4))
                    last = (x, y)
                }
            }
            let tip = Turn.of(a0)
            c.disc(cx + tip.x * len, cy + tip.y * len * squash, 1 + 1.6 * level, colour.mixed(.white, level * 0.5), 0.3 + 0.7 * level)
        }
        c.disc(cx, cy, 3 + 7 * kick + 2 * pulse.level, Palette.yellow.mixed(.white, kick * 0.5), 0.55 + 0.45 * kick)
        for k in 0..<3 { c.arc(cx, cy, 6 + Double(k) * 4 + 10 * kick, Palette.yellow, (0.35 - Double(k) * 0.1) * (0.3 + kick), squash: squash) }
    }
}
