#if canImport(CoreMIDI)
// galaxz-probe: run Galax-z's own protocol code against an OP-Z on this Mac (USB or Bluetooth) and print what the app
// would show: the active pattern, and every track's sound by name and slot. Read-only: StateSync hellos and acks,
// and a file-service pull of the two settings files.
//
//   swift run --package-path Packages/GalaxzKit galaxz-probe
//
// Close Galax-z on the iPad and TE's app first: two clients on one OP-Z break both.

import Foundation
import OPZLink
import OPZModel

@MainActor
enum Probe {
    static let started = ProcessInfo.processInfo.systemUptime
    static func now() -> Double { ProcessInfo.processInfo.systemUptime - started }

    static func run() async -> Int32 {
        let midi = MIDITransport()
        guard midi.connectToOPZ(), let connection = midi.connection else {
            print("no OP-Z in CoreMIDI")
            return 1
        }
        print("connected: \(connection.name) over \(connection.transport)")
        let state = StateSyncClient()
        let files = FileClient()
        state.log = { print("statesync:", $0) }
        files.log = { print("files:", $0) }
        func send(_ frames: [[UInt8]]) { frames.forEach(midi.send) }

        let reader = Task { @MainActor in
            for await frame in midi.frames {
                send(state.receive(frame, now: now()) + files.receive(frame, now: now()))
            }
        }
        defer { reader.cancel() }
        send(state.tick(now: now(), forceHello: true))
        var filesStarted = false
        while now() < 30 {
            if case .done = files.phase { break }
            if case .failed = files.phase { break }
            try? await Task.sleep(for: .milliseconds(50))
            send(state.tick(now: now()) + files.tick(now: now()))
            if state.bank != nil, state.partsIncoming == nil, !filesStarted {
                filesStarted = true
                send(files.start(now: now()))
            }
        }

        guard let bank = state.bank, let address = state.playAddress ?? state.bankAddress else {
            print("no pattern bank from the OP-Z (is TE's app or Galax-z on the iPad connected?)")
            return 1
        }
        print("project \(address.project + 1), pattern \(address.pattern + 1), \(state.global?.tempo ?? 0) BPM")
        guard case .done = files.phase, let p = files.files[FileClient.plugs],
              let s = files.files[FileClient.slotConfiguration],
              let settings = OPZSettings(plugsJSON: p, slotsJSON: s) else {
            print("settings not read: \(files.phase)")
            return 1
        }
        print("\(settings.plugs.count) sounds on the OP-Z, state CRC \(String(format: "%08x", files.stateCrc ?? 0))")
        func pad(_ s: String, _ n: Int) -> String { s.padding(toLength: n, withPad: " ", startingAt: 0) }
        for t in 0..<OPZ.tracks {
            let plug = Int(bank.track(address.pattern, t).plug)
            let sound = Sound(plug: plug, settings: settings)
            let slot = sound.flatMap { settings.slot(of: $0.plug, track: t) }.map { "slot \($0)" } ?? "-"
            let knobs = sound?.engine.map { "  P1 \($0.p1?.name ?? "?") · P2 \($0.p2?.name ?? "?")" } ?? ""
            print(pad(OPZ.trackNames[t], 8), pad(String(plug), 7), pad(sound?.name ?? "—", 16), pad(slot, 8) + knobs)
        }
        for t in [0, 4, 8, 9] {
            let names = (1...10).map { k in
                settings.slots[t]?[k].flatMap { Sound(plug: $0, settings: settings)?.name } ?? "·"
            }
            print("\(pad(OPZ.trackNames[t], 5)) slots: \(names.joined(separator: " | "))")
        }
        return 0
    }
}

exit(await Probe.run())
#else
print("galaxz-probe needs a Mac for now (CoreMIDI, CoreGraphics)")
#endif
