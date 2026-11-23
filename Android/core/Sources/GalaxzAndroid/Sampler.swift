import ChopKit
import Foundation
import OPZStage

/// The chops on this phone: their sound, what is recorded and opened, the kits kept (`files/Chops`). `App/Sampler.swift`
/// for Android: the same kits, the same words on the screen; AAudio for the sound (`ChopsAudio.swift`), the Kotlin side
/// for opening files and for the microphone's permission.
final class Sampler {
    weak var stage: Stage?
    var changed: () -> Void = {}
    /// Wanted of the Kotlin side: a file to open, the microphone allowed.
    private(set) var wantsFile = false, wantsMicrophone = false

    /// The devices to use, as the Kotlin side has found them (0: Android's default).
    struct Devices: Equatable { var output: Int32 = 0, microphone: Int32 = 0, opz: Int32 = 0, allowed = false }
    var devices = Devices() { didSet { if devices.output != oldValue.output, out != nil { out?.stop(); out = nil; chops?.silence() } } }

    private let folder: URL
    private var chops: ChopEngine?
    private var out: ChopsOut?
    private var kit = SungVoice.kit
    private var kits: [URL?] = [nil]                    // nil: VOX
    private var at = 0
    /// A recording as it was made, to be cut again.
    private var raw: (sound: [Float], rate: Double, name: String)?
    private var recorder: Recorder?
    private var lineUntil = 0.0
    private static let longest = 30.0

    private struct Saved: Codable { var name: String; var rate: Double; var chops: [Kit.Chop] }

    init(folder: URL) {
        self.folder = folder.appendingPathComponent("Chops")
    }

    func start(_ s: Stage, settings: URL) {
        stage = s
        s.ask = { [weak self] in self?.take($0) }
        let j = JSONDecoder()
        func read<T: Decodable>(_ k: String, _ t: T.Type) -> T? { (try? Data(contentsOf: settings.appendingPathComponent("\(k).json"))).flatMap { try? j.decode(t, from: $0) } }
        if let x = read("chopDials", [Double].self), x.count == ChopDial.allCases.count { s.chops.dials = x }
        if let x = read("chopEffects", [Effect].self), x.map(\.kind) == Effect.Kind.allCases, x.allSatisfy({ $0.dials.count == 3 }) { s.chops.effects = x }
        if let x = read("chopModule", Bool.self) { s.chops.module = x }
        s.chops.keys = read("chopKeys", Bool.self) ?? false
        self.settings = settings
        look()
        show()
    }
    private var settings: URL?

    // MARK: kits

    private func look() {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        kits = [nil] + files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }.map { Optional($0) }
        at = min(at, kits.count - 1)
    }

    private func choose(_ by: Int) {
        guard kits.count > 1 else { return tell("RECORD OR OPEN A SOUND FOR MORE KITS") }
        at = ((at + by) % kits.count + kits.count) % kits.count
        raw = nil
        do { kit = try kits[at].map(Self.read) ?? SungVoice.kit } catch { tell("THAT KIT CANNOT BE READ"); kit = SungVoice.kit; at = 0 }
        stage?.chops.chosen = 0
        use()
    }

    private static func read(_ u: URL) throws -> Kit {
        let s = try JSONDecoder().decode(Saved.self, from: Data(contentsOf: u))
        let (x, rate) = try Wave.read(u.deletingPathExtension().appendingPathExtension("wav"), most: 300)
        return Kit(name: s.name, rate: rate, audio: x, chops: s.chops.filter { $0.start >= 0 && $0.end <= x.count + 64 && $0.start < $0.end })
    }

    private func save() {
        guard !kit.audio.isEmpty else { return }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let base: URL
            if let u = kits[at] { base = u.deletingPathExtension() }
            else {
                let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyyMMdd-HHmmss"
                base = folder.appendingPathComponent("kit-" + f.string(from: Date()))
            }
            try Wave.write(kit.audio, rate: kit.rate, to: base.appendingPathExtension("wav"))
            try JSONEncoder().encode(Saved(name: kit.name, rate: kit.rate, chops: kit.chops)).write(to: base.appendingPathExtension("json"), options: .atomic)
            look()
            at = kits.firstIndex { $0?.lastPathComponent == base.lastPathComponent + ".json" } ?? at
        } catch { tell("THE KIT WAS NOT KEPT: \(error.localizedDescription.uppercased())") }
    }

    private func remove() {
        guard let u = kits[at] else { return }
        for f in [u, u.deletingPathExtension().appendingPathExtension("wav")] { try? FileManager.default.removeItem(at: f) }
        at = 0
        kit = SungVoice.kit
        raw = nil
        look()
        use()
    }

    /// A sound, cut as chosen, becomes a new kit.
    func take(sound: [Float], rate: Double, name: String) {
        raw = (sound, rate, name)
        let k = Chopper.cut(sound, rate: rate, mode: stage?.chops.cut ?? .hits, name: name)
        guard !k.chops.isEmpty else { raw = nil; return tell("NOTHING IS HEARD IN IT") }
        kit = k
        at = 0
        stage?.chops.chosen = 0
        save()
        use()
    }

    private func cutAgain() {
        guard let r = raw else { return tell("RECORD OR OPEN A SOUND TO CUT IT ANOTHER WAY") }
        let k = Chopper.cut(r.sound, rate: r.rate, mode: stage?.chops.cut ?? .hits, name: r.name)
        guard !k.chops.isEmpty else { return tell("NOTHING IS HEARD IN IT") }
        kit = k
        save()
        use()
    }

    private func use() { chops?.load(kit); show() }

    private func show() {
        guard let stage else { return }
        stage.chops.name = kit.name
        stage.chops.list = kit.chops
        stage.chops.shape = kit.shape(320)
        stage.chops.length = max(1, kit.audio.count)
        stage.chops.own = kits[at] != nil
        stage.chops.chosen = min(stage.chops.chosen, max(0, kit.chops.count - 1))
        changed()
    }

    func tell(_ s: String) {
        stage?.chops.line = s
        lineUntil = monotonic() + 4
        changed()
    }

    // MARK: asked

    private func take(_ a: ChopAsk) {
        switch a {
        case .start(let n, let v, let id, let semis):
            guard sounds() else { return }
            chops?.start(n, velocity: v, id: id, semitones: semis)
        case .stop(let id): chops?.stop(id: id)
        case .silence: chops?.silence()
        case .dial(let d, let x): if let k = ChopDial(rawValue: d) { chops?.set(k, x) }
        case .effect(let e): chops?.set(e)
        case .edited(let list): kit.chops = list; chops?.load(kit); if kits[at] != nil { save() }
        case .kit(let by): choose(by)
        case .cut: cutAgain()
        case .removeKit: remove()
        case .open: wantsFile = true
        case .record(let s): record(s)
        case .stopRecording: finish()
        case .keep:
            guard let s = stage, let settings else { return }
            let e = JSONEncoder()
            func put<T: Encodable>(_ k: String, _ v: T) { try? (try? e.encode(v))?.write(to: settings.appendingPathComponent("\(k).json"), options: .atomic) }
            put("chopDials", s.chops.dials)
            put("chopEffects", s.chops.effects)
            put("chopModule", s.chops.module)
            put("chopKeys", s.chops.keys)
        }
    }

    /// The Kotlin side took the request.
    func tookRequests() { wantsFile = false; wantsMicrophone = false }

    func set(tempo: Int?) { if let tempo { chops?.set(tempo: Double(tempo)) } }

    /// Now and then: what sounds, how the recording goes, when what was said is old.
    func tick(_ now: Double) {
        guard let stage else { return }
        if let c = chops {
            let on = c.sounding
            if on != stage.chops.sounding { stage.chops.sounding = on; changed() }
        }
        if out?.lost == true { out?.stop(); out = nil; chops?.silence() }     // the next chop starts it again
        if let r = recorder {
            let (seconds, level) = r.state
            stage.chops.seconds = seconds
            stage.chops.level = Double(level)
            changed()
            if seconds >= Self.longest || r.lost { finish() }
        }
        if lineUntil > 0, now > lineUntil { lineUntil = 0; stage.chops.line = ""; changed() }
    }

    // MARK: sound

    /// On, from the first chop.
    private func sounds() -> Bool {
        if chops != nil, out != nil { return true }
        do {
            let o = try ChopsOut(device: devices.output)
            if chops == nil || chops?.rate != Double(o.rate) {
                let c = ChopEngine(rate: Double(o.rate))
                chops = c
                c.load(kit)
                for (i, x) in (stage?.chops.dials ?? []).enumerated() { if let k = ChopDial(rawValue: i) { c.set(k, x) } }
                for e in stage?.chops.effects ?? [] { c.set(e) }
                set(tempo: stage?.input.tempo)
            }
            o.play(chops!)
            out = o
        } catch {
            tell("NO SOUND HERE: \(error.why.uppercased())")
            return false
        }
        return true
    }

    // MARK: recording

    private func record(_ from: ChopDesk.Source) {
        guard recorder == nil, from != .file else { return }
        guard devices.allowed else { wantsMicrophone = true; return tell("ALLOW GALAX-Z THE MICROPHONE") }
        let device = from == .opz ? devices.opz : devices.microphone
        guard from != .opz || device != 0 else { return tell("THE OP-Z'S SOUND IS NOT ON THE CABLE") }
        do { recorder = try Recorder(device: device, opz: from == .opz) } catch { return tell(error.why.uppercased()) }
        stage?.chops.recording = true
        changed()
    }

    private func finish() {
        guard let r = recorder else { return }
        recorder = nil
        stage?.chops.recording = false
        let (x, rate) = r.stop()
        guard x.count > Int(rate * 0.1) else { return tell("TOO SHORT") }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HHmm"
        take(sound: x, rate: rate, name: "REC " + f.string(from: Date()))
    }

    /// A file the Kotlin side opened and decoded: mono, at its own rate.
    func open(_ x: [Float], rate: Double, name: String) {
        guard !x.isEmpty, rate > 0 else { return tell("THAT FILE CANNOT BE READ") }
        take(sound: Array(x.prefix(Int(Chopper.maxSource * rate))), rate: rate, name: String(name.prefix(14)))
    }

    func stopSound() { out?.stop(); out = nil; _ = recorder?.stop(); recorder = nil }
}

/// 16-bit (or float) mono WAV, as the kits are kept on iOS.
enum Wave {
    struct Bad: Error {}

    static func write(_ x: [Float], rate: Double, to u: URL) throws {
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let bytes = UInt32(x.count * 2)
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + bytes); d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(bytes)
        d.reserveCapacity(d.count + Int(bytes))
        for v in x { u16(UInt16(bitPattern: Int16(max(-1, min(1, v.isFinite ? v : 0)) * 32767))) }
        try d.write(to: u, options: .atomic)
    }

    static func read(_ u: URL, most: Double) throws -> ([Float], Double) {
        let d = [UInt8](try Data(contentsOf: u))
        func u32(_ i: Int) -> Int { Int(d[i]) | Int(d[i + 1]) << 8 | Int(d[i + 2]) << 16 | Int(d[i + 3]) << 24 }
        func u16(_ i: Int) -> Int { Int(d[i]) | Int(d[i + 1]) << 8 }
        guard d.count >= 44, String(decoding: d[0..<4], as: UTF8.self) == "RIFF", String(decoding: d[8..<12], as: UTF8.self) == "WAVE" else { throw Bad() }
        var i = 12, format = 0, channels = 0, rate = 0, bits = 0
        while i + 8 <= d.count {
            let id = String(decoding: d[i..<i + 4], as: UTF8.self), n = u32(i + 4), body = i + 8
            if id == "fmt ", body + 16 <= d.count { (format, channels, rate, bits) = (u16(body), u16(body + 2), u32(body + 4), u16(body + 14)) }
            if id == "data" {
                guard channels > 0, rate > 0, (format == 1 && bits == 16) || (format == 3 && bits == 32) else { throw Bad() }
                let size = bits / 8 * channels, frames = min((min(n, d.count - body)) / size, Int(most * Double(rate)))
                var out = [Float](repeating: 0, count: frames)
                for f in 0..<frames {
                    var sum: Float = 0
                    for c in 0..<channels {
                        let at = body + f * size + c * bits / 8
                        sum += format == 1 ? Float(Int16(bitPattern: UInt16(u16(at)))) / 32768 : Float(bitPattern: UInt32(u32(at)))
                    }
                    out[f] = sum / Float(channels)
                }
                return (out, Double(rate))
            }
            i = body + n + (n & 1)
        }
        throw Bad()
    }
}
