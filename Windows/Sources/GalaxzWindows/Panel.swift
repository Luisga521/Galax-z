#if os(Windows)
import DotKit
import Foundation
import WinSDK

/// The Mac's colours (`App/Face.swift`), as 0xRRGGBB.
enum Ink {
    static let background: UInt32 = 0x0C0C0D, panel: UInt32 = 0x161618, ink: UInt32 = 0xEDEBE6
    static let yellow: UInt32 = 0xFFD23F, green: UInt32 = 0x2FD18B, red: UInt32 = 0xFF5A36, blue: UInt32 = 0x3D7BFF

    /// `c` at `alpha` over `bg`: GDI draws no see-through colour, so it is mixed here.
    static func mix(_ c: UInt32, _ alpha: Double, over bg: UInt32 = background) -> UInt32 {
        let a = max(0, min(1, alpha))
        func ch(_ v: UInt32, _ s: UInt32) -> UInt32 { (v >> s) & 255 }
        func m(_ s: UInt32) -> UInt32 { UInt32((Double(ch(c, s)) * a + Double(ch(bg, s)) * (1 - a)).rounded()) << s }
        return m(16) | m(8) | m(0)
    }

    static func ref(_ c: UInt32) -> COLORREF { COLORREF((c >> 16) & 255 | (c & 0xFF00) | (c & 255) << 16) }
}

/// Settings' screens on Windows, drawn by GDI in Galax-z's look: an immediate-mode kit. Each frame the screen is laid out
/// again from the app's state (`SettingsPanel.layout`); a widget answers whether it was clicked as it is laid out. What it
/// draws is kept as a list and painted when the layout is done, a card's background under what is in it.
final class Ui {
    struct Font: Hashable { var size: Int32; var bold: Bool }

    enum Op {
        case fill(RECT, UInt32, Int32)                    // colour, corner
        case stroke(RECT, UInt32, Int32)
        case text(String, RECT, Font, UInt32, UINT)
        case dots([(Int32, Int32)], Int32, UInt32)        // centres, size
        case ellipse(RECT, UInt32)
    }

    private(set) var ops: [Op] = []
    private var fonts: [Font: HFONT] = [:]
    private let measureDC: HDC
    /// Window pixels per 1/96 inch.
    var scale = 1.0

    // input, in window pixels
    var mouse = POINT(x: -1, y: -1)
    var down = false
    private var pressedAt: POINT?
    private var releasedAt: POINT?
    private(set) var active: String?
    private var pressStarted = 0.0
    /// Something is moving (a held button fills, a preview plays): draw again soon.
    var animating = false
    /// Work to do once the layout is over (a dialog box must not open in the middle of one).
    private var later: [() -> Void] = []

    /// The top of the scrolling part: what is above it is the bar.
    var contentTop: Int32 = 0
    var scroll: Int32 = 0
    var contentHeight: Int32 = 0
    var size = (w: Int32(1), h: Int32(1))

    init() {
        measureDC = CreateCompatibleDC(nil)
    }

    func px(_ v: Double) -> Int32 { Int32((v * scale).rounded()) }

    func font(_ size: Double, bold: Bool = false) -> Font { Font(size: px(size * 1.25), bold: bold) }

    private func hfont(_ f: Font) -> HFONT? {
        if let h = fonts[f] { return h }
        let face = Array("Consolas".utf16) + [0]
        let h = CreateFontW(-f.size, 0, 0, 0, f.bold ? 700 : 400, 0, 0, 0, 1, 0, 0, 5, 0, face)   // DEFAULT_CHARSET, CLEARTYPE_QUALITY
        fonts[f] = h
        return h
    }

    /// Fonts for a new scale.
    func rescale(_ s: Double) {
        guard s != scale else { return }
        scale = s
        for (_, h) in fonts { DeleteObject(h) }
        fonts = [:]
    }

    // MARK: a frame

    func begin() {
        ops = []
        animating = false
    }

    /// The layout is done: forget the click. What waited for it, to run once the frame is painted.
    func end() -> [() -> Void] {
        if releasedAt != nil { releasedAt = nil; active = nil }
        pressedAt = nil
        let l = later
        later = []
        return l
    }

    func defer_(_ f: @escaping () -> Void) { later.append(f) }

    func press(_ p: POINT) { pressedAt = p; releasedAt = nil; down = true; mouse = p; active = nil; pressStarted = ProcessInfo.processInfo.systemUptime }
    func release(_ p: POINT) { releasedAt = p; down = false; mouse = p }
    func cancel() { down = false; active = nil; pressedAt = nil; releasedAt = nil }

    func wheel(_ delta: Int32) {
        scroll = max(0, min(max(0, contentHeight - (size.h - contentTop)), scroll - delta * px(48) / 120))
    }

    private static func inside(_ r: RECT, _ p: POINT) -> Bool { p.x >= r.left && p.x < r.right && p.y >= r.top && p.y < r.bottom }

    /// A rectangle that can be pressed: whether this release clicked it. `fixed`: in the bar, which does not scroll.
    func interact(_ id: String, _ r: RECT, enabled: Bool = true, fixed: Bool = false) -> Bool {
        guard enabled else { if active == id { active = nil }; return false }
        func visible(_ p: POINT) -> Bool { fixed ? p.y < contentTop : p.y >= contentTop }
        if let p = pressedAt, Self.inside(r, p), visible(p) { active = id; pressedAt = nil }
        if let p = releasedAt, active == id { return Self.inside(r, p) && visible(p) }
        return false
    }

    func isHeld(_ id: String, _ r: RECT) -> Bool { active == id && down && Self.inside(r, mouse) }
    var heldSeconds: Double { ProcessInfo.processInfo.systemUptime - pressStarted }

    // MARK: drawing

    func fill(_ r: RECT, _ c: UInt32, corner: Double = 0) { ops.append(.fill(r, c, px(corner))) }
    func stroke(_ r: RECT, _ c: UInt32, corner: Double = 0) { ops.append(.stroke(r, c, px(corner))) }
    func ellipse(_ r: RECT, _ c: UInt32) { ops.append(.ellipse(r, c)) }

    /// A card's background, under what was drawn since `mark`.
    func card(from mark: Int, _ r: RECT, _ c: UInt32 = Ink.panel, corner: Double = 14, stroke s: UInt32? = nil) {
        ops.insert(.fill(r, c, px(corner)), at: min(mark, ops.count))
        if let s { ops.append(.stroke(r, s, px(corner))) }
    }
    var mark: Int { ops.count }

    /// How big `s` is, wrapped at `width` (0: one line).
    func measure(_ s: String, _ f: Font, width: Int32 = 0) -> SIZE {
        guard !s.isEmpty else { return SIZE(cx: 0, cy: f.size) }
        let old = SelectObject(measureDC, hfont(f))
        defer { SelectObject(measureDC, old) }
        var r = RECT(left: 0, top: 0, right: max(1, width), bottom: 0)
        let w = Array(s.utf16)
        _ = DrawTextW(measureDC, w, Int32(w.count), &r, UINT(width > 0 ? 0x10 : 0x20) | 0x400 | 0x800)   // WORDBREAK or SINGLELINE, CALCRECT, NOPREFIX
        return SIZE(cx: r.right - r.left, cy: r.bottom - r.top)
    }

    /// Text at `x, y`, wrapped at `width`: its height.
    @discardableResult
    func text(_ s: String, _ x: Int32, _ y: Int32, width: Int32, _ f: Font, _ c: UInt32 = Ink.ink, alpha: Double = 1, align: UINT = 0) -> Int32 {
        let h = measure(s, f, width: width).cy
        ops.append(.text(s, RECT(left: x, top: y, right: x + width, bottom: y + h), f, Ink.mix(c, alpha), 0x10 | 0x800 | align))
        return h
    }

    /// One line, cut short with … where it does not fit.
    func line(_ s: String, _ r: RECT, _ f: Font, _ c: UInt32 = Ink.ink, alpha: Double = 1, align: UINT = 0) {
        ops.append(.text(s, r, f, Ink.mix(c, alpha), 0x20 | 0x04 | 0x800 | 0x8000 | align))     // SINGLELINE VCENTER NOPREFIX END_ELLIPSIS
    }

    // MARK: dot text (the Mac's DotText)

    private var dotCache: [String: (w: Int, h: Int, lit: [(Int, Int)])] = [:]

    /// Galax-z's dot type: its width.
    @discardableResult
    func dotText(_ s: String, _ x: Int32, _ y: Int32, font: Int = 0, dot: Double = 2, _ c: UInt32 = Ink.ink, alpha: Double = 1) -> Int32 {
        let key = "\(font)\u{1}\(s)"
        let g: (w: Int, h: Int, lit: [(Int, Int)])
        if let c = dotCache[key] { g = c } else {
            let f = [DotFont.tiny, .small, .big][max(0, min(2, font))]
            let t = s.uppercased(), w = max(1, f.width(t))
            let canvas = DotCanvas(width: w, height: f.height)
            _ = canvas.text(t, 0, 0, DotColor(255, 255, 255), font: f)
            var lit: [(Int, Int)] = []
            for yy in 0..<f.height { for xx in 0..<w where canvas[xx, yy].r > 100 { lit.append((xx, yy)) } }
            g = (w, f.height, lit)
            if dotCache.count > 400 { dotCache.removeAll() }
            dotCache[key] = g
        }
        let pitch = dot * scale * 1.25
        let size = max(1, Int32((pitch * 0.78).rounded()))
        ops.append(.dots(g.lit.map { (x + Int32((Double($0.0) * pitch).rounded()), y + Int32((Double($0.1) * pitch).rounded())) }, size, Ink.mix(c, alpha)))
        return Int32((Double(g.w) * pitch).rounded())
    }

    func dotHeight(font: Int = 0, dot: Double = 2) -> Int32 {
        Int32((Double([DotFont.tiny, .small, .big][max(0, min(2, font))].height) * dot * scale * 1.25).rounded())
    }

    // MARK: widgets

    func buttonWidth(_ label: String) -> Int32 { measure(label, font(10, bold: true)).cx + px(28) }
    var buttonHeight: Int32 { px(30) }

    /// A pill button (`PillButton`): clicked.
    func button(_ label: String, id: String? = nil, _ x: Int32, _ y: Int32, fill: UInt32? = nil, enabled: Bool = true, fixed: Bool = false) -> Bool {
        let r = RECT(left: x, top: y, right: x + buttonWidth(label), bottom: y + buttonHeight)
        let clicked = interact(id ?? label, r, enabled: enabled, fixed: fixed)
        let pressed = isHeld(id ?? label, r)
        let a = enabled ? 1.0 : 0.35
        if let fill {
            self.fill(r, Ink.mix(fill, a * (pressed ? 0.75 : 1)), corner: 15)
            line(label, r, font(10, bold: true), Ink.background, align: 1)
        } else {
            self.fill(r, Ink.mix(Ink.ink, pressed ? 0.16 : 0.07, over: Ink.panel), corner: 15)
            stroke(r, Ink.mix(Ink.ink, 0.25 * a, over: Ink.panel), corner: 15)
            line(label, r, font(10, bold: true), Ink.ink, alpha: a, align: 1)
        }
        return clicked
    }

    /// A switch: the new value when clicked.
    func toggle(_ id: String, _ on: Bool, _ x: Int32, _ y: Int32, enabled: Bool = true) -> Bool? {
        let r = RECT(left: x, top: y, right: x + px(44), bottom: y + px(24))
        let clicked = interact(id, r, enabled: enabled)
        let a = enabled ? 1.0 : 0.35
        fill(r, on ? Ink.mix(Ink.yellow, a) : Ink.mix(Ink.ink, 0.18 * a, over: Ink.panel), corner: 12)
        let k = px(18), kx = on ? r.right - k - px(3) : r.left + px(3)
        ellipse(RECT(left: kx, top: r.top + px(3), right: kx + k, bottom: r.top + px(3) + k), on ? Ink.background : Ink.mix(Ink.ink, 0.8 * a, over: Ink.panel))
        return clicked ? !on : nil
    }
    var toggleWidth: Int32 { px(44) }

    /// A slider over `range`: the value as dragged.
    func slider(_ id: String, _ v: Double, _ range: ClosedRange<Double>, _ x: Int32, _ y: Int32, width: Int32, enabled: Bool = true) -> Double {
        let r = RECT(left: x, top: y, right: x + width, bottom: y + px(22))
        _ = interact(id, r, enabled: enabled)
        var value = v
        if active == id, down {
            let f = Double(mouse.x - r.left) / Double(max(1, width))
            value = range.lowerBound + max(0, min(1, f)) * (range.upperBound - range.lowerBound)
        }
        let f = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let mid = r.top + px(11), at = r.left + Int32(Double(width) * f)
        fill(RECT(left: r.left, top: mid - px(2), right: r.right, bottom: mid + px(2)), Ink.mix(Ink.ink, 0.15, over: Ink.panel), corner: 2)
        fill(RECT(left: r.left, top: mid - px(2), right: at, bottom: mid + px(2)), Ink.mix(Ink.yellow, enabled ? 1 : 0.4, over: Ink.panel), corner: 2)
        ellipse(RECT(left: at - px(8), top: mid - px(8), right: at + px(8), bottom: mid + px(8)), Ink.ink)
        return value
    }

    /// A row of choices: the one clicked.
    func segmented(_ id: String, _ options: [String], _ chosen: Int, _ x: Int32, _ y: Int32, width: Int32, enabled: Bool = true, fixed: Bool = false) -> Int? {
        let n = Int32(max(1, options.count)), h = px(30)
        let r = RECT(left: x, top: y, right: x + width, bottom: y + h)
        fill(r, Ink.mix(Ink.ink, 0.07, over: fixed ? Ink.background : Ink.panel), corner: 8)
        var out: Int?
        for (i, o) in options.enumerated() {
            let sx = x + width * Int32(i) / n, ex = x + width * Int32(i + 1) / n
            let s = RECT(left: sx + px(2), top: y + px(2), right: ex - px(2), bottom: y + h - px(2))
            if interact("\(id).\(i)", s, enabled: enabled, fixed: fixed) { out = i }
            if i == chosen { fill(s, Ink.mix(Ink.yellow, enabled ? 1 : 0.5), corner: 7) }
            line(o, s, font(10, bold: true), i == chosen ? Ink.background : Ink.ink, alpha: enabled ? (i == chosen ? 1 : 0.75) : 0.35, align: 1)
        }
        return out
    }

    /// The Mac's `HoldButton`: held for `seconds`, then asked once more (`question`) before `action`.
    func holdButton(_ id: String, _ title: String, question: String, _ x: Int32, _ y: Int32, color: UInt32 = Ink.yellow, enabled: Bool,
                    seconds: Double = 1.4, hwnd: HWND?, action: @escaping () -> Void) -> Int32 {
        let w = max(px(190), measure(title, font(11, bold: true)).cx + px(36)), h = px(40)
        let r = RECT(left: x, top: y, right: x + w, bottom: y + h)
        _ = interact(id, r, enabled: enabled)
        let held = enabled && isHeld(id, r)
        let f = held ? min(1, heldSeconds / seconds) : 0
        fill(r, Ink.mix(color, enabled ? 0.12 : 0.05, over: Ink.panel), corner: 10)
        if f > 0 { fill(RECT(left: r.left, top: r.top, right: r.left + Int32(Double(w) * f), bottom: r.bottom), color, corner: 10) }
        stroke(r, Ink.mix(color, enabled ? 0.9 : 0.3, over: Ink.panel), corner: 10)
        line(held ? "KEEP HOLDING" : title, r, font(11, bold: true), held && f > 0.5 ? Ink.background : color, alpha: enabled ? 1 : 0.4, align: 1)
        if held {
            animating = true
            if f >= 1 {
                cancel()
                defer_ {
                    let q = Array(question.utf16) + [0], t = Array("Galax-z".utf16) + [0]
                    // MB_YESNO | MB_ICONWARNING | MB_DEFBUTTON2: No unless chosen
                    if MessageBoxW(hwnd, q, t, UINT(0x04 | 0x30 | 0x100)) == 6 { action() }      // IDYES
                }
            }
        }
        return h
    }

    /// A bar of dots (`DotProgress`); without a value, a wave.
    func progress(_ value: Double?, _ x: Int32, _ y: Int32, width: Int32) -> Int32 {
        let step = px(9), d = px(7), n = max(1, Int(width / step))
        let t = ProcessInfo.processInfo.systemUptime
        for i in 0..<n { for j in 0..<2 {
            let f = Double(i) / Double(max(1, n - 1))
            let a = value.map { f <= $0 ? 1.0 : 0.12 } ?? 0.12 + 0.88 * max(0, sin(t * 4 - f * 12))
            let cx = x + Int32(i) * step, cy = y + Int32(j) * step
            ellipse(RECT(left: cx, top: cy, right: cx + d, bottom: cy + d), Ink.mix(Ink.yellow, a, over: Ink.panel))
        } }
        if value == nil { animating = true }
        return step * 2
    }

    // MARK: painting

    private var bufferDC: HDC?
    private var bitmap: HBITMAP?
    private var bufferSize = (w: Int32(0), h: Int32(0))

    /// Everything laid out, onto `dc`.
    func paint(_ dc: HDC) {
        if bufferDC == nil || bufferSize != size {
            if let bitmap { DeleteObject(bitmap) }
            if let bufferDC { DeleteDC(bufferDC) }
            bufferDC = CreateCompatibleDC(dc)
            bitmap = CreateCompatibleBitmap(dc, size.w, size.h)
            SelectObject(bufferDC, bitmap)
            bufferSize = size
        }
        guard let m = bufferDC else { return }
        let nullPen = GetStockObject(8)                                  // NULL_PEN
        var all = RECT(left: 0, top: 0, right: size.w, bottom: size.h)
        let bg = CreateSolidBrush(Ink.ref(Ink.background))
        FillRect(m, &all, bg)
        DeleteObject(bg)
        SetBkMode(m, 1)                                                  // TRANSPARENT
        for op in ops {
            switch op {
            case .fill(let r, let c, let corner):
                let b = CreateSolidBrush(Ink.ref(c))
                let ob = SelectObject(m, b), op = SelectObject(m, nullPen)
                if corner > 0 { RoundRect(m, r.left, r.top, r.right + 1, r.bottom + 1, corner, corner) }
                else { var rr = r; FillRect(m, &rr, b) }
                SelectObject(m, ob); SelectObject(m, op)
                DeleteObject(b)
            case .stroke(let r, let c, let corner):
                let p = CreatePen(0, max(1, px(1.2)), Ink.ref(c))
                let op = SelectObject(m, p), ob = SelectObject(m, GetStockObject(5))      // NULL_BRUSH
                RoundRect(m, r.left, r.top, r.right, r.bottom, corner, corner)
                SelectObject(m, op); SelectObject(m, ob)
                DeleteObject(p)
            case .text(let s, let r, let f, let c, let flags):
                let of = SelectObject(m, hfont(f))
                SetTextColor(m, Ink.ref(c))
                var rr = r
                let w = Array(s.utf16)
                _ = DrawTextW(m, w, Int32(w.count), &rr, flags)
                SelectObject(m, of)
            case .dots(let centres, let d, let c):
                let b = CreateSolidBrush(Ink.ref(c))
                let ob = SelectObject(m, b), op = SelectObject(m, nullPen)
                // GDI draws no outline-less ellipse a few pixels across: small dots are squares, as the LEDs of a screen
                if d < 4 { for (x, y) in centres { var r = RECT(left: x, top: y, right: x + d, bottom: y + d); FillRect(m, &r, b) } }
                else { for (x, y) in centres { Ellipse(m, x, y, x + d + 1, y + d + 1) } }
                SelectObject(m, ob); SelectObject(m, op)
                DeleteObject(b)
            case .ellipse(let r, let c):
                let b = CreateSolidBrush(Ink.ref(c))
                let ob = SelectObject(m, b), op = SelectObject(m, nullPen)
                Ellipse(m, r.left, r.top, r.right + 1, r.bottom + 1)
                SelectObject(m, ob); SelectObject(m, op)
                DeleteObject(b)
            }
        }
        BitBlt(dc, 0, 0, size.w, size.h, m, 0, 0, 0x00CC_0020)          // SRCCOPY
    }
}
#endif
