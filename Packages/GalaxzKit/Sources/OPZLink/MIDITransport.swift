import CoreMIDI
import Foundation

/// Where frames come from and go: a real OP-Z over CoreMIDI, or the demo OP-Z.
@MainActor
public protocol OPZPort: AnyObject {
    /// Complete SysEx messages from the OP-Z (F0 … F7), in order.
    var frames: AsyncStream<[UInt8]> { get }
    func send(_ sysex: [UInt8])
}

/// What the OP-Z's keys and transport send, with CoreMIDI's own timestamp (seconds of host time): the time the message
/// arrived at the driver, not when the app got round to it, so key presses can be timed to the millisecond.
public enum KeyEvent: Sendable, Equatable {
    case noteOn(note: Int, channel: Int, velocity: Int, time: Double)
    case noteOff(note: Int, channel: Int, time: Double)
    /// MIDI start or continue (the OP-Z began playing) and stop.
    case playing(Bool, time: Double = 0)
    case cc(number: Int, value: Int, channel: Int)
    /// A tick of the OP-Z's clock: 24 a beat, 6 a step.
    case clock
}

/// The OP-Z over CoreMIDI (USB cable, or Bluetooth once linked), with SysEx carried as UMP 7-bit data packets.
@MainActor
public final class MIDITransport: OPZPort {
    /// Only an OP-Z that is a program on this Mac, never a real one (the self test: it plays and turns things).
    public static var onlyVirtual = false
    public enum Transport: Sendable { case usb, bluetooth, other }

    public struct Connection: Equatable, Sendable {
        public var name: String
        public var transport: Transport
        let source: MIDIEndpointRef
    }

    public let frames: AsyncStream<[UInt8]>
    /// Notes from the keys, and start/stop, timestamped.
    public let keys: AsyncStream<KeyEvent>
    /// The OP-Z in use, nil when none is connected.
    public private(set) var connection: Connection?
    public var connectedName: String? { connection?.name }
    /// Called on the main actor when MIDI devices come or go.
    public var onSetupChanged: (() -> Void)?

    private let reader: UMPReader
    private var client = MIDIClientRef()
    private var inPort = MIDIPortRef()
    private var outPort = MIDIPortRef()
    private var source = MIDIEndpointRef()
    private var destination = MIDIEndpointRef()

    public init() {
        let (stream, continuation) = AsyncStream.makeStream(of: [UInt8].self)
        frames = stream
        let (keyStream, keyContinuation) = AsyncStream.makeStream(of: KeyEvent.self, bufferingPolicy: .bufferingNewest(512))
        keys = keyStream
        reader = UMPReader(continuation, keys: keyContinuation)
        MIDIClientCreateWithBlock("Galax-z" as CFString, &client, Self.notifyBlock { [weak self] in self?.onSetupChanged?() })
        MIDIInputPortCreateWithProtocol(client, "Galax-z In" as CFString, ._1_0, &inPort, Self.readBlock(reader))
        MIDIOutputPortCreate(client, "Galax-z Out" as CFString, &outPort)
    }

    // CoreMIDI calls these two on its own threads. They are made outside the main actor on purpose: a closure written
    // inside this class's init would be main-actor isolated, and Swift 6's isolation check stops the app the first
    // time the OP-Z sends anything (the 0.1 crash on plugging in).
    nonisolated static func readBlock(_ reader: UMPReader) -> MIDIReceiveBlock {
        { list, _ in reader.read(list) }
    }

    nonisolated static func notifyBlock(_ changed: @escaping @MainActor @Sendable () -> Void) -> MIDINotifyBlock {
        { note in
            guard note.pointee.messageID == .msgSetupChanged else { return }
            Task { @MainActor in changed() }
        }
    }

    /// Connect to the OP-Z (a cable first, then Bluetooth); false when there is none.
    @discardableResult
    public func connectToOPZ() -> Bool {
        let src = Self.find(count: MIDIGetNumberOfSources(), MIDIGetSource)
        let dst = Self.find(count: MIDIGetNumberOfDestinations(), MIDIGetDestination)
        guard let src, let dst else {
            disconnect()
            return false
        }
        if src.ref != source {
            if source != 0 { MIDIPortDisconnectSource(inPort, source) }
            MIDIPortConnectSource(inPort, src.ref, nil)
            source = src.ref
        }
        destination = dst.ref
        connection = Connection(name: src.name, transport: src.transport, source: src.ref)
        return true
    }

    public func disconnect() {
        if source != 0 { MIDIPortDisconnectSource(inPort, source) }
        source = 0
        destination = 0
        connection = nil
    }

    public func send(_ sysex: [UInt8]) {
        guard destination != 0, sysex.first == 0xF0, sysex.last == 0xF7 else { return }
        let words = Self.umpWords(sysex)
        let size = 4096
        let raw = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 8)
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: MIDIEventList.self, capacity: 1)
        var k = 0
        while k < words.count { // at most 128 two-word messages per list, never full
            var packet = MIDIEventListInit(list, ._1_0)
            let end = min(words.count, k + 256)
            var i = k
            while i < end {
                var pair = (words[i], words[i + 1])
                packet = withUnsafePointer(to: &pair) {
                    $0.withMemoryRebound(to: UInt32.self, capacity: 2) { MIDIEventListAdd(list, size, packet, 0, 2, $0) }
                }
                i += 2
            }
            MIDISendEventList(outPort, destination, list)
            k = end
        }
    }

    /// A short message (a note, a CC, a bend, start or stop), at a time of the host's clock in seconds; what is past goes at once.
    public func send(short b: [UInt8], at time: Double = 0) {
        guard destination != 0, var word = Self.umpWord(b) else { return }
        var list = MIDIEventList()
        let packet = MIDIEventListInit(&list, ._1_0), stamp = time > 0 ? MIDITimeStamp(max(0, time / UMPReader.tick)) : 0
        _ = MIDIEventListAdd(&list, MemoryLayout<MIDIEventList>.size, packet, stamp <= mach_absolute_time() ? 0 : stamp, 1, &word)
        MIDISendEventList(outPort, destination, &list)
    }
    public nonisolated static func umpWord(_ b: [UInt8]) -> UInt32? {
        guard let s = b.first, s & 0x80 != 0, s != 0xF0, s != 0xF7, b.count <= 3, b.dropFirst().allSatisfy({ $0 < 128 }) else { return nil }
        return (s >= 0xF0 ? 0x1000_0000 : 0x2000_0000) | UInt32(s) << 16 | UInt32(b.count > 1 ? b[1] : 0) << 8 | UInt32(b.count > 2 ? b[2] : 0)
    }

    /// A SysEx message as UMP type 3 (7-bit data) words: six bytes per message, F0 and F7 left out.
    public nonisolated static func umpWords(_ sysex: [UInt8]) -> [UInt32] {
        let body = Array(sysex.dropFirst().dropLast())
        let chunks = stride(from: 0, to: max(body.count, 1), by: 6).map { Array(body[$0..<min($0 + 6, body.count)]) }
        var words: [UInt32] = []
        for (i, chunk) in chunks.enumerated() {
            let status: UInt32 = chunks.count == 1 ? 0 : i == 0 ? 1 : i == chunks.count - 1 ? 3 : 2
            let b = chunk + [UInt8](repeating: 0, count: 6 - chunk.count)
            words.append(0x3 << 28 | status << 20 | UInt32(chunk.count) << 16 | UInt32(b[0]) << 8 | UInt32(b[1]))
            words.append(UInt32(b[2]) << 24 | UInt32(b[3]) << 16 | UInt32(b[4]) << 8 | UInt32(b[5]))
        }
        return words
    }

    /// Every MIDI source's name, for the log when no OP-Z is among them.
    public static func sourceNames() -> [String] {
        (0..<MIDIGetNumberOfSources()).map { string(MIDIGetSource($0), kMIDIPropertyDisplayName) }
    }

    private typealias Found = (ref: MIDIEndpointRef, name: String, transport: Transport)

    /// The endpoint whose name says OP-Z, a cable before Bluetooth.
    private static func find(count: Int, _ get: (Int) -> MIDIEndpointRef) -> Found? {
        var found: [Found] = []
        for i in 0..<count {
            let ref = get(i)
            let name = string(ref, kMIDIPropertyDisplayName)
            if name.lowercased().contains("op-z"), !onlyVirtual || isVirtual(ref) { found.append((ref, name, transport(of: ref))) }
        }
        return found.first { $0.transport == .usb } ?? found.first
    }

    /// Made by a program: it belongs to no device.
    static func isVirtual(_ endpoint: MIDIEndpointRef) -> Bool {
        var entity = MIDIEntityRef()
        return MIDIEndpointGetEntity(endpoint, &entity) != noErr || entity == 0
    }

    /// From the driver that owns the endpoint's device: Apple's USB or Bluetooth MIDI driver.
    private static func transport(of endpoint: MIDIEndpointRef) -> Transport {
        var entity = MIDIEntityRef(), device = MIDIDeviceRef()
        guard MIDIEndpointGetEntity(endpoint, &entity) == noErr, MIDIEntityGetDevice(entity, &device) == noErr else {
            return .other
        }
        let owner = string(device, kMIDIPropertyDriverOwner).lowercased()
        return owner.contains("bluetooth") ? .bluetooth : owner.contains("usb") ? .usb : .other
    }

    private static func string(_ object: MIDIObjectRef, _ property: CFString) -> String {
        var cf: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(object, property, &cf)
        return cf?.takeRetainedValue() as String? ?? ""
    }
}

/// Reads what CoreMIDI delivers on its own thread: reassembles SysEx from UMP 7-bit data packets and hands complete
/// messages on in order; passes notes and start/stop on with the packet's timestamp.
public final class UMPReader: @unchecked Sendable {
    private let out: AsyncStream<[UInt8]>.Continuation
    private let keys: AsyncStream<KeyEvent>.Continuation?
    private var buffer: [UInt8]? // only touched on CoreMIDI's receive thread

    /// Seconds per host-time tick.
    static let tick: Double = {
        var base = mach_timebase_info_data_t()
        mach_timebase_info(&base)
        return Double(base.numer) / Double(base.denom) / 1e9
    }()

    public init(_ out: AsyncStream<[UInt8]>.Continuation, keys: AsyncStream<KeyEvent>.Continuation? = nil) {
        self.out = out
        self.keys = keys
    }

    public func read(_ list: UnsafePointer<MIDIEventList>) {
        for packetPointer in list.unsafeSequence() {
            let packet = packetPointer.pointee
            let count = Int(packet.wordCount)
            // a packet without a time stamp arrived now
            let time = Double(packet.timeStamp == 0 ? mach_absolute_time() : packet.timeStamp) * Self.tick
            withUnsafeBytes(of: packet.words) { raw in
                let words = raw.bindMemory(to: UInt32.self)
                var i = 0
                while i < count && i < words.count {
                    let word = words[i]
                    let type = Int(word >> 28)
                    if type == 0x3, i + 1 < words.count { feed(word, words[i + 1]) }
                    if type == 0x1 || type == 0x2 { message(word, time: time) }
                    i += [1, 1, 1, 2, 2, 4, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4][type]
                }
            }
        }
    }

    /// A one-word UMP: a MIDI 1.0 channel message (type 2) or a system real-time message (type 1).
    func message(_ word: UInt32, time: Double) {
        guard let keys else { return }
        let status = Int((word >> 16) & 0xFF)
        let data1 = Int((word >> 8) & 0x7F), data2 = Int(word & 0x7F)
        switch status {
        case 0xFA, 0xFB: keys.yield(.playing(true, time: time))
        case 0xFC: keys.yield(.playing(false, time: time))
        case 0xF8: keys.yield(.clock)
        case 0x90...0x9F where data2 > 0: keys.yield(.noteOn(note: data1, channel: status & 0x0F, velocity: data2, time: time))
        case 0xB0...0xBF: keys.yield(.cc(number: data1, value: data2, channel: status & 0x0F))
        case 0x80...0x9F: keys.yield(.noteOff(note: data1, channel: status & 0x0F, time: time))
        default: break
        }
    }

    func feed(_ w0: UInt32, _ w1: UInt32) {
        let status = (w0 >> 20) & 0xF
        let n = min(Int((w0 >> 16) & 0xF), 6)
        let all: [UInt8] = [UInt8((w0 >> 8) & 0xFF), UInt8(w0 & 0xFF), UInt8(w1 >> 24),
                            UInt8((w1 >> 16) & 0xFF), UInt8((w1 >> 8) & 0xFF), UInt8(w1 & 0xFF)]
        let bytes = all.prefix(n)
        switch status {
        case 0: out.yield([0xF0] + bytes + [0xF7])
        case 1: buffer = Array(bytes)
        case 2: buffer?.append(contentsOf: bytes)
        case 3:
            if let start = buffer { out.yield([0xF0] + start + bytes + [0xF7]) }
            buffer = nil
        default: break
        }
    }
}
