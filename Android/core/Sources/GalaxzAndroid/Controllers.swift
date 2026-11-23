import Foundation
import OPZLink
import OPZModel
import OPZPlay
import OPZStage

/// Every MIDI controller that is not the OP-Z: what its knobs, pads and keys do, as learned (`App/Controllers.swift`).
/// The Kotlin side opens them and hands their bytes over by name.
final class Controllers {
    private(set) var learned: Learned
    /// Their names, and what was moved last.
    var devices: [String] = []
    private(set) var last: String?
    weak var stage: Stage?
    var changed: () -> Void = {}
    private let file: URL
    private var readers: [String: MIDIBytes] = [:]

    init(folder: URL) {
        file = folder.appendingPathComponent("learned.json")
        learned = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(Learned.self, from: $0) } ?? Learned()
    }

    private func keep() { try? (try? JSONEncoder().encode(learned))?.write(to: file, options: .atomic) }

    func midi(_ device: String, _ bytes: UnsafeBufferPointer<UInt8>) {
        var r = readers[device] ?? MIDIBytes()
        r.feed(bytes, time: monotonic(), frame: { _ in }, key: { e in
            switch e {
            case .noteOn(let n, let ch, let v, _): take(device, ch, .note, n, v)
            case .noteOff(let n, let ch, _): take(device, ch, .note, n, 0)
            case .cc(let n, let v, let ch) where n < 120: take(device, ch, .cc, n, v)
            default: break
            }
        })
        readers[device] = r
    }

    private func take(_ device: String, _ channel: Int, _ kind: Control.Kind, _ number: Int, _ v: Int) {
        guard let stage else { return }
        let c = Control(device: device, channel: channel, kind: kind, number: number)
        if learned.waiting != nil || v > 0 { last = "\(device): \(c.name) = \(v)" }
        // keys: a whole keyboard, but for the pads that were given something of their own
        if c.kind == .note, learned.waiting == nil, learned.entry(c) == nil || learned.entry(c)?.target == .keys,
           learned.entries.contains(where: { $0.target == .keys && $0.control.device == device && $0.control.channel == channel }) {
            v > 0 ? stage.keyDown(c.number, velocity: v) : stage.keyUp(c.number)
            return changed()
        }
        let before = learned.entries
        switch learned.moved(c, v, now: { stage.value(of: $0) }) {
        case .set(let t, let x): stage.set(t, to: x)
        case .press(let t, let velocity): _ = stage.press(t, velocity: velocity)
        case .release(let t): _ = stage.press(t, velocity: 0)
        case .learned, .none: break
        }
        if learned.entries != before { keep() }
        changed()
    }

    func learn(_ t: Target?) { learned.learn(learned.waiting == t ? nil : t); changed() }
    func forget(_ c: Control) { learned.forget(c); keep(); changed() }
    func forgetAll() { learned.forgetAll(); keep(); changed() }
    func set(_ way: Learned.Way, for c: Control) { learned.set(way, for: c); keep(); changed() }

    /// What LEARN shows for a kind of thing (SOUND, MIX, PERFORM, CHOPS, PATTERNS, KEYS) and a track (nil: the selected).
    static func targets(_ family: Int, track: Int?) -> [Target] {
        switch family {
        case 0: OPZ.params.indices.map { .sound(track: track, param: $0) }
        case 1: [.gain(track: track), .mute(track: track), .sound(track: track, param: 10), .sound(track: track, param: 6), .sound(track: track, param: 7)]
            + (track == nil ? (0..<8).map { .gain(track: $0) } + (0..<8).map { .mute(track: $0) } : [])
        case 2: (0..<PerformBay.pads).map { .move(pad: $0) }
        case 3: (0..<8).map { .chopDial($0) } + (0..<24).map { .chop($0) }
        case 4: [.play, .previousPattern, .nextPattern] + (0..<16).map { .pattern($0) }
        default: [.keys, .page(by: -1), .page(by: 1)] + (0..<16).map { .select(track: $0) }
        }
    }
}
