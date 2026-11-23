// SPDX-License-Identifier: MIT
// Derived from OP-FREE: after core/src/session.ts and research/patterns.md
// Copyright (c) 2026 Lourens Smit and the op-z-engines contributors (OP-FREE)
// Copyright (c) 2026 Luis Tosado (this version of it)

import OPZModel

/// A StateSync replica, the way TE's app is one (op-free `research/patterns.md` §5, `core/src/session.ts`):
///
///     host $00 hello (every second)            ->  OP-Z $01 (to every hello)
///     first hello of a session                 ->  OP-Z $07 play state, $0C global block, $09 bank part 0
///     host $0B ack of part n                   ->  OP-Z part n + 1 … $0A the last part
///     host $08                                 ->  OP-Z the bank again from part 0
///
/// The OP-Z sends the next part only after the ack of the one before and never times out, so a lost part stalls the
/// transfer until `$08`. The session ends ~5 s after the last hello.
///
/// No I/O here: feed it what the OP-Z sends and the time, send what it returns.
public final class StateSyncClient {
    public static let clientId: UInt16 = 0x4242 // op-free's SERVER_ID, the id its tools use

    enum Message {
        static let hello: UInt8 = 0x00, sessionAck: UInt8 = 0x01, delta: UInt8 = 0x02, playState: UInt8 = 0x07
        static let bankRequest: UInt8 = 0x08, bankPart: UInt8 = 0x09, bankFinal: UInt8 = 0x0A, bankAck: UInt8 = 0x0B
        static let global: UInt8 = 0x0C, sound: UInt8 = 0x0E, midiQuery: UInt8 = 0x0F, midi: UInt8 = 0x10
    }
    static let chunk = 178
    static let helloEvery = 1.0
    static let partWait = 1.0
    static let burstWait = 1.5
    static let ackLost = 3.0
    static let requestsPerBank = 3
    /// After an edit that cannot be made from its `$02` (a pattern copied, a record lost), fetch the bank again once the
    /// edits pause this long, and never later than `editMax`.
    static let editQuiet = 0.15
    static let editMax = 0.6
    /// A bank asked for that does not come is asked for again.
    static let askAgain = 2.0
    /// Edits kept while a bank is on its way: made again on it when it is in (it may have been packed before them).
    static let editsKept = 512

    /// The latest complete bank and its address; `bankRevision` counts the banks received.
    public private(set) var bank: Bank?
    public private(set) var bankAddress: PatternAddress?
    public private(set) var bankRevision = 0
    /// Counts the edits and sounds made in the bank since.
    public private(set) var editRevision = 0
    /// What the OP-Z's panel is doing; `panelRevision` counts its messages.
    public private(set) var panel = PanelState()
    public private(set) var panelRevision = 0
    /// Its MIDI settings, asked for once a connection, and again by `askMIDI` (they can be changed on the OP-Z and it does not say so).
    public private(set) var midi: MIDISettings?
    /// The red page, while the OP-Z tells of it (v11).
    public private(set) var red: RedPage?
    /// The tumbler and EUCLID, if the OP-Z's OS tells of them (Galax-z v10); its messages count in `panelRevision`.
    public private(set) var machines: Machines?
    /// Banks fetched again because an edit could not be followed (a lost record, a copied pattern).
    public private(set) var refetches = 0
    public private(set) var global: GlobalBlock?
    /// `$07` byte 17: the active pattern now.
    public private(set) var playAddress: PatternAddress?
    /// Sounds the OP-Z sent with `$0E`, by track.
    public private(set) var sounds: [Int: [UInt8]] = [:]
    /// Parts of the transfer in progress (nil when none).
    public private(set) var partsIncoming: Int?
    /// Count of every message received, by id; ids we do not handle yet are what to decode next (`$02` deltas).
    public private(set) var seen: [UInt8: Int] = [:]
    public var log: (String) -> Void = { _ in }
    /// Every `$02` payload, as it arrives: kept by the app next to the bank changes that follow, to decode them.
    public var onDelta: (([UInt8]) -> Void)?

    private var rx: (address: Int, transfer: Int, chunks: [[UInt8]])?
    private var lastHello = -Double.infinity
    private var lastAck = -Double.infinity
    private var firstAck: Double?
    private var lastPart = -Double.infinity
    private var requests = 0
    /// Edits that have to be fetched: when the first and the last arrived.
    private var edited: (first: Double, last: Double)?
    private var lastEdit: UInt16?
    /// What was changed since a bank was asked for (or began to come): made again on it, as it may have been packed before them.
    private enum Change { case edit(PatternChange), sound(PatternAddress, Int, [UInt8]) }
    private var pending: [Change] = []
    private var collecting = false
    /// When a bank was asked for because of edits, until one is in.
    private var asked: Double?
    /// A bank came since the session (re)started: the one from before may have missed edits.
    private var current = false

    public init() {}

    /// The OP-Z answered a hello within the last few seconds.
    public func isLive(at now: Double) -> Bool { now - lastAck < Self.ackLost }

    // frames ------------------------------------------------------------------------------------------------------

    public static func helloFrame(clientId: UInt16 = clientId, protocolVersion: UInt8 = 6) -> [UInt8] {
        SysEx.frame(Message.hello, [UInt8(clientId >> 8), UInt8(clientId & 0xFF), protocolVersion])
    }

    /// `$0B`: the client has part `index` of `transfer` (TE's receiver sends `09 00 00 00`, transfer, index).
    public static func ackFrame(transfer: Int, index: Int) -> [UInt8] {
        SysEx.frame(Message.bankAck, [9, 0, 0, 0] + u16le(transfer) + u16le(index))
    }

    /// `$08`: the bank again from part 0 (the OP-Z ignores the payload; TE's receiver sends FF FF FF FF).
    public static func bankRequestFrame() -> [UInt8] { SysEx.frame(Message.bankRequest, [0xFF, 0xFF, 0xFF, 0xFF]) }

    private static func u16le(_ v: Int) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)] }
    private static func u16le(_ b: [UInt8], _ at: Int) -> Int { Int(b[at]) | Int(b[at + 1]) << 8 }

    // driving ----------------------------------------------------------------------------------------------------

    /// Call often (a few times a second): a hello when one is due, and a fresh bank request when a transfer stalled
    /// or a live session sent no bank (another client's session was still open).
    public func tick(now: Double, forceHello: Bool = false) -> [[UInt8]] {
        var out: [[UInt8]] = []
        if forceHello || now - lastHello >= Self.helloEvery {
            out.append(Self.helloFrame())
            lastHello = now
        }
        // Edits that could not be made here: a fresh bank once they pause, never cutting a transfer short.
        if let e = edited, rx == nil, now - (asked ?? -.infinity) > Self.askAgain, now - e.last >= Self.editQuiet || now - e.first >= Self.editMax {
            asked = now
            requests = 0
            refetches += 1
            out += requestBank("edited on the OP-Z", now: now)
        }
        if rx != nil, now - lastPart > Self.partWait {
            out += requestBank("transfer stalled", now: now)
        } else if !current, rx == nil, let first = firstAck, now - first > Self.burstWait, now - lastPart > Self.partWait {
            out += requestBank("no bank with the session", now: now)
        }
        return out
    }

    /// One complete SysEx message from the OP-Z; returns what to send back.
    public func receive(_ raw: [UInt8], now: Double) -> [[UInt8]] {
        guard let f = try? SysEx.decode(raw) else { return [] }
        seen[f.id, default: 0] += 1
        switch f.id {
        case Message.sessionAck:
            lastAck = now
            if firstAck == nil { firstAck = now }
        case Message.bankPart, Message.bankFinal:
            return bankPart(final: f.id == Message.bankFinal, f.payload, now: now)
        case Message.delta:
            onDelta?(f.payload)
            edits(f.payload, now: now)
        case Message.midi:
            if let m = Zlib.inflate(f.payload, size: MIDISettings.size).flatMap(MIDISettings.init), m != midi { midi = m; panelRevision += 1 }
        case Message.global:
            if let g = Zlib.inflate(f.payload, size: OPZ.globalSize).flatMap(GlobalBlock.init) { global = g }
        case Message.playState where f.payload.count == 20:
            let address = PatternAddress(raw: Int(f.payload[17]))
            playAddress = address
            if let b = bankAddress, b.project != address.project {
                if rx == nil { return requestBank("project changed", now: now) }
                refetch(now)            // the one on its way may be the old project's
            }
        case Message.sound where f.payload.count == 19 && f.payload[0] <= 15:
            sounds[Int(f.payload[0])] = Array(f.payload[1...])
            if let a = playAddress ?? bankAddress, a.project == bankAddress?.project {
                bank?.setSound(a.pattern, Int(f.payload[0]), Array(f.payload[1...]))
                keep(.sound(a, Int(f.payload[0]), Array(f.payload[1...])), now)
                editRevision += 1
            }
        default:
            if panel.receive(f.id, f.payload) { panelRevision += 1; break }
            if f.id == 0x72 {
                if let r = RedPage(f.payload) { red = r; panelRevision += 1 }
                break
            }
            var m = machines ?? Machines()
            if m.receive(f.id, f.payload), machines != nil || f.id == 0x70 { machines = m; panelRevision += 1 }
        }
        return []
    }

    /// A `$02`: make its edits in the bank, at once; what cannot be made that way is fetched.
    private func edits(_ payload: [UInt8], now: Double) {
        guard let changes = PatternChange.parse(payload) else { return refetch(now) }
        for c in changes {
            if let last = lastEdit, c.timestamp != last &+ 1 { refetch(now) }      // one was lost
            lastEdit = c.timestamp
            keep(.edit(c), now)
            guard bank != nil else { continue }
            guard c.address.project == bankAddress?.project else { refetch(now); continue }
            if bank!.apply(c) { editRevision += 1 } else { refetch(now) }
        }
    }

    private func keep(_ c: Change, _ now: Double) {
        guard collecting else { return }
        pending.append(c)
        if pending.count > Self.editsKept { pending.removeAll(); refetch(now) }
    }

    private func refetch(_ now: Double) { edited = (edited?.first ?? now, now) }

    /// Ask for the bank again (also what to do after the session was lost).
    public func requestBank(_ why: String, now: Double) -> [[UInt8]] {
        rx = nil
        partsIncoming = nil
        lastPart = now
        guard requests < Self.requestsPerBank else { return [] }
        requests += 1
        if !collecting { collecting = true; pending = [] }
        log("bank \(why): asking for it again")
        return [Self.bankRequestFrame()]
    }

    /// Forget the session (the cable came out): the next hello starts a new one.
    public func reset() {
        rx = nil
        partsIncoming = nil
        edited = nil
        lastEdit = nil
        pending = []
        collecting = false
        asked = nil
        current = false
        panel = PanelState()
        machines = nil
        midi = nil
        red = nil
        panelRevision += 1
        firstAck = nil
        lastAck = -.infinity
        lastHello = -.infinity
        requests = 0
    }

    /// One `$09`/`$0A`, checked as TE's receiver does, acked, and on the last part inflated.
    private func bankPart(final: Bool, _ p: [UInt8], now: Double) -> [[UInt8]] {
        guard p.count >= 7, p.count - 6 <= Self.chunk, final || p.count - 6 == Self.chunk else {
            return requestBank("part malformed", now: now)
        }
        let address = Self.u16le(p, 0), transfer = Self.u16le(p, 2), index = Self.u16le(p, 4)
        if index == 0 {
            rx = (address, transfer, [])
            if !collecting { collecting = true; pending = [] }
        } else if rx == nil || rx!.transfer != transfer || rx!.chunks.count != index {
            return requestBank("part \(index) out of order", now: now)
        }
        rx!.chunks.append(Array(p[6...]))
        lastPart = now
        partsIncoming = rx!.chunks.count
        if !final { return [Self.ackFrame(transfer: transfer, index: index)] }

        let z = rx!.chunks.flatMap { $0 }
        rx = nil
        partsIncoming = nil
        guard let bytes = Zlib.inflate(z, size: OPZ.bankSize), let b = Bank(bytes) else {
            return requestBank("did not inflate to \(OPZ.bankSize) bytes", now: now)
        }
        bank = b
        bankAddress = PatternAddress(raw: address)
        // edits from after it was asked for may not be in it, nor fetched yet
        if let a = asked, let e = edited, e.last <= a { edited = nil }
        asked = nil
        current = true
        for c in pending {
            switch c {
            case .edit(let c) where c.address.project == bankAddress?.project: if !bank!.apply(c), (edited?.last ?? -.infinity) < now { refetch(now) }
            case .sound(let a, let t, let v) where a.project == bankAddress?.project: bank!.setSound(a.pattern, t, v)
            default: break
            }
        }
        pending = []
        collecting = false
        if let p = playAddress, p.project != bankAddress?.project { refetch(now) }
        bankRevision += 1
        requests = 0
        log("bank: project \((address >> 4) + 1), pattern \((address & 0x0F) + 1) (\(index + 1) parts, \(z.count) bytes)")
        return []
    }
}
