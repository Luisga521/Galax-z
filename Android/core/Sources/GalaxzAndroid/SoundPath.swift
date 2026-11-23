#if os(Android)
import CAAudio
import OPZLink

/// The OP-Z's sound over the cable, played on this phone: its USB input read in the output stream's own callback, through the
/// same `SoundCopy` as on iOS and the Mac (a gain that glides, nothing louder than full scale). Nothing is recorded or kept.
/// The Kotlin side chooses the two devices (`Sound.kt`); this only joins them.
final class SoundPath {
    /// What the audio thread reads: one block, freed only after both streams are closed.
    private struct Shared {
        var copy = SoundCopy()
        var wanted: Float = 0
        var input: OpaquePointer?
        var channels = 2
        var buffer: UnsafeMutablePointer<Float>
        var capacity: Int                      // frames
        var primed = false
        var lost = false
    }

    private let shared: UnsafeMutablePointer<Shared>
    private var input: OpaquePointer?
    private var output: OpaquePointer?
    /// Frames a second, as the OP-Z gives them.
    private(set) var rate = 0

    /// Opens and starts both, or says why not.
    init(inputDevice: Int32, outputDevice: Int32, volume: Float) throws(Refused) {
        let capacity = 16_384
        shared = .allocate(capacity: 1)
        shared.initialize(to: Shared(buffer: .allocate(capacity: capacity * 8), capacity: capacity))
        shared.pointee.wanted = volume
        do throws(Refused) {
            // the OP-Z, as it is: no gain control, no noise taken out
            let i = try Self.open { b in
                AAudioStreamBuilder_setDirection(b, aaudio_direction_t(AAUDIO_DIRECTION_INPUT))
                AAudioStreamBuilder_setDeviceId(b, inputDevice)
                AAudioStreamBuilder_setFormat(b, aaudio_format_t(AAUDIO_FORMAT_PCM_FLOAT))
                AAudioStreamBuilder_setPerformanceMode(b, aaudio_performance_mode_t(AAUDIO_PERFORMANCE_MODE_LOW_LATENCY))
                AAudioStreamBuilder_setInputPreset(b, aaudio_input_preset_t(AAUDIO_INPUT_PRESET_UNPROCESSED))
            }
            input = i
            let channels = Int(AAudioStream_getChannelCount(i))
            rate = Int(AAudioStream_getSampleRate(i))
            guard channels > 0, channels <= 8, rate > 0 else { throw Refused("The OP-Z's sound has no format (\(channels) channels, \(rate) Hz).") }
            shared.pointee.input = i
            shared.pointee.channels = channels
            // this phone's speaker, or what is plugged in or linked: at the OP-Z's rate, so nothing is converted on the way
            let o = try Self.open { b in
                AAudioStreamBuilder_setDirection(b, aaudio_direction_t(AAUDIO_DIRECTION_OUTPUT))
                AAudioStreamBuilder_setDeviceId(b, outputDevice)
                AAudioStreamBuilder_setFormat(b, aaudio_format_t(AAUDIO_FORMAT_PCM_FLOAT))
                AAudioStreamBuilder_setChannelCount(b, 2)
                AAudioStreamBuilder_setSampleRate(b, Int32(rate))
                AAudioStreamBuilder_setPerformanceMode(b, aaudio_performance_mode_t(AAUDIO_PERFORMANCE_MODE_LOW_LATENCY))
                AAudioStreamBuilder_setUsage(b, aaudio_usage_t(AAUDIO_USAGE_MEDIA))
                AAudioStreamBuilder_setContentType(b, aaudio_content_type_t(AAUDIO_CONTENT_TYPE_MUSIC))
                AAudioStreamBuilder_setDataCallback(b, Self.render, UnsafeMutableRawPointer(shared))
                AAudioStreamBuilder_setErrorCallback(b, Self.failed, UnsafeMutableRawPointer(shared))
            }
            output = o
            // two bursts of buffer: as little delay as the device keeps up with
            AAudioStream_setBufferSizeInFrames(o, AAudioStream_getFramesPerBurst(o) * 2)
            try Self.ok(AAudioStream_requestStart(i), "starting the OP-Z's sound")
            try Self.ok(AAudioStream_requestStart(o), "starting this phone's sound")
        } catch {
            close()
            throw error
        }
    }

    struct Refused: Error { let why: String; init(_ why: String) { self.why = why } }

    var volume: Float {
        get { shared.pointee.wanted }
        set { shared.pointee.wanted = newValue }
    }

    /// A device went away under it (the cable out, headphones off): start again.
    var lost: Bool { shared.pointee.lost }

    func stop() { close() }

    private func close() {
        if let output { AAudioStream_requestStop(output); AAudioStream_close(output) }     // waits for its callback to end
        if let input { AAudioStream_requestStop(input); AAudioStream_close(input) }
        output = nil
        input = nil
        shared.pointee.buffer.deallocate()
        shared.deinitialize(count: 1)
        shared.deallocate()
    }

    deinit { if output != nil || input != nil { close() } }

    // MARK: AAudio

    private static func open(_ set: (OpaquePointer) -> Void) throws(Refused) -> OpaquePointer {
        var b: OpaquePointer?
        try ok(AAudio_createStreamBuilder(&b), "making a stream")
        guard let b else { throw Refused("No stream.") }
        defer { AAudioStreamBuilder_delete(b) }
        set(b)
        var s: OpaquePointer?
        try ok(AAudioStreamBuilder_openStream(b, &s), "opening a stream")
        guard let s else { throw Refused("No stream.") }
        return s
    }

    private static func ok(_ r: aaudio_result_t, _ what: String) throws(Refused) {
        guard r == AAUDIO_OK else {
            let why = String(cString: AAudio_convertResultToText(r))
            throw Refused("Android refused \(what): \(why).")
        }
    }

    /// The audio thread: what came from the OP-Z since the last time, out at once.
    private static let render: AAudioStream_dataCallback = { stream, user, data, frames in
        guard let user else { return aaudio_data_callback_result_t(AAUDIO_CALLBACK_RESULT_CONTINUE) }
        let s = user.assumingMemoryBound(to: Shared.self)
        let out = data.assumingMemoryBound(to: Float.self)
        let n = Int(frames), oc = max(1, Int(AAudioStream_getChannelCount(stream)))
        out.update(repeating: 0, count: n * oc)
        guard let input = s.pointee.input else { return aaudio_data_callback_result_t(AAUDIO_CALLBACK_RESULT_CONTINUE) }
        let ch = s.pointee.channels, cap = s.pointee.capacity
        // the first time, and whenever too much has piled up (the two clocks drift): only the newest is kept
        let waiting = Int(AAudioStream_getFramesWritten(input) - AAudioStream_getFramesRead(input))
        if !s.pointee.primed || waiting > n * 4 + 256 {
            var drop = s.pointee.primed ? waiting - n * 2 : waiting
            while drop > 0 {
                let got = AAudioStream_read(input, s.pointee.buffer, Int32(min(drop, cap)), 0)
                if got <= 0 { break }
                drop -= Int(got)
            }
            s.pointee.primed = true
        }
        let got = Int(AAudioStream_read(input, s.pointee.buffer, Int32(min(n, cap)), 0))
        if got > 0 {
            s.pointee.copy.copy(s.pointee.buffer, channels: ch, to: out, channels: oc, frames: got, wanted: s.pointee.wanted)
        }
        return aaudio_data_callback_result_t(AAUDIO_CALLBACK_RESULT_CONTINUE)
    }

    /// AAudio says a stream is gone; it may not be closed from here.
    private static let failed: AAudioStream_errorCallback = { _, user, _ in
        user?.assumingMemoryBound(to: Shared.self).pointee.lost = true
    }
}
#endif
