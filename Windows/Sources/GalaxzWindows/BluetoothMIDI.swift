#if os(Windows)
import CGalaxzBluetooth
import Foundation
import GalaxzAndroid
import GalaxzDesktop

/// The OP-Z over Bluetooth MIDI. Windows reaches Bluetooth MIDI only through WinRT (`CGalaxzBluetooth`), and every WinRT call
/// waits, so all of it runs on one thread of its own: it finds a paired OP-Z and opens it, looks for unpaired ones near while
/// PAIR is open, and pairs the one asked for. A cable comes first: while `WinMIDI` has the OP-Z over USB, this lets go.
///
/// What it found is read under `lock` by the window; bytes from the OP-Z come on Windows' threads, to `received`.
final class BluetoothMIDI: @unchecked Sendable {
    struct Device: Equatable { let id, name: String }

    private let lock = NSLock()
    private var link: UnsafeMutableRawPointer?
    private var linkName: String?
    private var allowed = true
    private var scanning = false
    private var pairing: Device?
    private var _nearby: [Device] = []
    private var _paired: [String] = []
    private var _radio = 1
    private var _note = ""
    private var _looked = false
    private var lastNear = -1, lastPorts: [String] = ["-"]          // logged when they change
    /// An OP-Z that is paired but off (or with a phone) does not open: tried again after a while, not at every look.
    private var retryAt = 0.0
    /// Bytes from the OP-Z, on a thread of Windows'.
    var received: ([UInt8]) -> Void = { _ in }
    /// The OP-Z opened (its name) or let go (nil): posted to the window's thread.
    var changed: (String?) -> Void = { _ in }
    private let main: MainQueue

    init(main: MainQueue) {
        self.main = main
        let t = Thread { [weak self] in self?.run() }
        t.name = "galaxz-bluetooth"
        t.start()
    }

    // MARK: what the window reads

    /// Unpaired OP-Zs near, from the last look (only while PAIR is open).
    var nearby: [Device] { lock.lock(); defer { lock.unlock() }; return _nearby }
    /// The names of paired OP-Zs Windows has MIDI ports for now (on and in reach).
    var paired: [String] { lock.lock(); defer { lock.unlock() }; return _paired }
    /// The one open now, by name.
    var connectedName: String? { lock.lock(); defer { lock.unlock() }; return linkName }
    /// 0 no Bluetooth on this computer, 1 on, 2 switched off.
    var radio: Int { lock.lock(); defer { lock.unlock() }; return _radio }
    /// The last thing to say (pairing, a failure).
    var note: String { lock.lock(); defer { lock.unlock() }; return _note }
    var isPairing: Bool { lock.lock(); defer { lock.unlock() }; return pairing != nil }
    /// A look for nearby devices has finished since PAIR opened.
    var looked: Bool { lock.lock(); defer { lock.unlock() }; return _looked }

    /// PAIR is open: look for OP-Zs near.
    func scan(_ on: Bool) {
        lock.lock()
        scanning = on
        if on { _looked = false; _note = "" } else { _nearby = [] }
        lock.unlock()
    }

    func pair(_ d: Device) {
        lock.lock()
        if pairing == nil { pairing = d; _note = "PAIRING \(d.name.uppercased())…" }
        lock.unlock()
    }

    /// A cable has the OP-Z (false): Bluetooth lets go and opens nothing until it is gone.
    func allow(_ on: Bool) {
        lock.lock()
        allowed = on
        lock.unlock()
    }

    /// One whole message to the OP-Z (on the sender's thread). False when it is not open.
    @discardableResult
    func send(_ bytes: [UInt8]) -> Bool {
        lock.lock()
        let l = link
        lock.unlock()
        guard let l else { return false }
        return bytes.withUnsafeBufferPointer { galaxz_bt_send(l, $0.baseAddress, $0.count) } == 0
    }

    var isOpen: Bool { lock.lock(); defer { lock.unlock() }; return link != nil }

    // MARK: the thread

    private func run() {
        let r = galaxz_bt_init()
        if r != 0 { Log.say("Bluetooth: WinRT would not start on its thread (HRESULT \(r))") }
        var nextPorts = 0.0, nextRadio = 0.0
        while true {
            let now = DesktopCore.now()
            if now >= nextRadio {
                nextRadio = now + 5
                let radio = Int(galaxz_bt_radio())
                lock.lock(); _radio = radio; lock.unlock()
            }
            lock.lock()
            let want = pairing, scan = scanning
            lock.unlock()
            if let want { pairNow(want); nextPorts = 0 }
            if now >= nextPorts {
                nextPorts = now + 3
                ports()
            }
            if scan {
                let all = Self.lines(4000) { galaxz_bt_nearby(4000, $0, $1) }
                let found = all
                    .compactMap { l -> Device? in
                        let f = l.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                        return f.count == 2 && WinMIDI.isOPZ(f[1]) ? Device(id: f[0], name: f[1]) : nil
                    }
                if all.count != lastNear {
                    lastNear = all.count
                    Log.say("Bluetooth: \(all.count) devices near, not paired; OP-Z: \(found.map(\.name).joined(separator: ", "))")
                }
                lock.lock()
                if scanning { _nearby = found; _looked = true }
                lock.unlock()
            } else {
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
    }

    /// The OP-Z's MIDI ports over Bluetooth: open them when there are, let go when they are gone (or a cable has it).
    private func ports() {
        let all = Self.lines(0) { galaxz_bt_ports($0, $1) }
        if let bad = all.first, bad.hasPrefix("!") { Log.say("Bluetooth: no MIDI ports from Windows: \(bad.dropFirst())"); return }
        if all != lastPorts {                       // which ports WinRT has, and their ids: what tells Bluetooth from a cable
            lastPorts = all
            Log.say("Bluetooth: WinRT's MIDI ports now: " + (all.isEmpty ? "none" : all.joined(separator: " | ")))
        }
        var ins: [(String, String)] = [], outs: [(String, String)] = []
        for l in all {
            let f = l.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count == 3, WinMIDI.isOPZ(f[2]), Self.isBluetooth(id: f[1], name: f[2]) else { continue }
            if f[0] == "in" { ins.append((f[1], f[2])) } else { outs.append((f[1], f[2])) }
        }
        lock.lock()
        _paired = Array(Set(ins.map { Self.plain($0.1) })).sorted()
        let open = link, ok = allowed
        lock.unlock()
        if let open {
            if !ok || ins.isEmpty || outs.isEmpty {
                Log.say(ok ? "Bluetooth: the OP-Z went away" : "Bluetooth: a cable has the OP-Z, letting go")
                lock.lock(); link = nil; linkName = nil; lock.unlock()
                galaxz_bt_close(open)
                main.post { [weak self] in self?.changed(nil) }
            }
            return
        }
        guard ok, let i = ins.first, let o = outs.first(where: { Self.plain($0.1) == Self.plain(i.1) }) ?? outs.first else {
            if !ins.isEmpty || !outs.isEmpty { Log.say("Bluetooth: not opening (\(ok ? "\(ins.count) in, \(outs.count) out" : "a cable has it"))") }
            return
        }
        guard DesktopCore.now() >= retryAt else { return }
        Log.say("Bluetooth: opening \(Self.plain(i.1))")
        let me = Unmanaged.passUnretained(self).toOpaque()
        let l = i.0.withCString(encodedAs: UTF16.self) { inID in
            o.0.withCString(encodedAs: UTF16.self) { outID in galaxz_bt_open(inID, outID, me, btReceive) }
        }
        guard let l else {
            // Windows keeps a paired device's ports, but they open only while it is on and connected to this computer
            retryAt = DesktopCore.now() + 10
            say("PAIRED, NOT CONNECTED: SWITCH THE OP-Z ON (OR OFF AND ON). IF YOUR PHONE HAS IT, CLOSE TE'S APP THERE.")
            Log.say("Bluetooth: \(Self.plain(i.1)) does not open (off, or with another device): trying again in 10 s")
            return
        }
        let name = "OP-Z"
        lock.lock(); link = l; linkName = Self.plain(i.1); _note = ""; lock.unlock()
        Log.say("Bluetooth: OP-Z opened: in \(i.0), out \(o.0)")
        main.post { [weak self] in self?.changed(name) }
    }

    private func pairNow(_ d: Device) {
        let r = d.id.withCString(encodedAs: UTF16.self) { galaxz_bt_pair($0) }
        Log.say("Bluetooth: pairing \(d.name) (\(d.id)): \(r)")
        let text: String
        switch r {
        case 0, 19: text = "\(d.name.uppercased()) IS PAIRED. IT CONNECTS IN A FEW SECONDS."
        case 3: text = "\(d.name.uppercased()) IS NOT READY TO PAIR: SWITCH IT OFF AND ON, AND TRY AGAIN"
        case 8, 9: text = "PAIRING WAS CANCELLED OR TIMED OUT: TRY AGAIN WITH THE OP-Z CLOSE BY"
        case -1: text = "WINDOWS COULD NOT BE ASKED TO PAIR: USE WINDOWS' BLUETOOTH SETTINGS"
        default: text = "PAIRING FAILED (WINDOWS SAYS \(r)): TRY WINDOWS' BLUETOOTH SETTINGS"
        }
        lock.lock()
        pairing = nil
        _note = text
        if r == 0 || r == 19 { _nearby.removeAll { $0 == d } }
        lock.unlock()
    }

    private func say(_ s: String) { lock.lock(); _note = s; lock.unlock() }

    /// A MIDI port of a Bluetooth LE device. Windows 11 names them `\?\SWD#MMDEVAPI#MIDII_….BLE10#{…}` and
    /// "OP-Z (Bluetooth MIDI IN)" (seen on an OP-Z); older ones may name the Bluetooth LE bus or the BLE MIDI service.
    static func isBluetooth(id: String, name: String) -> Bool {
        let s = id.lowercased()
        return s.contains(".ble") || s.contains("bthle") || s.contains("03b80e5a-ede8-4b33-a751-6ce34ec4c700")
            || name.lowercased().contains("bluetooth")
    }

    /// "OP-Z (Bluetooth MIDI IN)" as "OP-Z".
    static func plain(_ name: String) -> String {
        guard let cut = name.range(of: " (Bluetooth", options: .caseInsensitive) else { return name }
        return String(name[..<cut.lowerBound])
    }

    /// The text a WinRT call fills in, as lines (asked twice when the first buffer is too small).
    private static func lines(_ hint: Int, _ call: (UnsafeMutablePointer<wchar_t>?, Int32) -> Int32) -> [String] {
        var buf = [wchar_t](repeating: 0, count: 16_384)
        var n = Int(buf.withUnsafeMutableBufferPointer { call($0.baseAddress, Int32($0.count)) })
        if n > buf.count {
            buf = [wchar_t](repeating: 0, count: n)
            n = Int(buf.withUnsafeMutableBufferPointer { call($0.baseAddress, Int32($0.count)) })
        }
        guard n > 1, n <= buf.count else { return [] }
        let text = String(decoding: buf[0..<(n - 1)].map { UInt16(truncatingIfNeeded: $0) }, as: UTF16.self)
        return text.split(separator: "\n").map(String.init)
    }

    fileprivate func bytes(_ b: [UInt8]) { received(b) }
}

/// WinRT hands each message from the OP-Z here; `context` is the `BluetoothMIDI` that opened it.
private let btReceive: galaxz_bt_receive = { context, bytes, count in
    guard let context, let bytes, count > 0 else { return }
    let b = [UInt8](UnsafeBufferPointer(start: bytes, count: count))
    Unmanaged<BluetoothMIDI>.fromOpaque(context).takeUnretainedValue().bytes(b)
}
#endif
