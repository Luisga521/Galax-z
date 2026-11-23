import OPZLink

/// Android hands MIDI 1.0 over as bytes, cut wherever its driver likes: this puts SysEx back together and reads the
/// notes, CCs, clock and start/stop out of the rest, as `UMPReader` does on Apple's side.
struct MIDIBytes {
    private var sysex: [UInt8]?
    private var status: UInt8 = 0
    private var data: [UInt8] = []

    mutating func feed(_ bytes: UnsafeBufferPointer<UInt8>, time: Double, frame: ([UInt8]) -> Void, key: (KeyEvent) -> Void) {
        for b in bytes { feed(b, time: time, frame: frame, key: key) }
    }

    mutating func feed(_ b: UInt8, time: Double, frame: ([UInt8]) -> Void, key: (KeyEvent) -> Void) {
        switch b {
        case 0xF8...: // real time: may come in the middle of anything, and changes nothing
            switch b {
            case 0xF8: key(.clock)
            case 0xFA, 0xFB: key(.playing(true, time: time))
            case 0xFC: key(.playing(false, time: time))
            default: break
            }
        case 0xF0:
            sysex = [0xF0]
            status = 0
        case 0xF7:
            if var s = sysex { s.append(0xF7); frame(s) }
            sysex = nil
        case 0x80...0xF6:
            sysex = nil
            status = b
            data.removeAll(keepingCapacity: true)
            if Self.length(b) == 0 { status = 0 }
        default: // data
            if sysex != nil { sysex!.append(b); return }
            guard status != 0 else { return }
            data.append(b)
            guard data.count == Self.length(status) else { return }
            message(status, data, time: time, key: key)
            data.removeAll(keepingCapacity: true)
            if status >= 0xF0 { status = 0 } // running status is for channel messages only
        }
    }

    private static func length(_ status: UInt8) -> Int {
        switch status {
        case 0xC0...0xDF, 0xF1, 0xF3: 1
        case 0x80...0xEF, 0xF2: 2
        default: 0
        }
    }

    private func message(_ status: UInt8, _ d: [UInt8], time: Double, key: (KeyEvent) -> Void) {
        let channel = Int(status & 0x0F)
        switch status {
        case 0x90...0x9F where d[1] > 0: key(.noteOn(note: Int(d[0]), channel: channel, velocity: Int(d[1]), time: time))
        case 0x80...0x9F: key(.noteOff(note: Int(d[0]), channel: channel, time: time))
        case 0xB0...0xBF: key(.cc(number: Int(d[0]), value: Int(d[1]), channel: channel))
        default: break
        }
    }
}
