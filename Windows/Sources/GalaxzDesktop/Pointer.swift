import GalaxzAndroid

/// A mouse (or a touch screen, which Windows turns into one) on the dots, as `DotView.onTouchEvent` handles a finger:
/// a press on something that holds (a pad, a fader) is grabbed and dragged; otherwise a short press is a tap, and a long
/// sideways drag turns the page.
public final class Pointer {
    let core: DesktopCore
    /// Pixels per 1/96 inch (the window's DPI ÷ 96): how far is far.
    public var scale = 1.0
    private var finger: Int?
    private var start: (x: Double, y: Double)?
    private var fingers = 0

    public init(_ core: DesktopCore) { self.core = core }

    public var held: Bool { finger != nil }

    public func down(_ x: Double, _ y: Double, _ layout: DotRenderer.Layout) {
        cancel()
        let d = layout.dot(x, y)
        fingers += 1
        if core.grab(fingers, d.x, d.y) { finger = fingers } else { start = (x, y) }
    }

    public func move(_ x: Double, _ y: Double, _ layout: DotRenderer.Layout) {
        guard let f = finger else { return }
        let d = layout.dot(x, y)
        core.drag(f, d.x, d.y)
    }

    /// What the press asks the app for, if it was a tap.
    public func up(_ x: Double, _ y: Double, _ layout: DotRenderer.Layout) -> DesktopCore.Action {
        let d = layout.dot(x, y)
        if let f = finger {
            finger = nil
            core.release(f, d.x, d.y)
            return .none
        }
        guard let s = start else { return .none }
        start = nil
        let dx = x - s.x, dy = y - s.y
        if abs(dx) > 48 * scale && abs(dx) > 2 * abs(dy) {          // a swipe: the next page
            core.turn(dx < 0 ? 1 : -1)
            return .none
        }
        guard (dx * dx + dy * dy).squareRoot() < 16 * scale else { return .none }
        return core.tap(d.x, d.y)
    }

    /// The mouse went away (the window lost it): let go of what is held.
    public func cancel() {
        if let f = finger { core.release(f, -1000, -1000) }
        finger = nil
        start = nil
    }
}
