// SPDX-License-Identifier: MIT
// Derived from OP-FREE: after FileSession.pull in core/src/session.ts
// Copyright (c) 2026 Lourens Smit and the op-z-engines contributors (OP-FREE)
// Copyright (c) 2026 Luis Tosado (this version of it)

import OPZModel

/// Downloads files from the OP-Z's file service, the way op-free's `FileSession.pull` does (core/src/session.ts,
/// proven on hardware):
///
///     host $51 advertise (again every 1.5 s)      ->  OP-Z $34 (client id, state CRC)
///     host $52 sync-active 0 (keep-alive, every 1 s)
///     host $35 request (file id, from part n)     ->  OP-Z $53 parts, one after another, to the last
///     a stream that pauses for 0.3 s, or nothing for 2.5 s: ask again from the first missing part (3 tries)
///     host $52 sync-active 0, $55 close
///
/// The `$00` hello the session also needs comes from the StateSync client, which says it every second anyway.
/// No I/O here: feed it what the OP-Z sends and the time, send what it returns.
public final class FileClient {
    public static let serverId = 0x4242
    public static let slotConfiguration: UInt32 = 0
    public static let plugs: UInt32 = 1

    public enum Phase: Equatable, Sendable { case idle, opening, pulling, done, failed(String) }

    public private(set) var phase: Phase = .idle
    /// Complete files, by file id.
    public private(set) var files: [UInt32: [UInt8]] = [:]
    public private(set) var stateCrc: UInt32?
    public var log: (String) -> Void = { _ in }

    static let partSize = 200
    static let advertEvery = 1.5
    static let keepaliveEvery = 1.0
    static let pause = 0.3
    static let roundTime = 2.5
    static let tries = 3
    static let openTime = 12.0

    private var queue: [UInt32]
    private var clientId: Int?
    private var started = 0.0
    private var lastAdvert = -Double.infinity
    private var lastKeepalive = -Double.infinity
    private var fid: UInt32 = 0
    private var want = 0
    private var got: [Int: [UInt8]] = [:]
    private var lastPart: Int?
    private var asked = 0.0
    private var lastRx: Double?
    private var progressed = false
    private var retries = 0

    public init(fileIDs: [UInt32] = [FileClient.plugs, FileClient.slotConfiguration]) {
        queue = fileIDs
    }

    // frames ------------------------------------------------------------------------------------------------------

    private static var sid: [UInt8] { u16le(serverId) }
    static func advertFrame() -> [UInt8] { SysEx.frame(0x51, sid) }
    static func keepaliveFrame() -> [UInt8] { SysEx.frame(0x52, sid + [0]) }
    static func closeFrame() -> [UInt8] { SysEx.frame(0x55, sid) }
    static func requestFrame(fid: UInt32, part: Int) -> [UInt8] { SysEx.frame(0x35, sid + u32le(fid) + u16le(part)) }

    private static func u16le(_ v: Int) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)] }
    private static func u32le(_ v: UInt32) -> [UInt8] { (0..<4).map { UInt8((v >> (8 * $0)) & 0xFF) } }
    private static func u16(_ b: [UInt8], _ at: Int) -> Int { Int(b[at]) | Int(b[at + 1]) << 8 }
    private static func u32(_ b: [UInt8], _ at: Int) -> UInt32 { (0..<4).reduce(0) { $0 | UInt32(b[at + $1]) << (8 * $1) } }

    // driving ----------------------------------------------------------------------------------------------------

    public func start(now: Double) -> [[UInt8]] {
        guard phase == .idle, !queue.isEmpty else { return [] }
        phase = .opening
        started = now
        lastAdvert = now
        return [Self.advertFrame()]
    }

    /// Call a few times a second: re-advertise, keep the session alive, ask again when the stream stalls.
    public func tick(now: Double) -> [[UInt8]] {
        switch phase {
        case .opening:
            if now - started > Self.openTime { return fail("no $34 reply from the file service") }
            if now - lastAdvert > Self.advertEvery {
                lastAdvert = now
                return [Self.advertFrame()]
            }
            return []
        case .pulling:
            var out: [[UInt8]] = []
            if now - lastKeepalive >= Self.keepaliveEvery {
                out.append(Self.keepaliveFrame())
                lastKeepalive = now
            }
            let paused = progressed && lastRx.map { now - $0 > Self.pause } == true
            if paused || now - asked >= Self.roundTime {
                if got.isEmpty { return out + fail("file \(fid) is not served") }
                if !progressed {
                    retries += 1
                    if retries >= Self.tries { return out + fail("file \(fid) incomplete: missing part \(want)") }
                }
                out.append(request(now: now))
            }
            return out
        default:
            return []
        }
    }

    /// One complete SysEx message from the OP-Z; returns what to send back.
    public func receive(_ raw: [UInt8], now: Double) -> [[UInt8]] {
        guard let f = try? SysEx.decode(raw) else { return [] }
        let p = f.payload
        switch (f.id, phase) {
        case (0x34, .opening) where p.count >= 6:
            clientId = Self.u16(p, 0)
            stateCrc = Self.u32(p, 2)
            phase = .pulling
            lastKeepalive = now
            return [Self.keepaliveFrame()] + begin(now: now)
        case (0x53, .pulling) where p.count >= 9:
            guard Self.u16(p, 0) == clientId, Self.u32(p, 2) == fid else { return [] }
            let part = Self.u16(p, 6)
            guard part >= want, let data = Zlib.inflate(Array(p[9...]), maxSize: Self.partSize) else { return [] }
            got[part] = data
            if p[8] != 0 { lastPart = part }
            lastRx = now
            if part == want {
                progressed = true
                retries = 0
                while got[want] != nil { want += 1 }
            }
            guard let last = lastPart, want > last else { return [] }
            let file = (0...last).flatMap { got[$0]! }
            files[fid] = file
            log("pulled file \(fid): \(file.count) bytes in \(last + 1) parts")
            return begin(now: now)
        default:
            return []
        }
    }

    /// The next file, or the end of the session.
    private func begin(now: Double) -> [[UInt8]] {
        guard !queue.isEmpty else {
            phase = .done
            return [Self.keepaliveFrame(), Self.closeFrame()]
        }
        fid = queue.removeFirst()
        want = 0
        got = [:]
        lastPart = nil
        retries = 0
        return [request(now: now)]
    }

    private func request(now: Double) -> [UInt8] {
        asked = now
        lastRx = nil
        progressed = false
        return Self.requestFrame(fid: fid, part: want)
    }

    private func fail(_ why: String) -> [[UInt8]] {
        phase = .failed(why)
        log("file service: \(why)")
        return [Self.closeFrame()]
    }
}
