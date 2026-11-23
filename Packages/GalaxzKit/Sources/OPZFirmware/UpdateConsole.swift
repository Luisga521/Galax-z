import Foundation

/// A byte pipe to the OP-Z's update-mode console (the serial port on a Mac, a fake one in tests).
public protocol ConsoleTransport: AnyObject {
    func write(_ bytes: [UInt8]) throws
    /// What arrived, waiting up to `timeout` for the first byte; empty if nothing did.
    func read(timeout: TimeInterval) throws -> [UInt8]
    func discardInput()
}

public enum ConsoleError: Error, CustomStringConvertible {
    case refused(String)
    /// An upload is open on the OP-Z and did not finish: nothing more may be sent until it is switched off.
    case stalled(String)

    public var description: String {
        switch self { case .refused(let s): "REFUSED: \(s)"; case .stalled(let s): "STALLED: \(s)" }
    }
}

/// The strict update-mode writer, port of Firmware/tools/flash.py (frames decoded in notes/update-write.md).
///
/// Fixed frames only (ping, read os.ldr, read os.crc32), plus `0x11` writes of os.ldr / os.crc32 whose data is a file
/// of a flashable image (SHA-256). One 2,048-byte piece per answer; a missing answer stops everything.
public final class UpdateConsole {
    public static let names = ["os.ldr", "os.crc32"]
    /// Formats or writes SPI flash, formats the NAND, upgrades, deletes, renames, runs code, unknown, power/reset.
    public static let never: Set<UInt8> = [0x06, 0x10, 0x14, 0x15, 0x23, 0x29, 0x31, 0x34, 0x37, 0x3B]
    static let start: UInt8 = 0xC0, escapeByte: UInt8 = 0x7D, piece = 2048
    static let typePing: UInt8 = 0x00, typeWrite: UInt8 = 0x11, typeRead: UInt8 = 0x19, typeLog: UInt8 = 0x04
    static let replyPong: UInt8 = 0x01, replyPiece: UInt8 = 0x12, replyWritten: UInt8 = 0x13, replyRead: UInt8 = 0x20

    public static let ping = frame(typePing)
    public static let read = Dictionary(uniqueKeysWithValues: names.map { ($0, frame(typeRead, Array($0.utf8) + [0])) })
    static let fixed: Set<[UInt8]> = Set([ping] + read.values)

    let port: ConsoleTransport
    let allowed: Set<String>      // "name sha256"
    let log: @Sendable (String) -> Void
    var reader = FrameReader()
    public private(set) var stalled = false

    public init(_ port: ConsoleTransport, images: [FirmwareImage], log: @escaping @Sendable (String) -> Void) {
        self.port = port
        self.log = log
        allowed = Set(images.flatMap { im in im.files.map { "\($0.name) \(Hash.sha256($0.data))" } })
    }

    // MARK: frames

    static func escape(_ d: [UInt8]) -> [UInt8] {
        d.flatMap { $0 == start || $0 == escapeByte ? [escapeByte, $0 ^ 0x20] : [$0] }
    }

    static func frame(_ type: UInt8, _ payload: [UInt8] = []) -> [UInt8] {
        precondition(!never.contains(type) && [typePing, typeRead].contains(type))
        return [start] + escape([0x01, type] + LDR.le(UInt32(payload.count)).reversed() + payload)
    }

    /// C0 and the escaped header, size and name up to its zero byte: on that byte the OP-Z opens the file ("w+b").
    static func writeHeader(_ name: String, size: Int) throws -> [UInt8] {
        guard names.contains(name) else { throw ConsoleError.refused("\(name) is not one of \(names)") }
        let raw = Array(name.utf8)
        let length = UInt32(4 + raw.count + 1 + size)
        return [start] + escape([0x01, typeWrite] + LDR.le(length).reversed() + LDR.le(UInt32(size)).reversed() + raw + [0])
    }

    /// Read a whole write frame back the way the OP-Z's parser does; refuse anything else.
    static func decodeWrite(_ wire: [UInt8]) throws -> (String, [UInt8]) {
        guard wire.first == start else { throw ConsoleError.refused("a frame must start with C0") }
        var body: [UInt8] = [], esc = false
        for b in wire.dropFirst() {
            if esc { body.append(b ^ 0x20); esc = false }
            else if b == escapeByte { esc = true }
            else if b == start { throw ConsoleError.refused("a raw C0 inside a frame") }
            else { body.append(b) }
        }
        guard body.count >= 11, body[0] == 0x01, body[1] == typeWrite, let end = body[10...].firstIndex(of: 0) else {
            throw ConsoleError.refused("not a write frame")
        }
        let length = Int(be(body, 2)), size = Int(be(body, 6))
        let name = String(decoding: body[10..<end], as: UTF8.self), data = Array(body[(end + 1)...])
        guard names.contains(name), data.count == size, length == 4 + name.utf8.count + 1 + size else {
            throw ConsoleError.refused("inconsistent write frame")
        }
        return (name, data)
    }

    static func be(_ d: [UInt8], _ i: Int) -> UInt32 {
        UInt32(d[i]) << 24 | UInt32(d[i + 1]) << 16 | UInt32(d[i + 2]) << 8 | UInt32(d[i + 3])
    }

    // MARK: talking

    func put(_ wire: [UInt8]) throws {
        if stalled { throw ConsoleError.stalled("an upload did not finish: switch the OP-Z off and on first") }
        try port.write(wire)
    }

    func send(_ wire: [UInt8]) throws {
        guard Self.fixed.contains(wire) else { throw ConsoleError.refused("not a fixed frame") }
        try put(wire)
    }

    /// The next frame of type `want`. With `idle`, once bytes flow the limit becomes `idle` s of silence.
    func wait(_ want: UInt8, timeout: TimeInterval, idle: TimeInterval? = nil) throws -> [UInt8]? {
        let begin = Date()
        var last = begin
        while true {
            let chunk = try port.read(timeout: 0.2)
            let now = Date()
            if !chunk.isEmpty { last = now; reader.feed(chunk) }
            for (type, payload) in reader.take() {
                if type == Self.typeLog { log("  << log \(String(decoding: payload.prefix { $0 != 0 }, as: UTF8.self))") }
                else if type == want { return payload }
                else { log("  << ignored frame type \(String(format: "0x%02x", type))") }
            }
            if let idle, last > begin {
                if now.timeIntervalSince(last) > idle { return nil }
            } else if now.timeIntervalSince(begin) > timeout { return nil }
        }
    }

    func drain() { port.discardInput(); reader = FrameReader() }

    func ping(timeout: TimeInterval = 2) throws -> Bool {
        try send(Self.ping)
        return try wait(Self.replyPong, timeout: timeout) == []
    }

    /// Opening the port eats the first frame, so ping twice and require the second pong.
    public func start() throws {
        _ = try ping(timeout: 1)
        drain()
        guard try ping() else {
            throw ConsoleError.refused("no answer: is the OP-Z connected and in update mode (hold SCREEN while switching on)?")
        }
        log("  pong: update mode")
    }

    public func readFile(_ name: String) throws -> [UInt8]? {
        guard let frame = Self.read[name] else { throw ConsoleError.refused("\(name)") }
        try send(frame)
        return try wait(Self.replyRead, timeout: 8, idle: 3)
    }

    public func writeFile(_ name: String, _ data: [UInt8], progress: (@Sendable (Int, Int) -> Void)? = nil) throws {
        guard allowed.contains("\(name) \(Hash.sha256(data))") else {
            throw ConsoleError.refused("\(name) is not a file of any flashable image")
        }
        let head = try Self.writeHeader(name, size: data.count)
        let pieces = data.isEmpty ? [[]] : stride(from: 0, to: data.count, by: Self.piece).map {
            Self.escape(Array(data[$0..<min($0 + Self.piece, data.count)]))
        }
        let decoded = try Self.decodeWrite(head + pieces.joined())
        guard decoded.0 == name, decoded.1 == data else { throw ConsoleError.refused("the write frame does not decode to what was asked") }
        log("  >> write \(name): \(data.count) bytes in \(pieces.count) pieces")
        drain()
        // From the first byte on the upload is open: whatever goes wrong (no answer, the port failing), nothing more may
        // be sent until the OP-Z has been switched off.
        var sent = 0
        do {
            try put(head)
            Thread.sleep(forTimeInterval: 0.3)   // the zero byte mounts and opens; nothing answers it
            for (i, wire) in pieces.enumerated() {
                let last = i == pieces.count - 1
                try put(wire)
                sent = i + 1
                guard try wait(last ? Self.replyWritten : Self.replyPiece, timeout: last ? 30 : 10) != nil else {
                    throw ConsoleError.refused("no answer")
                }
                progress?(i + 1, pieces.count)
            }
        } catch {
            stalled = true
            throw ConsoleError.stalled("\(name): \(error) after piece \(sent) of \(pieces.count). The upload is still open: "
                                       + "switch the OP-Z off, back on holding SCREEN, and flash again")
        }
        log("  << \(name) written")
    }
}

/// The OP-Z's byte stream → (type, payload). The device escapes its header as well as the payload.
struct FrameReader {
    private var body: [UInt8]? = nil, esc = false, frames: [(UInt8, [UInt8])] = []

    mutating func feed(_ data: [UInt8]) {
        for var b in data {
            if b == 0xC0 { body = []; esc = false; continue }
            guard body != nil else { continue }
            if esc { b ^= 0x20; esc = false } else if b == 0x7D { esc = true; continue }
            body!.append(b)
            if body!.count >= 6, body!.count == 6 + Int(UpdateConsole.be(body!, 2)) {
                frames.append((body![1], Array(body![6...])))
                body = nil
            }
        }
    }

    mutating func take() -> [(UInt8, [UInt8])] { defer { frames = [] }; return frames }
}
