import Foundation
import OPZModel

/// A pretend OP-Z for demo mode and for building screens with no unit attached. It plays back what op-free's fake
/// OP-Z sent (`Tools/fixtures/make-fixtures.mjs`): `$01` to every hello; on the first hello of a session `$07`, `$0C`
/// and bank part 0, each further part only after its ack, like the real one; and its file service: `$34` to an
/// advert, a settings file's `$53` parts to a `$35`.
public final class DemoOPZCore {
    private let ack: [UInt8]
    private let burst: [[UInt8]]
    private let parts: [[UInt8]]
    private let fileOpen: [UInt8]?
    /// file id → its `$53` parts in order
    private let fileParts: [UInt32: [[UInt8]]]
    private var next = 0
    private var lastHello = -Double.infinity

    public init(frames: [[UInt8]], files: [[UInt8]] = []) {
        func id(_ raw: [UInt8]) -> UInt8? { (try? SysEx.decode(raw))?.id }
        ack = frames.first { id($0) == 0x01 } ?? []
        burst = frames.filter { id($0) == 0x07 || id($0) == 0x0C }
        parts = frames.filter { id($0) == 0x09 || id($0) == 0x0A }
        fileOpen = files.first { id($0) == 0x34 }
        var byFile: [UInt32: [[UInt8]]] = [:]
        for raw in files {
            guard let f = try? SysEx.decode(raw), f.id == 0x53, f.payload.count >= 9 else { continue }
            let fid = (0..<4).reduce(UInt32(0)) { $0 | UInt32(f.payload[2 + $1]) << (8 * $1) }
            byFile[fid, default: []].append(raw)
        }
        fileParts = byFile
    }

    /// The project it has.
    var bank: Bank? {
        let z = parts.compactMap { try? SysEx.decode($0) }.flatMap { $0.payload.dropFirst(6) }
        return Zlib.inflate(z, size: OPZ.bankSize).flatMap(Bank.init)
    }

    /// The bundled demo song.
    public static func bundled() -> DemoOPZCore {
        struct File: Decodable { let frames: [String]; let files: [String]? }
        guard let url = PackageFiles.url("demo-session", "json", bundle: { Bundle.module }),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return DemoOPZCore(frames: []) }
        return DemoOPZCore(frames: file.frames.map(Self.bytes), files: (file.files ?? []).map(Self.bytes))
    }

    /// What the OP-Z sends back for one host frame.
    public func receive(_ raw: [UInt8], now: Double) -> [[UInt8]] {
        guard let f = try? SysEx.decode(raw) else { return [] }
        switch f.id {
        case 0x00:
            let fresh = now - lastHello > 5
            lastHello = now
            guard fresh else { return [ack] }
            next = 0
            return [ack] + burst + sendPart()
        case 0x08 where now - lastHello <= 5:
            next = 0
            return sendPart()
        case 0x0B where f.payload.count == 8 && now - lastHello <= 5:
            let index = Int(f.payload[6]) | Int(f.payload[7]) << 8
            return index == next - 1 ? sendPart() : []
        case 0x51:
            return fileOpen.map { [$0] } ?? []
        case 0x35 where f.payload.count == 8:
            let fid = (0..<4).reduce(UInt32(0)) { $0 | UInt32(f.payload[2 + $1]) << (8 * $1) }
            let from = Int(f.payload[6]) | Int(f.payload[7]) << 8
            return Array((fileParts[fid] ?? []).dropFirst(from)) // the file service streams every part from there
        default:
            return []
        }
    }

    private func sendPart() -> [[UInt8]] {
        guard next < parts.count else { return [] }
        defer { next += 1 }
        return [parts[next]]
    }

    static func bytes(_ hex: String) -> [UInt8] {
        var out: [UInt8] = []
        var i = hex.startIndex
        while let j = hex.index(i, offsetBy: 2, limitedBy: hex.endIndex), i < hex.endIndex {
            out.append(UInt8(hex[i..<j], radix: 16) ?? 0)
            i = j
        }
        return out
    }
}

/// The demo OP-Z as a port: replies arrive a little later, part by part, like a cable.
@MainActor
public final class DemoPort: OPZPort {
    public let frames: AsyncStream<[UInt8]>
    private let continuation: AsyncStream<[UInt8]>.Continuation
    private let core = DemoOPZCore.bundled()
    private let start = Date()
    private var player: Task<Void, Never>?
    private var machinist: Task<Void, Never>?
    private var hand: Task<Void, Never>?

    public init() {
        (frames, continuation) = AsyncStream.makeStream(of: [UInt8].self)
    }

    /// Play: the panel messages an OP-Z sends while its sequencer runs, at the demo song's tempo.
    public func play(bpm: Int = 124) {
        player?.cancel()
        let continuation = self.continuation
        player = Task { @MainActor in
            var step = 0
            while !Task.isCancelled {
                if step % 256 == 0 { continuation.yield(SysEx.frame(0x03, [0, 0x14])) }
                // as the OP-Z does: where it is, once a pattern
                if step % 16 == 0 { continuation.yield(SysEx.frame(0x05, [UInt8](repeating: 0, count: 16) + [0])) }
                step += 1
                try? await Task.sleep(for: .microseconds(15_000_000 / max(40, bpm)))
            }
        }
    }

    /// A tumbler and an EUCLID on the bass, as Galax-z OS v10 tells of them.
    public func machines(bpm: Int = 124) {
        machinist?.cancel()
        let continuation = self.continuation
        machinist = Task { @MainActor in
            var demo = DemoMachines()
            var turn = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(40))
                demo.step(0.04, bpm: bpm)
                let m = demo.machines.messages
                if turn % 25 == 0 { continuation.yield(SysEx.frame(0x70, m[0])) }
                continuation.yield(SysEx.frame(0x71, m[1]))
                turn += 1
            }
        }
    }

    /// Someone at the dials: sends to the two effects, and now and then a filter swept.
    public func dials() {
        guard let bank = core.bank else { return }
        hand?.cancel()
        let continuation = self.continuation
        hand = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            var sound = (0..<8).map { bank.sound(0, $0).map { UInt8(clamping: $0) } }
            func turn(_ t: Int) { continuation.yield(SysEx.frame(0x0E, [UInt8(t)] + sound[t])) }
            for (t, (a, b)) in [(0, 24), (70, 0), (40, 110), (90, 60), (0, 30), (120, 90), (170, 60), (60, 190)].enumerated() {
                sound[t][6] = UInt8(a)
                sound[t][7] = UInt8(b)
                if !Task.isCancelled { turn(t) }
            }
            var n = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                let (t, dial) = [(5, 8), (7, 7), (6, 6), (4, 0)][n % 4], from = Int(sound[t][dial])
                for i in 0...40 where !Task.isCancelled {
                    let f = Double(i <= 20 ? i : 40 - i) / 20
                    sound[t][dial] = UInt8(max(0, min(255, Double(from) + (from > 127 ? -110 : 110) * f * f * (3 - 2 * f))))
                    turn(t)
                    try? await Task.sleep(for: .milliseconds(40))
                }
                n += 1
            }
        }
    }

    public func stop() {
        for t in [player, machinist, hand] { t?.cancel() }
        (player, machinist, hand) = (nil, nil, nil)
    }

    public func send(_ sysex: [UInt8]) {
        let replies = core.receive(sysex, now: Date().timeIntervalSince(start))
        guard !replies.isEmpty else { return }
        let continuation = self.continuation
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(12))
            for r in replies { continuation.yield(r) }
        }
    }
}

/// The demo's tumbler and EUCLID.
public struct DemoMachines: Sendable {
    public private(set) var machines = Machines()
    private var tombola = Tombola()
    private var time = 0.0

    public init(track: Int = 4) {
        machines.track = track
        (machines.tumbling, machines.latched) = (UInt8(1 << track), UInt8(1 << track) | 1)
        machines.dials = [90, 190, 110, 38, 220, 90, 0, 153, 128, 77, 255, 0]
        machines.rings = [36, 43, 48, 51].map { Machines.Ring(key: $0, steps: 16, pulses: 4, rotation: 0) }
        tombola.balls = [(0.1, -0.3, 60), (-0.2, -0.1, 63), (0.25, 0.1, 67), (-0.05, 0.2, 70), (0, -0.5, 72)]
            .map { Machines.Ball(x: $0.0, y: $0.1, vx: 1.1 * $0.0, vy: 0.2, note: $0.2) }
    }

    public mutating func step(_ dt: Double, bpm: Int = 124) {
        time += dt
        tombola.step(dt, dials: machines.dials)
        // one that came to rest is thrown up again, so that the demo goes on
        for i in tombola.balls.indices where tombola.balls[i].flash == 0 && abs(tombola.balls[i].vx) + abs(tombola.balls[i].vy) < 0.4 && tombola.balls[i].y > 0.3 {
            tombola.balls[i].vy = -2.6 - 0.2 * Double(i)
            tombola.balls[i].vx = i % 2 == 0 ? 0.8 : -0.8
        }
        machines.balls = tombola.balls
        machines.turn = tombola.turn
        machines.steps = Int(time * Double(bpm) / 15)
        machines.told &+= 1
    }
}
