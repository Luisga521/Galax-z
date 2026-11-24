#if os(Windows)
import Foundation
import GalaxzAndroid
import GalaxzDesktop
import WinSDK

/// The OP-Z over a USB-C cable, through Windows' own MIDI (WinMM): `Android/…/MidiLink.kt` for Windows. Finds it by name,
/// opens its input and output, hands what it says to the core and sends what the core says, each message at its time.
/// Windows gives a MIDI device to one program at a time: TE's app or a DAW holding it keeps Galax-z out (it says so).
/// Without a cable, the OP-Z over Bluetooth (`BluetoothMIDI`, once it is paired): the cable comes first.
///
/// Threads: the window's (look, open, close), WinMM's (`received`), the sender's (`send`). `inLock` guards the input and
/// its buffers, `outLock` the output; no WinMM call that may wait for the callback is made while holding `inLock`.
final class WinMIDI {
    let core: DesktopCore
    private let inLock = NSLock(), outLock = NSLock()
    private var input: HMIDIIN?
    private var output: HMIDIOUT?
    private var buffers: [UnsafeMutablePointer<MIDIHDR>] = []
    private var closing = false
    private(set) var connected = false
    private var sender: TimedSender!
    private var nextLook = 0.0
    private var listenUntil = 0.0
    private var heard = false                   // a SysEx came back since this output was opened
    private var outAt = 0                       // which of the OP-Z's outputs (it can have two)
    private var said = ""
    private var urgent = false                  // the sender's thread runs ahead of drawing (set on that thread)
    /// The OP-Z over Bluetooth, when there is no cable.
    let bluetooth: BluetoothMIDI
    private(set) var overBluetooth = false

    static let headerSize = UINT(MemoryLayout<MIDIHDR>.size)

    init(core: DesktopCore, main: MainQueue) {
        self.core = core
        bluetooth = BluetoothMIDI(main: main)
        outAt = (try? String(contentsOf: Self.choiceFile, encoding: .utf8)).flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0
        sender = TimedSender(clock: DesktopCore.now) { [weak self] bytes in self?.send(bytes) }
        bluetooth.received = { [weak self] bytes in
            guard let self else { return }
            self.core.midiIn(bytes, at: DesktopCore.now())
            self.pump()
        }
        bluetooth.changed = { [weak self] name in self?.bluetoothChanged(name) }
    }

    /// On the window's thread: the OP-Z came or went over Bluetooth. A cable that has it meanwhile is not disturbed.
    private func bluetoothChanged(_ name: String?) {
        if let name {
            guard !connected else { return }
            overBluetooth = true
            said = ""
            Log.say("the OP-Z is here over Bluetooth")
            core.connected(name, bluetooth: true)
            core.offerPairing(false)
            pump()
        } else if overBluetooth {
            overBluetooth = false
            sender.clear()
            if !connected { core.connected(nil); core.offerPairing(true) }
            nextLook = 0
        }
    }

    private static var choiceFile: URL { Folders.support.appendingPathComponent("opz-port.txt") }

    // MARK: finding it

    static func text(_ name: (WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR,
                              WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR, WCHAR)) -> String {
        withUnsafeBytes(of: name) { String(decoding: $0.bindMemory(to: UInt16.self).prefix { $0 != 0 }, as: UTF16.self) }
    }

    static func inputs() -> [(id: UINT, name: String)] {
        var out: [(id: UINT, name: String)] = []
        let n = midiInGetNumDevs()
        var i: UINT = 0
        while i < n {
            var caps = MIDIINCAPSW()
            if midiInGetDevCapsW(UINT_PTR(i), &caps, UINT(MemoryLayout<MIDIINCAPSW>.size)) == 0 { out.append((i, text(caps.szPname))) }
            i += 1
        }
        return out
    }

    static func outputs() -> [(id: UINT, name: String)] {
        var out: [(id: UINT, name: String)] = []
        let n = midiOutGetNumDevs()
        var i: UINT = 0
        while i < n {
            var caps = MIDIOUTCAPSW()
            if midiOutGetDevCapsW(UINT_PTR(i), &caps, UINT(MemoryLayout<MIDIOUTCAPSW>.size)) == 0 { out.append((i, text(caps.szPname))) }
            i += 1
        }
        return out
    }

    static func isOPZ(_ name: String) -> Bool {
        name.lowercased().replacingOccurrences(of: "\u{2013}", with: "-").replacingOccurrences(of: "\u{2011}", with: "-").contains("op-z")
    }

    /// Every couple of seconds, and at once when Windows says a device came or went: open the OP-Z, notice it gone, try its
    /// other output when it does not answer.
    func look(_ now: Double, soon: Bool = false) {
        if soon { nextLook = 0 }
        guard now >= nextLook else { return }
        nextLook = now + 2
        let ins = Self.inputs().filter { Self.isOPZ($0.name) }, outs = Self.outputs().filter { Self.isOPZ($0.name) }
        // a cable comes first: Bluetooth lets go while there is one
        bluetooth.allow(ins.isEmpty || outs.isEmpty)
        if connected {
            if ins.isEmpty || outs.isEmpty { Log.say("the OP-Z went away"); close(); return }
            if !heard, now > listenUntil, outs.count > 1 {
                // over USB the OP-Z may have two outputs, and nothing says which one takes the session: try the next
                outAt = (outAt + 1) % outs.count
                Log.say("no answer from the OP-Z: trying its output \(outAt + 1) of \(outs.count)")
                close()
                open(input: ins[0], output: outs[outAt], now: now)
            } else if heard, listenUntil > 0 {
                listenUntil = 0
                try? String(outAt).write(to: Self.choiceFile, atomically: true, encoding: .utf8)
            }
            return
        }
        guard let i = ins.first, !outs.isEmpty else {
            core.offerPairing(!overBluetooth)
            if !overBluetooth { tell("PLUG IN YOUR OP-Z WITH A USB-C CABLE, OR PAIR IT") }
            return
        }
        if overBluetooth { overBluetooth = false; sender.clear() }       // the cable takes over
        core.offerPairing(false)
        open(input: i, output: outs[min(outAt, outs.count - 1)], now: now)
    }

    private func tell(_ line: String) {
        guard line != said else { return }
        said = line
        core.linkLine(line)
    }

    // MARK: opening and closing

    private func open(input i: (id: UINT, name: String), output o: (id: UINT, name: String), now: Double) {
        var inH: HMIDIIN? = nil, outH: HMIDIOUT? = nil
        let me = DWORD_PTR(UInt(bitPattern: Unmanaged.passUnretained(self).toOpaque()))
        let proc = DWORD_PTR(UInt(bitPattern: unsafeBitCast(midiInProc, to: Int.self)))
        var r = midiInOpen(&inH, i.id, proc, me, DWORD(CALLBACK_FUNCTION))
        if r == 0 { r = midiOutOpen(&outH, o.id, 0, 0, 0) }
        guard r == 0, let inH, let outH else {
            if let inH { midiInClose(inH) }
            Log.say("cannot open the OP-Z (\(i.name) / \(o.name)): MMRESULT \(r)")
            tell(r == 4 ? "CLOSE THE OTHER APP THAT HAS THE OP-Z (TE'S APP, A DAW)" : "WINDOWS WILL NOT OPEN THE OP-Z (ERROR \(r))")
            return
        }
        // SysEx comes into buffers of ours; each is given back to Windows once read
        var made: [UnsafeMutablePointer<MIDIHDR>] = []
        for _ in 0..<16 {
            let h = UnsafeMutablePointer<MIDIHDR>.allocate(capacity: 1)
            h.initialize(to: MIDIHDR())
            h.pointee.lpData = UnsafeMutablePointer<CChar>.allocate(capacity: 8192)
            h.pointee.dwBufferLength = 8192
            midiInPrepareHeader(inH, h, Self.headerSize)
            made.append(h)
        }
        inLock.lock()
        (input, buffers, closing) = (inH, made, false)
        inLock.unlock()
        outLock.lock()
        output = outH
        outLock.unlock()
        for h in made { midiInAddBuffer(inH, h, Self.headerSize) }
        midiInStart(inH)
        (connected, heard, listenUntil, said) = (true, false, now + 3, "")
        Log.say("OP-Z opened: in \(i.name), out \(o.name)")
        core.connected("OP-Z")
        pump()
    }

    func close() {
        inLock.lock()
        closing = true
        let inH = input, made = buffers
        (input, buffers) = (nil, [])
        inLock.unlock()
        outLock.lock()                       // a send in progress ends first
        let outH = output
        output = nil
        outLock.unlock()
        sender.clear()
        if let h = inH {
            midiInStop(h)
            midiInReset(h)                   // every buffer comes back (the callback sees `closing` and keeps them)
            for b in made { midiInUnprepareHeader(h, b, Self.headerSize) }
            midiInClose(h)
            for b in made { b.pointee.lpData?.deallocate(); b.deallocate() }
        }
        if let h = outH { midiOutReset(h); midiOutClose(h) }
        if connected { connected = false; core.connected(nil) }
    }

    // MARK: in

    /// On WinMM's own thread.
    fileprivate func received(_ msg: UINT, _ p1: DWORD_PTR) {
        let now = DesktopCore.now()
        if msg == 0x3C3 {                            // MIM_DATA: a short message, packed in p1
            let status = UInt8(truncatingIfNeeded: p1)
            let n: Int
            switch status {
            case 0x80...0xBF, 0xE0...0xEF, 0xF2: n = 3
            case 0xC0...0xDF, 0xF1, 0xF3: n = 2
            default: n = 1
            }
            var bytes: [UInt8] = []
            for k in 0..<n { bytes.append(UInt8(truncatingIfNeeded: UInt64(p1) >> UInt64(8 * k))) }
            core.midiIn(bytes, at: now)
        } else if msg == 0x3C4 {                     // MIM_LONGDATA: a SysEx, or part of one
            guard let h = UnsafeMutablePointer<MIDIHDR>(bitPattern: UInt(p1)) else { return }
            let n = Int(h.pointee.dwBytesRecorded)
            if n > 0, let data = h.pointee.lpData {
                let bytes = [UInt8](UnsafeRawBufferPointer(start: UnsafeRawPointer(data), count: n))
                if bytes.contains(0xF0) { heard = true }
                core.midiIn(bytes, at: now)
            }
            inLock.lock()
            let again = closing ? nil : input
            inLock.unlock()
            if let again { midiInAddBuffer(again, h, Self.headerSize) }
        } else {
            return
        }
        pump()
    }

    // MARK: out

    /// Take everything the core has to say and hand it to the sender, which keeps each message's time.
    func pump() { sender.add(core.takeOutgoing()) }

    /// On the sender's thread, in order.
    private func send(_ bytes: [UInt8]) {
        if !urgent { urgent = true; SetThreadPriority(GetCurrentThread(), 15) }      // THREAD_PRIORITY_TIME_CRITICAL: drawing never delays a note
        outLock.lock()
        defer { outLock.unlock() }
        guard !bytes.isEmpty else { return }
        guard let h = output else { bluetooth.send(bytes); return }
        if bytes[0] == 0xF0 {
            let hdr = UnsafeMutablePointer<MIDIHDR>.allocate(capacity: 1)
            hdr.initialize(to: MIDIHDR())
            let data = UnsafeMutableRawPointer.allocate(byteCount: bytes.count, alignment: 1)
            bytes.withUnsafeBytes { data.copyMemory(from: $0.baseAddress!, byteCount: bytes.count) }
            hdr.pointee.lpData = data.assumingMemoryBound(to: CChar.self)
            hdr.pointee.dwBufferLength = DWORD(bytes.count)
            hdr.pointee.dwBytesRecorded = DWORD(bytes.count)
            if midiOutPrepareHeader(h, hdr, Self.headerSize) == 0 {
                if midiOutLongMsg(h, hdr, Self.headerSize) == 0 {
                    let end = DesktopCore.now() + 2
                    while hdr.pointee.dwFlags & 1 == 0, DesktopCore.now() < end { Sleep(0) }       // MHDR_DONE
                }
                var tries = 0
                while midiOutUnprepareHeader(h, hdr, Self.headerSize) == 65, tries < 200 { Sleep(1); tries += 1 }   // still playing
            }
            data.deallocate()
            hdr.deallocate()
        } else {
            var packed: DWORD = 0
            for (i, b) in bytes.prefix(3).enumerated() { packed |= DWORD(b) << DWORD(8 * i) }
            midiOutShortMsg(h, packed)
        }
    }
}

/// WinMM calls this for every message from the OP-Z; `instance` is the `WinMIDI` that opened it.
private let midiInProc: @convention(c) (OpaquePointer?, UINT, DWORD_PTR, DWORD_PTR, DWORD_PTR) -> Void = { _, msg, instance, p1, _ in
    guard let p = UnsafeRawPointer(bitPattern: UInt(instance)) else { return }
    Unmanaged<WinMIDI>.fromOpaque(p).takeUnretainedValue().received(msg, p1)
}
#endif
