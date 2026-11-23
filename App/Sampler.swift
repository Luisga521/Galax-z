import AVFoundation
import ChopKit
import Foundation
import Observation
import OPZLink
import OPZStage
import os
#if targetEnvironment(macCatalyst)
import CoreAudio
#endif

/// The chops on this device: their sound, what is recorded and opened, the kits kept (`Documents/Chops`).
@MainActor @Observable
final class Sampler {
    @ObservationIgnored weak var stage: Stage?
    @ObservationIgnored var changed: () -> Void = {}
    /// A file is wanted: the app's window shows the picker.
    var opening = false

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var chops: ChopEngine?
    @ObservationIgnored private var node: AVAudioSourceNode?
    @ObservationIgnored private var kit = SungVoice.kit
    @ObservationIgnored private var kits: [URL?] = [nil]                    // nil: VOX
    @ObservationIgnored private var at = 0
    /// A recording as it was made, to be cut again.
    @ObservationIgnored private var raw: (sound: [Float], rate: Double, name: String)?
    @ObservationIgnored private var recorder: Recorder?
    @ObservationIgnored private var watching: [NSObjectProtocol] = []
    @ObservationIgnored private var ticker: Task<Void, Never>?

    struct Failed: Error { let why: String }
    private struct Saved: Codable { var name: String; var rate: Double; var chops: [Kit.Chop] }
    private static let longest = 30.0

    static var folder: URL { Backups.root.deletingLastPathComponent().appending(path: "Chops") }

    func start(_ s: Stage) {
        stage = s
        s.ask = { [weak self] in self?.take($0) }
        let d = UserDefaults.standard, j = JSONDecoder()
        if let x = d.data(forKey: "chopDials").flatMap({ try? j.decode([Double].self, from: $0) }), x.count == ChopDial.allCases.count { s.chops.dials = x }
        if let x = d.data(forKey: "chopEffects").flatMap({ try? j.decode([Effect].self, from: $0) }), x.map(\.kind) == Effect.Kind.allCases, x.allSatisfy({ $0.dials.count == 3 }) { s.chops.effects = x }
        if d.object(forKey: "chopModule") != nil { s.chops.module = d.bool(forKey: "chopModule") }
        s.chops.keys = d.bool(forKey: "chopKeys")
        look()
        show()
    }

    // MARK: kits

    private func look() {
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: nil)) ?? []
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
        let (x, rate) = try sound(u.deletingPathExtension().appendingPathExtension("wav"), most: 300)
        return Kit(name: s.name, rate: rate, audio: x, chops: s.chops.filter { $0.start >= 0 && $0.end <= x.count + 64 && $0.start < $0.end })
    }

    private func save() {
        guard !kit.audio.isEmpty else { return }
        do {
            try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
            let base: URL
            if let u = kits[at] { base = u.deletingPathExtension() }
            else {
                let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyyMMdd-HHmmss"
                base = Self.folder.appending(path: "kit-" + f.string(from: Date()))
            }
            try Self.write(kit.audio, rate: kit.rate, to: base.appendingPathExtension("wav"))
            try JSONEncoder().encode(Saved(name: kit.name, rate: kit.rate, chops: kit.chops)).write(to: base.appendingPathExtension("json"), options: .atomic)
            look()
            at = kits.firstIndex { $0?.lastPathComponent == base.lastPathComponent + ".json" } ?? at
        } catch { tell("THE KIT WAS NOT KEPT: \(error.localizedDescription.uppercased())") }
    }

    /// The kit goes to the Trash where there is one.
    private func remove() {
        guard let u = kits[at] else { return }
        let wav = u.deletingPathExtension().appendingPathExtension("wav")
        for f in [u, wav] { do { try FileManager.default.trashItem(at: f, resultingItemURL: nil) } catch { try? FileManager.default.removeItem(at: f) } }
        at = 0
        kit = SungVoice.kit
        raw = nil
        look()
        use()
    }

    /// A sound, cut as chosen, becomes a new kit.
    private func take(sound: [Float], rate: Double, name: String) {
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

    private func tell(_ s: String) {
        stage?.chops.line = s
        changed()
        Task { try? await Task.sleep(for: .seconds(4)); if stage?.chops.line == s { stage?.chops.line = ""; changed() } }
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
        case .open: opening = true
        case .record(let s): Task { await record(s) }
        case .stopRecording: finish()
        case .keep:
            guard let s = stage else { return }
            let e = JSONEncoder(), d = UserDefaults.standard
            d.set(try? e.encode(s.chops.dials), forKey: "chopDials")
            d.set(try? e.encode(s.chops.effects), forKey: "chopEffects")
            d.set(s.chops.module, forKey: "chopModule")
            d.set(s.chops.keys, forKey: "chopKeys")
        }
    }

    /// For the self test: the loudest since it was asked, and the kits there are.
    var loudest: Float { chops?.takeLevel() ?? -1 }
    var kitCount: Int { kits.count }
    var kitName: String { "\(kit.name), \(kit.chops.count) chops" }

    func set(tempo: Int?) { if let tempo { chops?.set(tempo: Double(tempo)) } }

    // MARK: sound

    /// On, from the first chop.
    private func sounds() -> Bool {
        if chops != nil, engine.isRunning { return true }
        do {
            #if !targetEnvironment(macCatalyst)
            let s = AVAudioSession.sharedInstance()
            if s.category != .playAndRecord { try s.setCategory(.playback, options: [.mixWithOthers]) }
            try? s.setPreferredIOBufferDuration(0.005)
            try s.setActive(true)
            #endif
            let rate = max(8000, engine.outputNode.outputFormat(forBus: 0).sampleRate)
            if chops == nil || chops?.rate != rate {
                if let node { engine.detach(node) }
                let c = ChopEngine(rate: rate)
                guard let f = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else { return false }
                let n = Self.source(c, f)
                engine.attach(n)
                engine.connect(n, to: engine.mainMixerNode, format: f)
                (chops, node) = (c, n)
                c.load(kit)
                for (i, x) in (stage?.chops.dials ?? []).enumerated() { if let k = ChopDial(rawValue: i) { c.set(k, x) } }
                for e in stage?.chops.effects ?? [] { c.set(e) }
                set(tempo: stage?.input.tempo)
            }
            engine.prepare()
            try engine.start()
        } catch { tell("NO SOUND HERE: \(error.localizedDescription.uppercased())"); return false }
        if watching.isEmpty {
            watching.append(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { guard let self else { return }; self.engine.stop(); self.chops?.silence() }       // the next chop starts it again
            })
        }
        if ticker == nil {
            ticker = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(33))
                    guard let self, let s = self.stage, let c = self.chops else { continue }
                    let on = c.sounding
                    if on != s.chops.sounding { s.chops.sounding = on; self.changed() }
                }
            }
        }
        return true
    }

    /// (of no actor: it runs on the audio thread)
    nonisolated private static func source(_ c: ChopEngine, _ f: AVAudioFormat) -> AVAudioSourceNode {
        AVAudioSourceNode(format: f) { _, _, n, list in
            let b = UnsafeMutableAudioBufferListPointer(list)
            guard b.count >= 2, let l = b[0].mData?.assumingMemoryBound(to: Float.self), let r = b[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            c.render(l, r, Int(n))
            return noErr
        }
    }

    // MARK: recording

    private func record(_ from: ChopDesk.Source) async {
        guard recorder == nil, from != .file else { return }
        guard await AVAudioApplication.requestRecordPermission() else { return tell("ALLOW GALAX-Z THE MICROPHONE IN THE SYSTEM'S SETTINGS") }
        do {
            recorder = try Recorder(opz: from == .opz)
        } catch let e as Failed { return tell(e.why) } catch { return tell(error.localizedDescription.uppercased()) }
        stage?.chops.recording = true
        while let r = recorder {
            let (seconds, level) = r.state
            stage?.chops.seconds = seconds
            stage?.chops.level = Double(level)
            changed()
            if seconds >= Self.longest { finish(); break }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private func finish() {
        guard let r = recorder else { return }
        recorder = nil
        stage?.chops.recording = false
        let (x, rate) = r.stop()
        // the session back as it was for playing
        if engine.isRunning == false, chops != nil { _ = sounds() }
        guard x.count > Int(rate * 0.1) else { return tell("TOO SHORT") }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HHmm"
        take(sound: x, rate: rate, name: "REC " + f.string(from: Date()))
    }

    // MARK: files

    func open(_ u: URL) {
        let held = u.startAccessingSecurityScopedResource()
        defer { if held { u.stopAccessingSecurityScopedResource() } }
        do {
            let (x, rate) = try Self.sound(u, most: Chopper.maxSource)
            take(sound: x, rate: rate, name: String(u.deletingPathExtension().lastPathComponent.prefix(14)))
        } catch { tell("THAT FILE CANNOT BE READ") }
    }

    /// Any sound file, mono.
    nonisolated static func sound(_ u: URL, most: Double) throws -> ([Float], Double) {
        let f = try AVAudioFile(forReading: u), rate = f.processingFormat.sampleRate, channels = Int(f.processingFormat.channelCount)
        let want = min(Int(f.length), Int(most * rate))
        guard want > 0, channels > 0, let b = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: 65_536) else { throw Failed(why: "EMPTY") }
        var out = [Float]()
        out.reserveCapacity(want)
        while out.count < want {
            try f.read(into: b)
            guard b.frameLength > 0, let d = b.floatChannelData else { break }
            for i in 0..<min(Int(b.frameLength), want - out.count) { out.append((0..<channels).reduce(Float(0)) { $0 + d[$1][i] } / Float(channels)) }
        }
        return (out, rate)
    }

    nonisolated static func write(_ x: [Float], rate: Double, to u: URL) throws {
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false]
        let f = try AVAudioFile(forWriting: u, settings: settings)
        guard let b = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(max(1, x.count))), let d = b.floatChannelData else { throw Failed(why: "NO ROOM") }
        x.withUnsafeBufferPointer { if let p = $0.baseAddress { d[0].update(from: p, count: x.count) } }
        b.frameLength = AVAudioFrameCount(x.count)
        try f.write(from: b)
    }
}

/// Takes in a sound: this device's microphone, or the OP-Z over the cable (its own sound, with its microphone when that is on).
@MainActor private final class Recorder {
    private struct Taken { var x: [Float] = []; var level: Float = 0 }
    private let taken = OSAllocatedUnfairLock(initialState: Taken())
    private var rate = 44_100.0
    private let engine = AVAudioEngine()
    #if targetEnvironment(macCatalyst)
    private var device = AudioObjectID(0), proc: AudioDeviceIOProcID?
    #else
    private var before: AVAudioSession.Category?
    #endif

    var state: (Double, Float) {
        let rate = rate
        return taken.withLock { t in defer { t.level *= 0.8 }; return (Double(t.x.count) / rate, t.level) }
    }

    init(opz: Bool) throws {
        #if targetEnvironment(macCatalyst)
        if opz {
            guard let d = HAL.devices().first(where: { SoundCopy.isOPZ(HAL.name($0)) && HAL.channels($0, kAudioObjectPropertyScopeInput) > 0 }) else {
                throw Sampler.Failed(why: "THE OP-Z'S SOUND IS NOT ON THE CABLE")
            }
            rate = HAL.rate(d) ?? 44_100
            guard Self.listen(&proc, d, taken) == noErr, AudioDeviceStart(d, proc) == noErr else { throw Sampler.Failed(why: "THE MAC REFUSED THE OP-Z'S SOUND") }
            device = d
            return
        }
        #else
        let s = AVAudioSession.sharedInstance()
        before = s.category
        try s.setCategory(.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP])
        try s.setActive(true)
        let inputs = s.availableInputs ?? []
        let want = opz ? inputs.first { $0.portType == .usbAudio && SoundCopy.isOPZ($0.portName) } : inputs.first { $0.portType == .builtInMic }
        guard let want else { throw Sampler.Failed(why: opz ? "THE OP-Z'S SOUND IS NOT ON THE CABLE" : "NO MICROPHONE HERE") }
        try s.setPreferredInput(want)
        #endif
        let f = engine.inputNode.outputFormat(forBus: 0)
        guard f.channelCount > 0, f.sampleRate > 0 else { throw Sampler.Failed(why: "NO MICROPHONE HERE") }
        rate = f.sampleRate
        Self.tap(engine.inputNode, f, taken)
        engine.prepare()
        try engine.start()
    }

    func stop() -> ([Float], Double) {
        #if targetEnvironment(macCatalyst)
        if let proc { AudioDeviceStop(device, proc); AudioDeviceDestroyIOProcID(device, proc) }
        proc = nil
        #endif
        if engine.isRunning { engine.inputNode.removeTap(onBus: 0); engine.stop() }
        #if !targetEnvironment(macCatalyst)
        let s = AVAudioSession.sharedInstance()
        try? s.setPreferredInput(nil)
        if let before { try? s.setCategory(before == .playAndRecord ? .playAndRecord : .playback, options: before == .playAndRecord ? [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP] : [.mixWithOthers]) }
        #endif
        return (taken.withLock { $0.x }, rate)
    }

    nonisolated private static func put(_ taken: OSAllocatedUnfairLock<Taken>, _ n: Int, _ sample: (Int) -> Float) {
        var part = [Float](repeating: 0, count: n), peak: Float = 0
        for i in 0..<n { let v = sample(i); part[i] = v.isFinite ? v : 0; peak = max(peak, abs(part[i])) }
        taken.withLock { [part, peak] t in if t.x.count < 4_000_000 { t.x += part }; t.level = max(t.level, peak) }
    }
    nonisolated private static func tap(_ node: AVAudioInputNode, _ f: AVAudioFormat, _ taken: OSAllocatedUnfairLock<Taken>) {
        node.installTap(onBus: 0, bufferSize: 1024, format: f) { b, _ in
            guard let d = b.floatChannelData else { return }
            let c = Int(b.format.channelCount)
            put(taken, Int(b.frameLength)) { i in (0..<c).reduce(Float(0)) { $0 + d[$1][i] } / Float(max(1, c)) }
        }
    }
    #if targetEnvironment(macCatalyst)
    nonisolated private static func listen(_ proc: inout AudioDeviceIOProcID?, _ d: AudioObjectID, _ taken: OSAllocatedUnfairLock<Taken>) -> OSStatus {
        AudioDeviceCreateIOProcIDWithBlock(&proc, d, DispatchQueue(label: "galax-z.record")) { _, input, _, _, _ in
            let b = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
            guard b.count > 0, let p = b[0].mData?.assumingMemoryBound(to: Float.self) else { return }
            let c = max(1, Int(b[0].mNumberChannels))
            put(taken, Int(b[0].mDataByteSize) / (4 * c)) { i in (0..<min(2, c)).reduce(Float(0)) { $0 + p[i * c + $1] } / Float(min(2, c)) }
        }
    }
    #endif
}
