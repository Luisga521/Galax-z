import Foundation
import OPZModel
import OPZStage

/// The core for an app written in Swift around it (Galax-z for Windows): what `JNI.swift` gives the Kotlin app, as Swift
/// calls. The window, the MIDI and the sound come from different threads, so every call holds one lock, as there.
public final class DesktopCore: @unchecked Sendable {
    /// A tap that asks the app for something (`Stage.Action`).
    public enum Action: Sendable { case none, hub, settings, pair, sound }

    private let lock = NSLock()
    private let core: Core

    /// `folder`: where the app keeps its settings; `files`: where the package's own files are (engines.json,
    /// demo-session.json), copied beside the app (nil: SwiftPM's bundles).
    public init(folder: URL, files: URL?, demo: Bool) {
        if let files { PackageFiles.folder = files }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        core = Core(folder: folder, demo: demo)
    }

    private func locked<T>(_ body: (Core) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(core)
    }

    /// Seconds of the clock MIDI times are counted in.
    public static func now() -> Double { monotonic() }

    // MARK: the screen

    /// Every 16 ms or so; true when there is something new to draw.
    public func tick() -> Bool { locked { c in c.tick(); defer { c.changed = false }; return c.changed } }

    /// Draw a frame of `w` × `h` dots into `dots` (RGBA, 4 bytes a dot). Whether the picture is still, whether the OP-Z plays.
    public func frame(_ w: Int, _ h: Int, time: Double, dt: Double, into dots: inout [UInt8]) -> (still: Bool, playing: Bool) {
        guard w > 0, h > 0 else { return (true, false) }
        if dots.count != w * h * 4 { dots = [UInt8](repeating: 0, count: w * h * 4) }
        return locked { c in
            c.canvas.resize(w, h)
            c.stage.frame(c.canvas, time: time, dt: dt)
            dots.withUnsafeMutableBytes { $0.copyMemory(from: UnsafeRawBufferPointer(start: c.canvas.dots, count: w * h * 4)) }
            return (c.stage.still, c.stage.playhead.playing)
        }
    }

    /// The page and what is on it, in words (for a screen reader).
    public var spoken: String { locked { $0.stage.spoken } }

    // MARK: the OP-Z

    /// Bytes from the OP-Z, at `time` (seconds, `now()`'s clock).
    public func midiIn(_ bytes: [UInt8], at time: Double) {
        guard !bytes.isEmpty else { return }
        locked { c in bytes.withUnsafeBufferPointer { c.midi($0, at: time) } }
    }

    /// The app opened an OP-Z (its name), or has none (nil); `bluetooth`: over Bluetooth MIDI, not a cable.
    public func connected(_ name: String?, bluetooth: Bool = false) { locked { $0.connected(name, bluetooth: bluetooth) } }

    /// PAIR on the SKY page, with how to find an OP-Z under the name (the Mac's `Live.offerPairing`).
    public func offerPairing(_ on: Bool) {
        locked { c in
            guard c.stage.showsPairing != on else { return }
            c.stage.showsPairing = on
            c.linkHint = on ? "SWITCH IT ON AND PAIR IT, OR PLUG IN A CABLE" : ""
            c.changed = true
        }
    }

    /// What to send: SysEx at once (time 0), short messages at their time (seconds, `now()`'s clock).
    public func takeOutgoing() -> [(at: Double, bytes: [UInt8])] { locked { $0.takeOutgoing() } }

    /// What to do while there is no OP-Z, said under the name.
    public func linkLine(_ line: String, hint: String = "") { locked { c in c.linkLine = line; c.linkHint = hint } }

    public func useDemo(_ on: Bool) { locked { $0.useDemo(on) } }
    public var isDemo: Bool { locked { $0.source == .demo } }
    public func reload() { locked { $0.reload() } }

    /// Bytes from a controller that is not the OP-Z, by its name.
    public func controllerIn(_ name: String, _ bytes: [UInt8]) {
        guard !bytes.isEmpty else { return }
        locked { c in bytes.withUnsafeBufferPointer { c.controllers.midi(name, $0) } }
    }

    // MARK: touch, in dots as the screen lays them out

    public func tap(_ x: Int, _ y: Int) -> Action {
        locked { c in
            c.changed = true
            switch c.stage.tap(x, y) {
            case .none: return .none
            case .hub: return .hub
            case .settings: return .settings
            case .pair: return .pair
            case .sound: return .sound
            }
        }
    }

    public func holds(_ x: Int, _ y: Int) -> Bool { locked { $0.stage.holds(x, y) } }
    public func grab(_ id: Int, _ x: Int, _ y: Int) -> Bool { locked { c in c.changed = true; return c.stage.grab(id, x, y) } }
    public func drag(_ id: Int, _ x: Int, _ y: Int) { locked { c in c.changed = true; c.stage.drag(id, x, y) } }
    public func release(_ id: Int, _ x: Int, _ y: Int) { locked { c in c.changed = true; c.stage.release(id, x, y) } }
    /// Let go of everything held (the window was covered or lost the mouse).
    public func letGo() { locked { c in c.changed = true; c.stage.letGo() } }

    /// Pages: turn by one (a swipe, an arrow key).
    public func turn(_ by: Int) { locked { c in c.changed = true; c.stage.turn(by) } }
    public func setPage(_ i: Int) {
        locked { c in
            guard let p = Stage.Page(rawValue: i) else { return }
            c.changed = true
            c.stage.page = p
        }
    }
    public func selectTrack(_ by: Int) { locked { c in c.changed = true; c.stage.select(track: c.stage.track + by) } }

    // MARK: Settings, the key test, LEARN (`Settings.swift`): JSON out, a word and an argument in

    public func query(_ what: String) -> String { locked { $0.query(what) } }
    @discardableResult public func command(_ what: String, _ arg: String = "") -> String { locked { $0.command(what, arg) } }
}
