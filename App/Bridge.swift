import CoreMIDI
import Foundation
import OPZLink
import OPZPlay
import os

/// Other controllers straight through to the OP-Z: notes, knobs, wheels and pressure, as they come, on CoreMIDI's own
/// thread (never waiting for the screen). What has been learned, and what is being learned, is left to Controllers.
final class Bridge: Sendable {
    /// Where a controller's messages go.
    enum Route: Codable, Hashable, Sendable {
        case off
        /// The track selected on the OP-Z (or here).
        case selected
        case track(Int)
        /// Channel 1 to track 1 and so on, as the controller sends them.
        case asSent
    }

    private struct Held: Hashable { let device: String, channel: Int, note: Int }
    private struct State {
        var routes: [String: Route] = [:]
        var fallback = Route.off
        var track = 0
        var destination = MIDIEndpointRef()
        var channels = Array(0..<16)
        var learned: Set<Control> = []
        var keys: Set<String> = []
        var learning = false
        /// Each note that is down: the track it went to, so it is let go there even if the track changed since.
        var held: [Held: Int] = [:]
    }
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let port: MIDIPortRef

    init(client: MIDIClientRef) {
        var p = MIDIPortRef()
        MIDIOutputPortCreate(client, "Galax-z Bridge" as CFString, &p)
        port = p
    }

    // MARK: told by the app (main thread)

    func set(routes: [String: Route], fallback: Route) {
        state.withLock { s in
            for (h, t) in s.held where (routes[h.device] ?? fallback) != (s.routes[h.device] ?? s.fallback) {
                send(s, [0x80 | UInt8(s.channels[t]), UInt8(h.note), 0])
                s.held[h] = nil
            }
            s.routes = routes
            s.fallback = fallback
        }
    }

    func set(track t: Int) { state.withLock { $0.track = max(0, min(15, t)) } }

    /// The OP-Z to send to (0: none) and its tracks' channels.
    func set(opz destination: MIDIEndpointRef, channels: [Int]?) {
        let channels = channels?.count == 16 ? channels! : Array(0..<16)
        state.withLock { s in
            guard s.destination != destination || s.channels != channels else { return }
            if s.destination != destination { s.held = [:] }
            s.destination = destination
            s.channels = channels
        }
    }

    func set(learned: Learned) {
        let keys = learned.entries.filter { $0.target == .keys }
        state.withLock { s in
            s.learned = Set(learned.entries.filter { $0.target != .keys }.map(\.control))
            s.keys = Set(keys.map { "\($0.control.device)\u{0}\($0.control.channel)" })
            s.learning = learned.waiting != nil
        }
    }

    // MARK: on CoreMIDI's thread

    /// A channel message from `device`: sent to the OP-Z if it is the bridge's. The track it went to, or nil.
    func forward(_ device: String, _ status: UInt8, _ a: Int, _ b: Int) -> Int? {
        let kind = status & 0xF0, channel = Int(status & 15)
        guard kind >= 0x80, kind < 0xF0 else { return nil }
        let note = kind == 0x80 || kind == 0x90, off = kind == 0x80 || (kind == 0x90 && b == 0)
        return state.withLock { s -> Int? in
            guard s.destination != 0, !s.learning else { return nil }
            if note, s.keys.contains("\(device)\u{0}\(channel)") { return nil }
            if note || kind == 0xB0, s.learned.contains(Control(device: device, channel: channel, kind: note ? .note : .cc, number: a)) { return nil }
            let h = Held(device: device, channel: channel, note: a)
            let t: Int
            if note, off, let was = s.held.removeValue(forKey: h) {
                t = was
            } else {
                switch s.routes[device] ?? s.fallback {
                case .off: return nil
                case .selected: t = s.track
                case .track(let n): t = max(0, min(15, n))
                case .asSent: t = channel
                }
                if note, !off { s.held[h] = t }
            }
            let out = kind | UInt8(s.channels[t])
            send(s, kind == 0xC0 || kind == 0xD0 ? [out, UInt8(a)] : [out, UInt8(a), UInt8(b)])
            return t
        }
    }

    private func send(_ s: State, _ bytes: [UInt8]) {
        guard s.destination != 0, var word = MIDITransport.umpWord(bytes) else { return }
        var list = MIDIEventList()
        let packet = MIDIEventListInit(&list, ._1_0)
        _ = MIDIEventListAdd(&list, MemoryLayout<MIDIEventList>.size, packet, 0, 1, &word)
        MIDISendEventList(port, s.destination, &list)
    }
}
