import AVFoundation
import Observation
import OPZLink
import UIKit

/// The system's microphone permission (what it calls any sound coming in, the OP-Z's over the cable too), asked for once: what the
/// system already knows is used as it is, and a question already on screen is waited for rather than asked again. The sound path is
/// built again whenever a device comes or goes, and every time used to ask.
@MainActor enum Microphone {
    private static var asking: Task<Bool, Never>?
    static var denied: Bool { AVAudioApplication.shared.recordPermission == .denied }

    static func allowed() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default:
            if let asking { return await asking.value }
            let t = Task { await AVAudioApplication.requestRecordPermission() }
            asking = t
            defer { asking = nil }
            return await t.value
        }
    }

    /// The system's settings for this app, where the microphone can be allowed after a no.
    static func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

/// Where the OP-Z is heard: from itself, or over the cable from this device. Its sound is only passed on: nothing is recorded, and no
/// microphone is used.
@MainActor @Observable
final class AudioOut {
    enum Out: String, CaseIterable { case opz, here }
    enum State: Equatable { case off, waiting, playing(String), failed(String) }

    static var here: String {
        #if targetEnvironment(macCatalyst)
        "MAC"
        #else
        UIDevice.current.userInterfaceIdiom == .phone ? "IPHONE" : "IPAD"
        #endif
    }

    var out = Out(rawValue: UserDefaults.standard.string(forKey: "audioOut") ?? "") ?? .opz {
        didSet { guard out != oldValue else { return }; UserDefaults.standard.set(out.rawValue, forKey: "audioOut"); apply() }
    }
    var volume = UserDefaults.standard.object(forKey: "audioVolume") as? Double ?? 0.8 {
        didSet { UserDefaults.standard.set(volume, forKey: "audioVolume"); path?.volume = Float(volume) }
    }
    private(set) var state = State.off { didSet { if state != oldValue { changed() } } }
    @ObservationIgnored var changed: () -> Void = {}

    @ObservationIgnored private var path: SoundPath?
    @ObservationIgnored private var cable = false
    @ObservationIgnored private var again: Task<Void, Never>?
    @ObservationIgnored private var run = 0
    /// When the path was last built again by itself: a jack that flickers, or a device that resets, waits longer each time.
    @ObservationIgnored private var rebuilt: [Date] = []

    /// What the screen says: nil when there is no choice (no cable).
    var line: String? {
        guard cable else { return nil }
        switch state {
        case .playing: return "OUT " + Self.here
        case .failed: return "OUT ?"
        case .off, .waiting: return out == .here ? "OUT ..." : "OUT OP-Z"
        }
    }

    var explained: String {
        switch state {
        case .off: return out == .here ? "Waits for the OP-Z on a cable: Bluetooth carries no sound." : "The OP-Z plays from its own speaker or headphones."
        case .waiting: return "Starting…"
        case .playing(let to): return "The OP-Z's sound comes over the cable and plays here: \(to)."
        case .failed(let why): return why
        }
    }

    func toggle() { out = out == .opz ? .here : .opz }

    /// An OP-Z is there over USB, or not.
    func cable(_ on: Bool) {
        guard on != cable else { return }
        cable = on
        apply()
        changed()
    }

    /// `restoring`: the output's own sample rate back too (not when building again onto the same output: that resets it, and round it goes).
    private func apply(restoring: Bool = true) {
        again?.cancel()
        run += 1
        path?.stop(restoring: restoring)
        path = nil
        guard out == .here, cable else { state = .off; return }
        state = .waiting
        let me = run
        let changed: @MainActor () -> Void = { [weak self] in self?.restart() }
        Task {
            guard await Microphone.allowed() else {
                if me == run { state = .failed("Allow Galax-z the microphone in the system's settings (MICROPHONE below): that is what it calls any sound coming in. Only the OP-Z's is used.") }
                return
            }
            guard me == run else { return }
            // the cable's audio side can show up after its MIDI side
            var why = ""
            for _ in 0..<12 {
                do {
                    let p = try SoundPath(volume: Float(volume), changed: changed)
                    path = p
                    state = .playing(p.to)
                    return
                } catch let e as SoundPath.Refused {
                    why = e.why
                    if !e.wait { break }
                } catch { why = error.localizedDescription }
                try? await Task.sleep(for: .milliseconds(500))
                guard me == run else { return }
            }
            state = .failed(why)
        }
    }

    /// Devices came or went: once it is quiet, and only if the way is broken or the output is another one, from the start.
    private func restart() {
        again?.cancel()
        again = Task {
            rebuilt.removeAll { -$0.timeIntervalSinceNow > 10 }
            try? await Task.sleep(for: .milliseconds(rebuilt.count >= 2 ? 2500 : 600))
            guard !Task.isCancelled else { return }
            if path?.stillGood == true { return }
            rebuilt.append(Date())
            apply(restoring: false)
        }
    }
}

#if !targetEnvironment(macCatalyst)
/// iPad and iPhone: the OP-Z as the session's input, this device (its speaker, or what is plugged in or linked) as its output.
@MainActor final class SoundPath {
    /// `wait`: it may come by itself in a moment.
    struct Refused: Error { let why: String; var wait = false }
    let to: String
    var volume: Float { didSet { engine.mainMixerNode.outputVolume = volume } }
    private let engine = AVAudioEngine()
    private var watching: [NSObjectProtocol] = []

    init(volume: Float, changed: @escaping @MainActor () -> Void) throws {
        self.volume = volume
        let s = AVAudioSession.sharedInstance()
        do {
            try s.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP])
            try? s.setPreferredSampleRate(44_100)
            try? s.setPreferredIOBufferDuration(0.005)
            try s.setActive(true)
            let usb = (s.availableInputs ?? []).filter { $0.portType == .usbAudio }
            guard let opz = usb.first(where: { SoundCopy.isOPZ($0.portName) }) ?? (usb.count == 1 ? usb[0] : nil) else {
                throw Refused(why: "The OP-Z's sound is not on the cable. Take the cable out and put it in again, with the OP-Z switched on.", wait: true)
            }
            try s.setPreferredInput(opz)
            func itself() -> Bool { s.currentRoute.outputs.contains { $0.uid == opz.uid || $0.portName == opz.portName } }
            if itself() {                               // it took the output too: this device's own, and the OP-Z as the input again
                try? s.overrideOutputAudioPort(.speaker)
                try? s.setPreferredInput(opz)
            }
            // never the microphone, and never back into the OP-Z: either could feed back
            guard s.currentRoute.inputs.contains(where: { $0.uid == opz.uid || $0.portName == opz.portName }) else {
                throw Refused(why: "This device does not take the OP-Z's sound and play it itself at once. Headphones on it may help.")
            }
            guard !itself() else {
                throw Refused(why: "This device sends its own sound to the OP-Z. Choose its speaker or headphones in Control Center, then try again.")
            }
            try? s.setPreferredInputNumberOfChannels(min(2, s.maximumInputNumberOfChannels))
            let format = engine.inputNode.outputFormat(forBus: 0)
            guard format.channelCount > 0, format.sampleRate > 0 else { throw Refused(why: "The OP-Z's sound has no format.") }
            engine.connect(engine.inputNode, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = volume
            engine.prepare()
            try engine.start()
            to = s.currentRoute.outputs.map(\.portName).joined(separator: ", ")
        } catch {
            engine.stop()
            Self.release()
            throw error
        }
        for name in [AVAudioSession.mediaServicesWereResetNotification, .AVAudioEngineConfigurationChange] {
            watching.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in MainActor.assumeIsolated { changed() } })
        }
        watching.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { n in
            let why = (n.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt).flatMap(AVAudioSession.RouteChangeReason.init)
            // our own changes are not news
            guard why == .newDeviceAvailable || why == .oldDeviceUnavailable else { return }
            MainActor.assumeIsolated { changed() }
        })
        watching.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { n in
            guard n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt == AVAudioSession.InterruptionType.ended.rawValue else { return }
            MainActor.assumeIsolated { changed() }
        })
    }

    /// The route's news is told only when it matters (see the observers): build again.
    var stillGood: Bool { false }

    func stop(restoring: Bool = true) {
        for w in watching { NotificationCenter.default.removeObserver(w) }
        watching = []
        engine.stop()
        Self.release()
    }

    private static func release() {
        let s = AVAudioSession.sharedInstance()
        try? s.overrideOutputAudioPort(.none)
        try? s.setPreferredInput(nil)
        try? s.setActive(false, options: .notifyOthersOnDeactivation)
        try? s.setCategory(.ambient)
    }
}
#else
import CoreAudio

/// The Mac: the OP-Z and the output put together as one private device (the system keeps their clocks together), and a copy from one to
/// the other.
@MainActor final class SoundPath {
    /// `wait`: it may come by itself in a moment.
    struct Refused: Error { let why: String; var wait = false }
    let to: String
    var volume: Float { didSet { shared.pointee.wanted = volume } }

    private struct Shared { var copy = SoundCopy(), wanted: Float = 0 }
    private let shared: UnsafeMutablePointer<Shared>
    private var device = AudioObjectID(0)
    private var proc: AudioDeviceIOProcID?
    private var rate: (AudioObjectID, Double)?
    /// Each output's own rate from before it was first used, kept across builds that leave it as it is.
    private static var original: [String: Double] = [:]
    private let opzID: String, outID: String
    private var listening: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    init(volume: Float, changed: @escaping @MainActor () -> Void) throws {
        self.volume = volume
        let all = HAL.devices()
        guard let opz = all.first(where: { SoundCopy.isOPZ(HAL.name($0)) && HAL.channels($0, kAudioObjectPropertyScopeInput) > 0 }) else {
            throw Refused(why: "The OP-Z's sound is not on the cable. Take the cable out and put it in again, with the OP-Z switched on.", wait: true)
        }
        // the Mac's output, but never the OP-Z itself: that would go round
        let usual = HAL.defaultOutput()
        let own = all.first { HAL.transport($0) == kAudioDeviceTransportTypeBuiltIn && HAL.channels($0, kAudioObjectPropertyScopeOutput) > 0 }
        guard let out = usual.flatMap({ SoundCopy.isOPZ(HAL.name($0)) || HAL.transport($0) == kAudioDeviceTransportTypeAggregate ? nil : $0 }) ?? own,
              let outID = HAL.uid(out), let opzID = HAL.uid(opz), outID != opzID else {
            throw Refused(why: "There is nothing to play it on: choose the Mac's speakers or headphones as its sound output.")
        }
        to = HAL.name(out)
        (self.opzID, self.outID) = (opzID, outID)
        shared = .allocate(capacity: 1)
        shared.initialize(to: Shared())
        shared.pointee.wanted = volume
        let what: [String: Any] = [kAudioAggregateDeviceNameKey: "Galax-z", kAudioAggregateDeviceUIDKey: "org.galax-z.out." + UUID().uuidString,
                                   kAudioAggregateDeviceIsPrivateKey: 1, kAudioAggregateDeviceMainSubDeviceKey: outID,
                                   kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: opzID, kAudioSubDeviceDriftCompensationKey: 1],
                                                                           [kAudioSubDeviceUIDKey: outID, kAudioSubDeviceDriftCompensationKey: 0]]]
        // the OP-Z comes first: its streams are the first ones, in and out
        let skip = HAL.streams(opz, kAudioObjectPropertyScopeOutput)
        if Self.original[outID] == nil { Self.original[outID] = HAL.rate(out) }
        rate = Self.original[outID].map { (out, $0) }
        do {
            try Self.ok(AudioHardwareCreateAggregateDevice(what as CFDictionary, &device), "putting the OP-Z and \(to) together")
            HAL.setFrames(device, 256)
            try Self.ok(Self.make(&proc, device, shared, skip), "the sound's way")
            try Self.ok(AudioDeviceStart(device, proc), "starting the sound")
        } catch {
            close()
            throw error
        }
        // devices came or went, or another output was chosen: AudioOut waits for quiet, then asks stillGood
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice] {
            var a = HAL.address(selector)
            let block: AudioObjectPropertyListenerBlock = { _, _ in Task { @MainActor in changed() } }
            if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &a, .main, block) == noErr { listening.append((a, block)) }
        }
    }

    /// The OP-Z and the output are both still there, the sound still runs, and the output is still the one the Mac plays on.
    /// (Making our own device changes the list, and an output whose rate is changed can reset for a moment: neither is news.)
    var stillGood: Bool {
        let here = Set(HAL.devices().compactMap(HAL.uid))
        guard here.contains(opzID), here.contains(outID), HAL.flag(device, kAudioDevicePropertyDeviceIsAlive), HAL.flag(device, kAudioDevicePropertyDeviceIsRunning) else { return false }
        guard let d = HAL.defaultOutput(), let u = HAL.uid(d) else { return true }
        return u == outID || SoundCopy.isOPZ(HAL.name(d)) || HAL.transport(d) == kAudioDeviceTransportTypeAggregate
    }

    func stop(restoring: Bool = true) { close(restoring: restoring || HAL.defaultOutput().flatMap(HAL.uid) != outID) }

    private func close(restoring: Bool = true) {
        for (a, block) in listening {
            var a = a
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &a, .main, block)
        }
        listening = []
        if let proc { AudioDeviceStop(device, proc); AudioDeviceDestroyIOProcID(device, proc) }
        proc = nil
        if device != 0 { AudioHardwareDestroyAggregateDevice(device) }
        device = 0
        // the output's own rate again, if it was changed for this
        if restoring, let (d, r) = rate {
            if HAL.rate(d) != r { HAL.setRate(d, r) }
            Self.original[outID] = nil
        }
        rate = nil
        // what the audio thread read lives until it has surely gone
        let p = shared
        nonisolated(unsafe) let q = p
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { q.deinitialize(count: 1); q.deallocate() }
    }

    private static func ok(_ status: OSStatus, _ what: String) throws {
        guard status == noErr else { throw Refused(why: "The Mac refused \(what) (\(status)).") }
    }

    /// Not of the main actor: it runs on the audio thread.
    nonisolated private static func make(_ proc: inout AudioDeviceIOProcID?, _ device: AudioObjectID, _ shared: UnsafeMutablePointer<Shared>, _ skip: Int) -> OSStatus {
        nonisolated(unsafe) let shared = shared
        return AudioDeviceCreateIOProcIDWithBlock(&proc, device, nil) { _, input, _, output, _ in
            let ins = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input)), outs = UnsafeMutableAudioBufferListPointer(output)
            for b in outs { if let d = b.mData { memset(d, 0, Int(b.mDataByteSize)) } }
            guard ins.count > 0, outs.count > skip, let from = ins[0].mData, let into = outs[skip].mData else { return }
            let ci = Int(ins[0].mNumberChannels), co = Int(outs[skip].mNumberChannels)
            guard ci > 0, co > 0 else { return }
            let frames = min(Int(ins[0].mDataByteSize) / (4 * ci), Int(outs[skip].mDataByteSize) / (4 * co))
            shared.pointee.copy.copy(from.assumingMemoryBound(to: Float.self), channels: ci, to: into.assumingMemoryBound(to: Float.self), channels: co,
                                     frames: frames, wanted: shared.pointee.wanted)
        }
    }
}

/// The Mac's audio devices.
enum HAL {
    static func address(_ s: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: s, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
    private static func size(_ o: AudioObjectID, _ a: AudioObjectPropertyAddress) -> Int {
        var a = a, n: UInt32 = 0
        return AudioObjectGetPropertyDataSize(o, &a, 0, nil, &n) == noErr ? Int(n) : 0
    }
    private static func value<T>(_ o: AudioObjectID, _ a: AudioObjectPropertyAddress, _ start: T) -> T? {
        var a = a, v = start, n = UInt32(MemoryLayout<T>.size)
        return withUnsafeMutablePointer(to: &v) { AudioObjectGetPropertyData(o, &a, 0, nil, &n, $0) } == noErr ? v : nil
    }
    private static func string(_ o: AudioObjectID, _ s: AudioObjectPropertySelector) -> String? {
        var a = address(s), n = UInt32(MemoryLayout<Unmanaged<CFString>?>.size), v: Unmanaged<CFString>?
        guard AudioObjectGetPropertyData(o, &a, 0, nil, &n, &v) == noErr else { return nil }
        return v?.takeRetainedValue() as String?
    }
    static func devices() -> [AudioObjectID] {
        var a = address(kAudioHardwarePropertyDevices)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var ids = [AudioObjectID](repeating: 0, count: size(system, a) / 4), n = UInt32(ids.count * 4)
        guard !ids.isEmpty, AudioObjectGetPropertyData(system, &a, 0, nil, &n, &ids) == noErr else { return [] }
        return Array(ids.prefix(Int(n) / 4))
    }
    static func name(_ d: AudioObjectID) -> String { string(d, kAudioObjectPropertyName) ?? "" }
    static func uid(_ d: AudioObjectID) -> String? { string(d, kAudioDevicePropertyDeviceUID) }
    static func transport(_ d: AudioObjectID) -> UInt32 { value(d, address(kAudioDevicePropertyTransportType), UInt32(0)) ?? 0 }
    static func defaultOutput() -> AudioObjectID? { value(AudioObjectID(kAudioObjectSystemObject), address(kAudioHardwarePropertyDefaultOutputDevice), AudioObjectID(0)).flatMap { $0 == 0 ? nil : $0 } }
    static func streams(_ d: AudioObjectID, _ scope: AudioObjectPropertyScope) -> Int { size(d, address(kAudioDevicePropertyStreams, scope)) / 4 }
    static func channels(_ d: AudioObjectID, _ scope: AudioObjectPropertyScope) -> Int {
        var a = address(kAudioDevicePropertyStreamConfiguration, scope)
        let n = size(d, a)
        guard n > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: n, alignment: 16)
        defer { raw.deallocate() }
        var m = UInt32(n)
        guard AudioObjectGetPropertyData(d, &a, 0, nil, &m, raw) == noErr else { return 0 }
        return UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self)).reduce(0) { $0 + Int($1.mNumberChannels) }
    }
    static func flag(_ d: AudioObjectID, _ s: AudioObjectPropertySelector) -> Bool { d != 0 && (value(d, address(s), UInt32(0)) ?? 0) != 0 }
    static func rate(_ d: AudioObjectID) -> Double? { value(d, address(kAudioDevicePropertyNominalSampleRate), 0.0) }
    static func setRate(_ d: AudioObjectID, _ r: Double) { var a = address(kAudioDevicePropertyNominalSampleRate), r = r; AudioObjectSetPropertyData(d, &a, 0, nil, 8, &r) }
    static func setFrames(_ d: AudioObjectID, _ n: UInt32) { var a = address(kAudioDevicePropertyBufferFrameSize), n = n; AudioObjectSetPropertyData(d, &a, 0, nil, 4, &n) }
}
#endif
