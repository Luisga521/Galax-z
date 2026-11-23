import CoreMIDI
import Foundation
import Observation
import OPZLink
import OPZModel
import OPZPlay
import OPZStage

/// Every MIDI controller that is not the OP-Z: what its knobs, pads and keys do, as learned.
@MainActor @Observable
final class Controllers {
    private(set) var learned: Learned { didSet { if learned.entries != oldValue.entries, let d = try? JSONEncoder().encode(learned) { UserDefaults.standard.set(d, forKey: "learned") } } }
    /// Their names, and what was moved last.
    private(set) var devices: [String] = []
    private(set) var last: String?

    @ObservationIgnored weak var stage: Stage?
    @ObservationIgnored var changed: () -> Void = {}
    @ObservationIgnored private var client = MIDIClientRef()
    @ObservationIgnored private var ports: [MIDIEndpointRef: (port: MIDIPortRef, name: String)] = [:]
    private struct Heard: Sendable { let device: String, status: UInt8, a: Int, b: Int }
    @ObservationIgnored private let into: AsyncStream<Heard>.Continuation

    init() {
        learned = UserDefaults.standard.data(forKey: "learned").flatMap { try? JSONDecoder().decode(Learned.self, from: $0) } ?? Learned()
        let (heard, into) = AsyncStream.makeStream(of: Heard.self, bufferingPolicy: .bufferingNewest(1024))
        self.into = into
        MIDIClientCreateWithBlock("Galax-z controllers" as CFString, &client, Self.notify { [weak self] in self?.look() })
        look()
        Task { [weak self] in for await h in heard { self?.take(h) } }
    }

    // (made outside the main actor: CoreMIDI calls them on its own threads)
    nonisolated private static func notify(_ changed: @escaping @MainActor @Sendable () -> Void) -> MIDINotifyBlock {
        { n in guard n.pointee.messageID == .msgSetupChanged else { return }; Task { @MainActor in changed() } }
    }
    nonisolated private static func receive(_ name: String, _ into: AsyncStream<Heard>.Continuation) -> MIDIReceiveBlock {
        { list, _ in
            for p in list.unsafeSequence() {
                let n = Int(p.pointee.wordCount)
                withUnsafeBytes(of: p.pointee.words) { raw in
                    let w = raw.bindMemory(to: UInt32.self)
                    var i = 0
                    while i < n, i < w.count {
                        let type = Int(w[i] >> 28)
                        if type == 2 { into.yield(Heard(device: name, status: UInt8(w[i] >> 16 & 255), a: Int(w[i] >> 8 & 127), b: Int(w[i] & 127))) }
                        i += [1, 1, 1, 2, 2, 4, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4][type]
                    }
                }
            }
        }
    }

    /// Listen to every source but the OP-Z (and what this Mac makes itself).
    private func look() {
        var now: [MIDIEndpointRef: String] = [:]
        for i in 0..<MIDIGetNumberOfSources() {
            let s = MIDIGetSource(i)
            var cf: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(s, kMIDIPropertyDisplayName, &cf)
            let name = cf?.takeRetainedValue() as String? ?? ""
            let low = name.lowercased()
            if s != 0, !name.isEmpty, !low.contains("op-z"), !low.contains("galax-z"), !low.contains("iac") { now[s] = name }
        }
        for (s, p) in ports where now[s] == nil { MIDIPortDispose(p.port); ports[s] = nil }
        for (s, name) in now where ports[s] == nil {
            var port = MIDIPortRef()
            guard MIDIInputPortCreateWithProtocol(client, name as CFString, ._1_0, &port, Self.receive(name, into)) == noErr else { continue }
            MIDIPortConnectSource(port, s, nil)
            ports[s] = (port, name)
        }
        devices = Array(Set(now.values)).sorted()
    }

    private func take(_ h: Heard) {
        guard let stage else { return }
        let channel = Int(h.status & 15)
        let c: Control, v: Int
        switch h.status & 0xF0 {
        case 0x90: (c, v) = (Control(device: h.device, channel: channel, kind: .note, number: h.a), h.b)
        case 0x80: (c, v) = (Control(device: h.device, channel: channel, kind: .note, number: h.a), 0)
        case 0xB0 where h.a < 120: (c, v) = (Control(device: h.device, channel: channel, kind: .cc, number: h.a), h.b)
        default: return
        }
        if learned.waiting != nil || v > 0 { last = "\(h.device): \(c.name) = \(v)" }
        // keys: a whole keyboard, but for the pads that were given something of their own
        if c.kind == .note, learned.waiting == nil, learned.entry(c) == nil || learned.entry(c)?.target == .keys,
           learned.entries.contains(where: { $0.target == .keys && $0.control.device == h.device && $0.control.channel == channel }) {
            v > 0 ? stage.keyDown(c.number, velocity: v) : stage.keyUp(c.number)
            return changed()
        }
        switch learned.moved(c, v, now: { stage.value(of: $0) }) {
        case .set(let t, let x): stage.set(t, to: x)
        case .press(let t, let velocity): _ = stage.press(t, velocity: velocity)
        case .release(let t): _ = stage.press(t, velocity: 0)
        case .learned, .none: return
        }
        changed()
    }

    func learn(_ t: Target?) { learned.learn(learned.waiting == t ? nil : t) }
    func forget(_ c: Control) { learned.forget(c) }
    func forgetAll() { learned.forgetAll() }
    func set(_ way: Learned.Way, for c: Control) { learned.set(way, for: c) }
}
