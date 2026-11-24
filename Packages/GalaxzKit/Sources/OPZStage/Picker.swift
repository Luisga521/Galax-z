import DotKit
import OPZModel
import OPZPlay

/// A choice's values all at once, over the page: tap one, or the top to close; drag to scroll.
struct Picking {
    let choice: Choice, page: Stage.Page, title: String, colour: DotColor
    let names: [String]
    /// Under each name: its chords (flat, degree, quality), or a row of lights (a groove's steps, a scale's notes).
    let lines: [[(flat: Bool, degree: String, quality: String)]], marks: [[Int]]
    let wide: Int                                  // what a value needs across
    var scroll = 0, most = 0, seek = true          // the current one is brought into sight once
}

extension Stage {
    /// A choice touched, not dragged: its left the one before, its right the next, the middle of many all of them.
    func touched(_ c: Choice, _ x: Int, _ box: DotRect) {
        let third = box.w / 3
        if c.long, x >= box.x + third, x < box.maxX - third { open(c) } else { choose(c, x < box.midX ? -1 : 1) }
    }

    func open(_ c: Choice) {
        guard let (names, _) = values(c) else { return }
        var lines: [[(flat: Bool, degree: String, quality: String)]] = [], marks: [[Int]] = []
        switch c {
        case .progression: lines = Progressions.all.map { $0.chords.map(Self.spelled) }
        case .groove: marks = [[]] + Groove.library.map { $0.steps.map { $0 == "X" ? 3 : $0 == "x" ? 2 : $0 == "o" ? 1 : 0 } }
        case .scale: marks = Scale.allCases.map { s in (0..<12).map { $0 == 0 ? 3 : s.steps.contains($0) ? 2 : 0 } }
        default: break
        }
        let widest = names.map { DotFont.tiny.width($0) }.max() ?? 0, w = max(widest, marks.isEmpty ? 0 : 32, lines.isEmpty ? 0 : 66)
        let colour = switch c {
        case .progression: Palette.pink
        case .groove: Palette.teal
        case .tool: Palette.green
        case .octave: Palette.ink
        case .shelf: Self.family(Move.gallery.first { $0.family == Move.families[shelf % Move.families.count] } ?? Move.gallery[0])
        default: Palette.yellow
        }
        picking = Picking(choice: c, page: page, title: c == .tool ? "CHORD" : "\(c)".uppercased(), colour: colour, names: names, lines: lines, marks: marks,
                          wide: min(88, max(20, w + 6)))
    }

    /// Open a choice's values by its name ("PROGRESSION", "GROOVE", "CHORD"…), for pictures.
    public func openList(_ name: String) {
        if let c = Choice.allCases.first(where: { (c: Choice) in c.long && (c == .tool ? "CHORD" : "\(c)".uppercased()) == name }) { open(c) }
    }

    /// A chord as the list writes it: minor as -, so 6-7 and 4M7 differ in a type with no small letters.
    static func spelled(_ ch: NashChord) -> (flat: Bool, degree: String, quality: String) {
        let q = switch ch.quality {
        case .minor: "-"
        case .min7: "-7"
        case .min9: "-9"
        default: ch.quality.rawValue
        }
        return (ch.flat, "\(ch.degree)", q)
    }

    /// A progression's chords in a line, the degree bright and what it is dim; what does not fit, an ellipsis.
    private func chords(_ c: DotCanvas, _ all: [(flat: Bool, degree: String, quality: String)], _ x0: Int, _ y: Int, _ end: Int, _ k: DotColor, _ on: Bool) {
        var x = x0
        for ch in all {
            let w = (ch.flat ? 4 : 0) + DotFont.tiny.width(ch.degree) + DotFont.tiny.width(ch.quality)
            if x + w > end { c.text("…", x, y, k, 0.6, font: .tiny); return }
            if ch.flat {                                                            // the type has no flat: one drawn
                for j in 0..<5 { c.set(x, y + j, k, on ? 0.9 : 0.85) }
                c.set(x + 1, y + 2, k, on ? 0.9 : 0.85); c.set(x + 2, y + 3, k, on ? 0.9 : 0.85); c.set(x + 1, y + 4, k, on ? 0.9 : 0.85)
                x += 4
            }
            x += c.text(ch.degree, x, y, k, on ? 1 : 0.95, font: .tiny)
            x += c.text(ch.quality, x, y, k, on ? 0.6 : 0.5, font: .tiny) + 3
        }
    }

    /// The open list, over the page's body.
    func picker(_ c: DotCanvas, _ r: DotRect) {
        guard var p = picking, p.page == page, let at = values(p.choice)?.at else { picking = nil; return }
        c.fill(r, .black, 0.93)
        touches.append((r, .grip(.pick(-1))))
        // the top: what, which, and the way out
        let top = DotRect(r.x, r.y, r.w, 11), close = "CLOSE ×", cw = DotFont.tiny.width(close) + 8
        let x = c.text(p.title, r.x + 2, r.y + 3, p.colour, 0.95, font: .tiny) + r.x + 8
        c.text("\(at + 1)/\(p.names.count)", x, r.y + 3, Palette.ink, 0.5, font: .tiny)
        c.frame(DotRect(r.maxX - cw, r.y, cw, 10), Palette.ink, 0.5, radius: 2)
        c.text(close, r.maxX - cw + 4, r.y + 3, .white, 0.85, font: .tiny)
        touches.append((top, .grip(.unpick)))
        c.rule(r.x, top.maxY + 1, r.w, Palette.ink, 0.28, step: 3)
        // the values, as many across as fit
        let list = DotRect(r.x, top.maxY + 4, r.w - 4, r.maxY - top.maxY - 4), two = !p.lines.isEmpty || !p.marks.isEmpty
        let cols = max(list.w >= 160 ? 2 : 1, (list.w + 2) / (p.wide + 2)), cw2 = (list.w + 2) / cols, ch = two ? 20 : 14, rows = (p.names.count + cols - 1) / cols
        p.most = max(0, rows * ch - 2 - list.h)
        if p.seek { p.scroll = at / cols * ch + ch / 2 - list.h / 2; p.seek = false }
        p.scroll = min(p.most, max(0, p.scroll))
        picking = p
        c.clipped(list) {
            for row in p.scroll / ch...min(rows - 1, (p.scroll + list.h) / ch) { for col in 0..<cols {
                let i = row * cols + col
                guard i < p.names.count else { break }
                let box = DotRect(list.x + col * cw2, list.y + row * ch - p.scroll, cw2 - 2, ch - 2), on = i == at
                c.pill(box, p.colour, on ? 0.8 : 0.15, radius: 2)
                c.text(DotFont.tiny.fitted(p.names[i], box.w - 6), box.x + 3, box.y + (two ? 3 : 4), on ? .black : .white, on ? 1 : 0.9, font: .tiny)
                if !p.lines.isEmpty { chords(c, p.lines[i], box.x + 3, box.y + 11, box.maxX - 3, on ? .black : p.colour, on) }
                for (k, m) in p.marks[safe: i].enumerated() {
                    c.fill(DotRect(box.x + 3 + k * 2, box.y + 16 - max(1, m), 1, max(1, m)), on ? .black : p.colour, m == 0 ? 0.25 : on ? 0.9 : 0.8)
                }
                let seen = box.intersection(list)
                if seen.h > 2 { touches.append((seen, .grip(.pick(i)))) }
            } }
        }
        // where it is, if it is longer than the screen
        guard p.most > 0 else { return }
        let bar = list.h * list.h / (list.h + p.most)
        c.column(list.maxX + 2, list.y, list.h, Palette.ink, 0.25, step: 2)
        c.fill(DotRect(list.maxX + 1, list.y + (list.h - bar) * p.scroll / p.most, 2, bar), p.colour, 0.8)
    }
}

private extension Array where Element == [Int] {
    subscript(safe i: Int) -> [Int] { indices.contains(i) ? self[i] : [] }
}
