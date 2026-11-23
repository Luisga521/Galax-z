#if os(Android)
import CJNI
import Foundation
import OPZModel
import OPZStage

// What `org.galaxz.app.Core` (Kotlin) calls. Its threads differ (the screen draws on its own, MIDI comes on another):
// one lock around every call, so the core and the stage run as if on one thread.

private let lock = NSLock()
private var core: Core?

private func locked<T>(_ fallback: T, _ body: (Core) -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    guard let core else { return fallback }
    return body(core)
}

private func string(_ env: UnsafeMutablePointer<JNIEnv?>, _ s: jstring?) -> String? {
    guard let s, let f = env.pointee?.pointee, let chars = f.GetStringUTFChars(env, s, nil) else { return nil }
    defer { f.ReleaseStringUTFChars(env, s, chars) }
    return String(cString: chars)
}

private func jstr(_ env: UnsafeMutablePointer<JNIEnv?>, _ s: String) -> jstring? {
    s.withCString { env.pointee?.pointee.NewStringUTF(env, $0) }
}

private func buffer(_ env: UnsafeMutablePointer<JNIEnv?>, _ b: jobject?) -> (UnsafeMutableRawPointer, Int)? {
    guard let b, let f = env.pointee?.pointee, let p = f.GetDirectBufferAddress(env, b) else { return nil }
    return (p, Int(f.GetDirectBufferCapacity(env, b)))
}

/// `folder`: where the app keeps its files, the package's own (engines.json, demo-session.json) copied there from the APK.
@_cdecl("Java_org_galaxz_app_Core_start")
public func start(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ folder: jstring?, _ demo: jboolean) {
    let dir = URL(fileURLWithPath: string(env, folder) ?? "/data/local/tmp")
    lock.lock()
    defer { lock.unlock() }
    guard core == nil else { return }
    PackageFiles.folder = dir
    core = Core(folder: dir, demo: demo != 0)
}

/// Every 20 ms or so; true when there is something new to draw.
@_cdecl("Java_org_galaxz_app_Core_tick")
public func tick(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?) -> jboolean {
    locked(0) { c in c.tick(); defer { c.changed = false }; return c.changed ? 1 : 0 }
}

/// Draw a frame of `w` × `h` dots into `pixels` (RGBA, a direct buffer). Returns 1 when the picture is still, 2 when the
/// OP-Z plays (bits).
@_cdecl("Java_org_galaxz_app_Core_frame")
public func frame(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ pixels: jobject?, _ w: jint, _ h: jint, _ time: jdouble, _ dt: jdouble) -> jint {
    guard let (p, size) = buffer(env, pixels), w > 0, h > 0, Int(w) * Int(h) * 4 <= size else { return 0 }
    return locked(0) { c in
        c.canvas.resize(Int(w), Int(h))
        c.stage.frame(c.canvas, time: time, dt: dt)
        p.copyMemory(from: c.canvas.dots, byteCount: Int(w) * Int(h) * 4)
        return (c.stage.still ? 1 : 0) | (c.stage.playhead.playing ? 2 : 0)
    }
}

/// Bytes from the OP-Z; `timeNs` is Android's time stamp (System.nanoTime).
@_cdecl("Java_org_galaxz_app_Core_midiIn")
public func midiIn(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ data: jbyteArray?, _ offset: jint, _ count: jint, _ timeNs: jlong) {
    guard let data, count > 0, let f = env.pointee?.pointee else { return }
    var bytes = [UInt8](repeating: 0, count: Int(count))
    bytes.withUnsafeMutableBufferPointer { b in
        b.baseAddress!.withMemoryRebound(to: jbyte.self, capacity: b.count) { f.GetByteArrayRegion(env, data, offset, count, $0) }
    }
    let t = timeNs > 0 ? Double(timeNs) / 1e9 : monotonic()
    locked(()) { c in bytes.withUnsafeBufferPointer { c.midi($0, at: t) } }
}

/// Android opened an OP-Z (its name), or has none (null).
@_cdecl("Java_org_galaxz_app_Core_connected")
public func connected(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ name: jstring?, _ bluetooth: jboolean) {
    let n = string(env, name)
    locked(()) { $0.connected(n, bluetooth: bluetooth != 0) }
}

/// What to send, into `out` (a direct buffer): records of [time ns: 8][length: 2][bytes], little-endian; time 0 = now.
/// Returns the bytes written; what does not fit waits for the next call.
@_cdecl("Java_org_galaxz_app_Core_drainOut")
public func drainOut(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ out: jobject?) -> jint {
    guard let (p, size) = buffer(env, out) else { return 0 }
    return locked(0) { c in
        var at = 0
        var left: [(at: Double, bytes: [UInt8])] = []
        for m in c.takeOutgoing() {
            guard left.isEmpty, at + 10 + m.bytes.count <= size, m.bytes.count <= 0xFFFF else { left.append(m); continue }
            var ns = Int64(m.at * 1e9).littleEndian, n = UInt16(m.bytes.count).littleEndian
            withUnsafeBytes(of: &ns) { p.advanced(by: at).copyMemory(from: $0.baseAddress!, byteCount: 8) }
            withUnsafeBytes(of: &n) { p.advanced(by: at + 8).copyMemory(from: $0.baseAddress!, byteCount: 2) }
            m.bytes.withUnsafeBytes { p.advanced(by: at + 10).copyMemory(from: $0.baseAddress!, byteCount: m.bytes.count) }
            at += 10 + m.bytes.count
        }
        c.putBack(left)
        return jint(at)
    }
}

// touch: dots, as the screen lays them out

/// A tap: 0 nothing more, 1 the hub, 2 settings, 3 pair, 4 sound (`Stage.Action`).
@_cdecl("Java_org_galaxz_app_Core_tap")
public func tap(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ x: jint, _ y: jint) -> jint {
    locked(0) { c in
        c.changed = true
        switch c.stage.tap(Int(x), Int(y)) {
        case .none: return 0
        case .hub: return 1
        case .settings: return 2
        case .pair: return 3
        case .sound: return 4
        }
    }
}

@_cdecl("Java_org_galaxz_app_Core_holds")
public func holds(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ x: jint, _ y: jint) -> jboolean {
    locked(0) { $0.stage.holds(Int(x), Int(y)) ? 1 : 0 }
}

@_cdecl("Java_org_galaxz_app_Core_grab")
public func grab(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ id: jint, _ x: jint, _ y: jint) -> jboolean {
    locked(0) { c in c.changed = true; return c.stage.grab(Int(id), Int(x), Int(y)) ? 1 : 0 }
}

@_cdecl("Java_org_galaxz_app_Core_drag")
public func drag(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ id: jint, _ x: jint, _ y: jint) {
    locked(()) { c in c.changed = true; c.stage.drag(Int(id), Int(x), Int(y)) }
}

@_cdecl("Java_org_galaxz_app_Core_release")
public func release(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ id: jint, _ x: jint, _ y: jint) {
    locked(()) { c in c.changed = true; c.stage.release(Int(id), Int(x), Int(y)) }
}

/// Let go of everything held (the screen was covered).
@_cdecl("Java_org_galaxz_app_Core_letGo")
public func letGo(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?) {
    locked(()) { c in c.changed = true; c.stage.letGo() }
}

/// Pages: turn by one (a swipe, an arrow key).
@_cdecl("Java_org_galaxz_app_Core_turn")
public func turn(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ by: jint) {
    locked(()) { c in c.changed = true; c.stage.turn(Int(by)) }
}

@_cdecl("Java_org_galaxz_app_Core_setPage")
public func setPage(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ i: jint) {
    locked(()) { c in
        guard let p = Stage.Page(rawValue: Int(i)) else { return }
        c.changed = true
        c.stage.page = p
    }
}

@_cdecl("Java_org_galaxz_app_Core_selectTrack")
public func selectTrack(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ by: jint) {
    locked(()) { c in c.changed = true; c.stage.select(track: c.stage.track + Int(by)) }
}

@_cdecl("Java_org_galaxz_app_Core_useDemo")
public func useDemo(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ on: jboolean) {
    locked(()) { $0.useDemo(on != 0) }
}

@_cdecl("Java_org_galaxz_app_Core_isDemo")
public func isDemo(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?) -> jboolean {
    locked(0) { $0.source == .demo ? 1 : 0 }
}

@_cdecl("Java_org_galaxz_app_Core_reload")
public func reload(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?) {
    locked(()) { $0.reload() }
}

/// What to do while there is no OP-Z, said under the name.
@_cdecl("Java_org_galaxz_app_Core_linkLine")
public func linkLine(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ line: jstring?, _ hint: jstring?) {
    let l = string(env, line) ?? "", h = string(env, hint) ?? ""
    locked(()) { c in c.linkLine = l; c.linkHint = h }
}

/// The page and what is on it, in words (TalkBack).
@_cdecl("Java_org_galaxz_app_Core_spoken")
public func spoken(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?) -> jstring? {
    jstr(env, locked("") { $0.stage.spoken })
}

// sound: the OP-Z's, through this phone (`Sound.kt` chooses the devices)

private let soundLock = NSLock()
private var sound: SoundPath?

/// Join the OP-Z's input to an output; "" when it plays, else why not.
@_cdecl("Java_org_galaxz_app_Core_soundStart")
public func soundStart(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ input: jint, _ output: jint, _ volume: jfloat) -> jstring? {
    soundLock.lock()
    defer { soundLock.unlock() }
    sound?.stop()
    sound = nil
    do throws(SoundPath.Refused) {
        sound = try SoundPath(inputDevice: input, outputDevice: output, volume: volume)
        return jstr(env, "")
    } catch {
        return jstr(env, error.why)
    }
}

@_cdecl("Java_org_galaxz_app_Core_soundStop")
public func soundStop(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?) {
    soundLock.lock()
    defer { soundLock.unlock() }
    sound?.stop()
    sound = nil
}

@_cdecl("Java_org_galaxz_app_Core_soundVolume")
public func soundVolume(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ volume: jfloat) {
    soundLock.lock()
    defer { soundLock.unlock() }
    sound?.volume = volume
}

/// False once a device went away under it.
@_cdecl("Java_org_galaxz_app_Core_soundAlive")
public func soundAlive(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?) -> jboolean {
    soundLock.lock()
    defer { soundLock.unlock() }
    return sound.map { $0.lost ? 0 : 1 } ?? 0
}

/// Where the OP-Z is heard, said in the top corner ("OUT PHONE"); null when there is no choice (no cable).
@_cdecl("Java_org_galaxz_app_Core_setOut")
public func setOut(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ line: jstring?) {
    let l = string(env, line)
    locked(()) { $0.out = l }
}

// the chops: what the Kotlin side finds and does for the sampler

/// The devices to use: the output (0: Android's own choice), this phone's microphone, the OP-Z's sound; whether recording is allowed.
@_cdecl("Java_org_galaxz_app_Core_chopsDevices")
public func chopsDevices(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ output: jint, _ mic: jint, _ opz: jint, _ allowed: jboolean) {
    locked(()) { $0.sampler.devices = .init(output: output, microphone: mic, opz: opz, allowed: allowed != 0) }
}

/// What the sampler wants of the Kotlin side, taken once: 1 a file to open, 2 the microphone allowed (bits).
@_cdecl("Java_org_galaxz_app_Core_chopsRequests")
public func chopsRequests(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?) -> jint {
    locked(0) { c in
        defer { c.sampler.tookRequests() }
        return (c.sampler.wantsFile ? 1 : 0) | (c.sampler.wantsMicrophone ? 2 : 0)
    }
}

/// A sound file, decoded by Android: mono samples at their rate.
@_cdecl("Java_org_galaxz_app_Core_chopsOpen")
public func chopsOpen(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ data: jfloatArray?, _ rate: jint, _ name: jstring?) {
    guard let data, let f = env.pointee?.pointee else { return }
    let n = Int(f.GetArrayLength(env, data))
    var x = [Float](repeating: 0, count: n)
    if n > 0 { x.withUnsafeMutableBufferPointer { b in f.GetFloatArrayRegion(env, data, 0, jsize(n), b.baseAddress!) } }
    let title = string(env, name) ?? "FILE"
    locked(()) { c in c.sampler.open(x, rate: Double(rate), name: title); c.changed = true }
}

/// Something could not be done on the Kotlin side: said on the CHOPS page.
@_cdecl("Java_org_galaxz_app_Core_chopsTell")
public func chopsTell(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ line: jstring?) {
    let l = string(env, line) ?? ""
    locked(()) { $0.sampler.tell(l) }
}

// Settings, the key test, LEARN: JSON out, a word and an argument in (`Settings.swift`)

@_cdecl("Java_org_galaxz_app_Core_query")
public func query(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ what: jstring?) -> jstring? {
    let w = string(env, what) ?? ""
    return jstr(env, locked("{}") { $0.query(w) })
}

@_cdecl("Java_org_galaxz_app_Core_command")
public func command(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ what: jstring?, _ arg: jstring?) -> jstring? {
    let w = string(env, what) ?? "", a = string(env, arg) ?? ""
    return jstr(env, locked("") { $0.command(w, a) })
}

/// Bytes from a controller that is not the OP-Z, by its name.
@_cdecl("Java_org_galaxz_app_Core_controllerIn")
public func controllerIn(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ name: jstring?, _ data: jbyteArray?, _ offset: jint, _ count: jint) {
    guard let data, count > 0, let f = env.pointee?.pointee else { return }
    let n = string(env, name) ?? "?"
    var bytes = [UInt8](repeating: 0, count: Int(count))
    bytes.withUnsafeMutableBufferPointer { b in
        b.baseAddress!.withMemoryRebound(to: jbyte.self, capacity: b.count) { f.GetByteArrayRegion(env, data, offset, count, $0) }
    }
    locked(()) { c in bytes.withUnsafeBufferPointer { c.controllers.midi(n, $0) } }
}

/// The matrix's type: [width, height, 1 for each lit dot]. Fonts: 0 tiny, 1 small, 2 big, 3 huge.
@_cdecl("Java_org_galaxz_app_Core_dotText")
public func dotTextJNI(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ text: jstring?, _ font: jint) -> jintArray? {
    let d = dotText(string(env, text) ?? "", font: Int(font))
    guard let f = env.pointee?.pointee, let a = f.NewIntArray(env, jsize(d.count)) else { return nil }
    d.withUnsafeBufferPointer { f.SetIntArrayRegion(env, a, 0, jsize(d.count), $0.baseAddress) }
    return a
}
#endif
