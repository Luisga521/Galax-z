import OPZLink
import OPZModel

/// The demo OP-Z, by the clock rather than by tasks: `DemoPort` (OPZLink) as Android drives it, from `Core.tick`.
/// Plays at the demo song's tempo, tells of a tumbler and an EUCLID, and turns some dials now and then.
final class Demo {
    private let core = DemoOPZCore.bundled()
    private let start: Double
    private let bpm = 124
    private var pending: [(at: Double, frame: [UInt8])] = []
    private var step = 0, nextStep: Double
    private var machines = DemoMachines(), turn = 0, nextMachine: Double
    private var sound: [[UInt8]] = []
    private var dialsAt: Double, sweeps = 0

    init(now: Double) {
        start = now
        nextStep = now
        nextMachine = now + 0.04
        dialsAt = now + 3
    }

    /// A frame from the app: the demo's answers come 12 ms later, like a cable's.
    func send(_ sysex: [UInt8], now: Double) {
        for r in core.receive(sysex, now: now - start) { pending.append((now + 0.012, r)) }
    }

    /// Everything the demo has said by now. `bank` is the project as the app has read it, for the dials.
    func due(now: Double, bank: Bank?) -> [[UInt8]] {
        let beat = 15.0 / Double(max(40, bpm))
        while nextStep <= now {
            if step % 256 == 0 { pending.append((nextStep, SysEx.frame(0x03, [0, 0x14]))) }
            if step % 16 == 0 { pending.append((nextStep, SysEx.frame(0x05, [UInt8](repeating: 0, count: 16) + [0]))) }
            step += 1
            nextStep += beat
        }
        while nextMachine <= now {
            machines.step(0.04, bpm: bpm)
            let m = machines.machines.messages
            if turn % 25 == 0 { pending.append((nextMachine, SysEx.frame(0x70, m[0]))) }
            pending.append((nextMachine, SysEx.frame(0x71, m[1])))
            turn += 1
            nextMachine += 0.04
        }
        if dialsAt <= now, let bank { dials(bank) }
        pending.sort { $0.at < $1.at }
        let cut = pending.firstIndex { $0.at > now } ?? pending.count
        defer { pending.removeFirst(cut) }
        return pending[..<cut].map(\.frame)
    }

    /// Someone at the dials: sends to the two effects, then every few seconds a filter or a level swept and back.
    private func dials(_ bank: Bank) {
        func turn(_ t: Int, at: Double) { pending.append((at, SysEx.frame(0x0E, [UInt8(t)] + sound[t]))) }
        if sound.isEmpty {
            sound = (0..<8).map { bank.sound(0, $0).map { UInt8(clamping: $0) } }
            for (t, (a, b)) in [(0, 24), (70, 0), (40, 110), (90, 60), (0, 30), (120, 90), (170, 60), (60, 190)].enumerated() {
                sound[t][6] = UInt8(a)
                sound[t][7] = UInt8(b)
                turn(t, at: dialsAt)
            }
            dialsAt += 4
            return
        }
        let (t, dial) = [(5, 8), (7, 7), (6, 6), (4, 0)][sweeps % 4], from = Int(sound[t][dial])
        for i in 0...40 {
            let f = Double(i <= 20 ? i : 40 - i) / 20
            sound[t][dial] = UInt8(max(0, min(255, Double(from) + (from > 127 ? -110 : 110) * f * f * (3 - 2 * f))))
            turn(t, at: dialsAt + Double(i) * 0.04)
        }
        sweeps += 1
        dialsAt += 41 * 0.04 + 4
    }
}
