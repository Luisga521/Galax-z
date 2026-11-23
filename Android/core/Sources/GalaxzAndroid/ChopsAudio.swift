import ChopKit

/// Why the sound could not be had.
struct AudioRefused: Error { let why: String; init(_ why: String) { self.why = why } }

#if os(Android)
import CAAudio
import Synchronization

/// AAudio, made to say what went wrong in words.
enum AAudio {
    static func open(_ set: (OpaquePointer) -> Void) throws(AudioRefused) -> OpaquePointer {
        var b: OpaquePointer?
        try ok(AAudio_createStreamBuilder(&b), "making a stream")
        guard let b else { throw AudioRefused("no stream") }
        defer { AAudioStreamBuilder_delete(b) }
        set(b)
        var s: OpaquePointer?
        try ok(AAudioStreamBuilder_openStream(b, &s), "opening a stream")
        guard let s else { throw AudioRefused("no stream") }
        return s
    }

    static func ok(_ r: aaudio_result_t, _ what: String) throws(AudioRefused) {
        guard r == AAUDIO_OK else { throw AudioRefused("Android refused \(what): \(String(cString: AAudio_convertResultToText(r)))") }
    }

    static func close(_ s: OpaquePointer?) {
        guard let s else { return }
        AAudioStream_requestStop(s)
        AAudioStream_close(s)                 // waits for its callback to end
    }
}

/// The chops' own output: the engine rendered in the stream's callback, as `AVAudioSourceNode` does on iOS.
final class ChopsOut {
    private struct Shared {
        var engine: Unmanaged<ChopEngine>?
        var left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>
        var lost = false
    }
    private static let most = 8192
    private let shared: UnsafeMutablePointer<Shared>
    private var stream: OpaquePointer?
    private(set) var rate = 0

    init(device: Int32) throws(AudioRefused) {
        shared = .allocate(capacity: 1)
        shared.initialize(to: Shared(left: .allocate(capacity: Self.most), right: .allocate(capacity: Self.most)))
        do {
            let user = UnsafeMutableRawPointer(shared)
            let s = try AAudio.open { b in
                AAudioStreamBuilder_setDirection(b, aaudio_direction_t(AAUDIO_DIRECTION_OUTPUT))
                AAudioStreamBuilder_setDeviceId(b, device)
                AAudioStreamBuilder_setFormat(b, aaudio_format_t(AAUDIO_FORMAT_PCM_FLOAT))
                AAudioStreamBuilder_setChannelCount(b, 2)
                AAudioStreamBuilder_setPerformanceMode(b, aaudio_performance_mode_t(AAUDIO_PERFORMANCE_MODE_LOW_LATENCY))
                AAudioStreamBuilder_setUsage(b, aaudio_usage_t(AAUDIO_USAGE_MEDIA))
                AAudioStreamBuilder_setContentType(b, aaudio_content_type_t(AAUDIO_CONTENT_TYPE_MUSIC))
                AAudioStreamBuilder_setDataCallback(b, Self.render, user)
                AAudioStreamBuilder_setErrorCallback(b, Self.failed, user)
            }
            stream = s
            rate = Int(AAudioStream_getSampleRate(s))
            AAudioStream_setBufferSizeInFrames(s, AAudioStream_getFramesPerBurst(s) * 2)
            try AAudio.ok(AAudioStream_requestStart(s), "starting the chops' sound")
        } catch {
            AAudio.close(stream)
            free()
            throw error
        }
    }

    /// What it plays (the engine is kept by the sampler, made at this stream's rate).
    func play(_ engine: ChopEngine) { shared.pointee.engine = Unmanaged.passUnretained(engine) }

    var lost: Bool { shared.pointee.lost }

    func stop() {
        AAudio.close(stream)
        stream = nil
        free()
    }

    private var freed = false
    private func free() {
        guard !freed else { return }
        freed = true
        shared.pointee.left.deallocate()
        shared.pointee.right.deallocate()
        shared.deinitialize(count: 1)
        shared.deallocate()
    }

    deinit { if stream != nil { stop() } }

    private static let render: AAudioStream_dataCallback = { stream, user, data, frames in
        let out = data.assumingMemoryBound(to: Float.self)
        let n = Int(frames), oc = max(1, Int(AAudioStream_getChannelCount(stream)))
        guard let user else { out.update(repeating: 0, count: n * oc); return aaudio_data_callback_result_t(AAUDIO_CALLBACK_RESULT_CONTINUE) }
        let s = user.assumingMemoryBound(to: Shared.self)
        guard let e = s.pointee.engine?.takeUnretainedValue(), n <= most else {
            out.update(repeating: 0, count: n * oc)
            return aaudio_data_callback_result_t(AAUDIO_CALLBACK_RESULT_CONTINUE)
        }
        let l = s.pointee.left, r = s.pointee.right
        e.render(l, r, n)
        for i in 0..<n {
            if oc == 1 { out[i] = (l[i] + r[i]) / 2; continue }
            out[i * oc] = l[i]
            out[i * oc + 1] = r[i]
            for c in 2..<max(2, oc) { out[i * oc + c] = 0 }
        }
        return aaudio_data_callback_result_t(AAUDIO_CALLBACK_RESULT_CONTINUE)
    }

    private static let failed: AAudioStream_errorCallback = { _, user, _ in
        user?.assumingMemoryBound(to: Shared.self).pointee.lost = true
    }
}

/// Takes in a sound: this phone's microphone, or the OP-Z over the cable. Mono, at the device's rate, at most 4 million samples.
final class Recorder {
    private struct Taken { var x: [Float] = []; var level: Float = 0; var lost = false }
    private let taken = Mutex(Taken())
    private var stream: OpaquePointer?
    private(set) var rate = 48_000.0

    init(device: Int32, opz: Bool) throws(AudioRefused) {
        let user = Unmanaged.passUnretained(self).toOpaque()
        let s = try AAudio.open { b in
            AAudioStreamBuilder_setDirection(b, aaudio_direction_t(AAUDIO_DIRECTION_INPUT))
            if device != 0 { AAudioStreamBuilder_setDeviceId(b, device) }
            AAudioStreamBuilder_setFormat(b, aaudio_format_t(AAUDIO_FORMAT_PCM_FLOAT))
            AAudioStreamBuilder_setPerformanceMode(b, aaudio_performance_mode_t(AAUDIO_PERFORMANCE_MODE_LOW_LATENCY))
            // the OP-Z as it is; the microphone as for music, not a call
            AAudioStreamBuilder_setInputPreset(b, aaudio_input_preset_t(opz ? AAUDIO_INPUT_PRESET_UNPROCESSED : AAUDIO_INPUT_PRESET_CAMCORDER))
            AAudioStreamBuilder_setDataCallback(b, Self.listen, user)
            AAudioStreamBuilder_setErrorCallback(b, Self.failed, user)
        }
        stream = s
        rate = Double(AAudioStream_getSampleRate(s))
        do { try AAudio.ok(AAudioStream_requestStart(s), "starting the recording") } catch { AAudio.close(s); stream = nil; throw error }
    }

    /// Seconds so far, and how loud lately.
    var state: (Double, Float) {
        let rate = rate
        return taken.withLock { t in defer { t.level *= 0.8 }; return (Double(t.x.count) / rate, t.level) }
    }

    var lost: Bool { taken.withLock { $0.lost } }

    func stop() -> ([Float], Double) {
        AAudio.close(stream)
        stream = nil
        return (taken.withLock { $0.x }, rate)
    }

    deinit { AAudio.close(stream) }

    private func put(_ p: UnsafePointer<Float>, frames n: Int, channels c: Int) {
        var part = [Float](repeating: 0, count: n), peak: Float = 0
        for i in 0..<n {
            var v: Float = 0
            for k in 0..<min(2, c) { v += p[i * c + k] }
            v /= Float(min(2, c))
            part[i] = v.isFinite ? v : 0
            peak = max(peak, abs(part[i]))
        }
        taken.withLock { t in if t.x.count < 4_000_000 { t.x += part }; t.level = max(t.level, peak) }
    }

    private static let listen: AAudioStream_dataCallback = { stream, user, data, frames in
        if let user {
            let r = Unmanaged<Recorder>.fromOpaque(user).takeUnretainedValue()
            r.put(data.assumingMemoryBound(to: Float.self), frames: Int(frames), channels: max(1, Int(AAudioStream_getChannelCount(stream))))
        }
        return aaudio_data_callback_result_t(AAUDIO_CALLBACK_RESULT_CONTINUE)
    }

    private static let failed: AAudioStream_errorCallback = { _, user, _ in
        guard let user else { return }
        Unmanaged<Recorder>.fromOpaque(user).takeUnretainedValue().taken.withLock { $0.lost = true }
    }
}
#else
// On a Mac (the core's tests) there is no sound: the sampler says so.
final class ChopsOut {
    let rate = 48_000
    init(device: Int32) throws(AudioRefused) { throw AudioRefused("no sound on this platform") }
    func play(_ engine: ChopEngine) {}
    var lost: Bool { true }
    func stop() {}
}

final class Recorder {
    init(device: Int32, opz: Bool) throws(AudioRefused) { throw AudioRefused("no recording on this platform") }
    var state: (Double, Float) { (0, 0) }
    var lost: Bool { true }
    func stop() -> ([Float], Double) { ([], 48_000) }
}
#endif
