import CoreMIDI
import Foundation
import OPZLink
import OPZModel

/// A virtual OP-Z for this Mac: a MIDI device named "OP-Z" that answers like one (StateSync, its files, the panel while it plays,
/// live edits, notes, the load meter's report), so that the app's whole path over CoreMIDI can be tried with no unit.
///
///     swift run galaxz-fakeopz [seconds] [-clock]        -clock: it sends MIDI clock too
///
/// Two seconds after an app says hello it plays; then, on a script: track 6 is selected (4 s), a step is edited (5 s), a knob is
/// turned (6 s), a page is turned (7 s), the meter's figures are sent (8 s), an edit is lost so the app has to read again (9 s),
/// project data of another pattern is replaced (10 s), and it stops (14 s). From 2 s on it tells of a tumbler and an EUCLID on track 6, with their pages on at 9 and 11 s.
setbuf(stdout, nil)
let seconds = CommandLine.arguments.dropFirst().first.flatMap(Double.init) ?? 60
var client = MIDIClientRef(), source = MIDIEndpointRef(), destination = MIDIEndpointRef()
MIDIClientCreateWithBlock("galaxz-fakeopz" as CFString, &client, nil)
MIDISourceCreateWithProtocol(client, "OP-Z" as CFString, ._1_0, &source)

let (frames, into) = AsyncStream.makeStream(of: [UInt8].self)
let reader = UMPReader(into)
MIDIDestinationCreateWithProtocol(client, "OP-Z" as CFString, ._1_0, &destination, receiver(reader))

func receiver(_ reader: UMPReader) -> MIDIReceiveBlock {
    { list, _ in
        reader.read(list)
        for p in list.unsafeSequence() {                        // what is played on it
            let n = Int(p.pointee.wordCount)
            withUnsafeBytes(of: p.pointee.words) { raw in
                var i = 0
                while i < n {
                    let w = raw.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self), type = w >> 28
                    if type == 2 || type == 1 { print(String(format: "midi %02x %3d %3d", Int(w >> 16 & 255), Int(w >> 8 & 127), Int(w & 127))) }
                    i += type == 3 || type == 4 ? 2 : 1
                }
            }
        }
    }
}

@MainActor func send(words: [UInt32]) {
    let raw = UnsafeMutableRawPointer.allocate(byteCount: 4096, alignment: 8)
    defer { raw.deallocate() }
    let list = raw.bindMemory(to: MIDIEventList.self, capacity: 1)
    var k = 0
    while k < words.count {
        var packet = MIDIEventListInit(list, ._1_0)
        let end = min(words.count, k + 256)
        let step = words[k] >> 28 == 3 ? 2 : 1
        while k < end {
            var pair = (words[k], step == 2 ? words[k + 1] : 0)
            packet = withUnsafePointer(to: &pair) { $0.withMemoryRebound(to: UInt32.self, capacity: 2) { MIDIEventListAdd(list, 4096, packet, 0, step, $0) } }
            k += step
        }
        MIDIReceivedEventList(source, list)
    }
}
@MainActor func send(_ sysex: [UInt8]) { send(words: MIDITransport.umpWords(sysex)) }
@MainActor func message(_ status: UInt32, _ a: UInt32 = 0, _ b: UInt32 = 0) {
    send(words: [(status >= 0xF0 ? 0x1000_0000 : 0x2000_0000) | status << 16 | a << 8 | b])
}

@MainActor final class Device {
    let core = DemoOPZCore.bundled()
    let start = Date()
    var helloAt: Double?
    var asked = 0
    var now: Double { Date().timeIntervalSince(start) }

    func receive(_ f: [UInt8]) {
        guard let m = try? SysEx.decode(f) else { return }
        if m.id == 0x00, helloAt == nil { helloAt = now; print("hello from an app") }
        if m.id == 0x08 { asked += 1; print("asked for the bank (\(asked))") }
        for r in core.receive(f, now: now) { send(r) }
    }

    func play() async {
        while helloAt == nil { try? await Task.sleep(for: .milliseconds(50)) }
        try? await Task.sleep(for: .seconds(2))
        print("plays")
        message(0xFA)
        send(SysEx.frame(0x03, [0, 0x14]))
        var tick = 0, done = Set<Int>(), machines = DemoMachines(track: 5), page: UInt8 = 0
        let t0 = now, offset = OPZ.notesAt + (3 * OPZ.slotsPerStep + 8) * 8
        while now - t0 < 14 {
            if tick % 6 == 0 {
                let s = tick / 6 % 16
                // as the OP-Z does: where it is, once a pattern
                if s == 0 { send(SysEx.frame(0x05, [UInt8](repeating: 0, count: 16) + [0])) }
                if s % 4 == 0 { message(0x97, 60 + UInt32(s), 100); }
                if s % 4 == 0 { message(0x9D, 53 + UInt32(s), 100); message(0xBD, 5, 64) }            // MODULE: a chop, a dial
                if s % 4 == 1 { message(0x8D, 53 + UInt32(s) - 1) }
                if s % 4 == 2 { message(0x87, 58 + UInt32(s), 0) }
            }
            if tick % 3 == 0, now - t0 > 2 {       // as Galax-z OS v10: where the balls are, 17 a second
                machines.step(0.06)
                var m = machines.machines.messages
                m[0][1] = page
                if tick % 48 == 0 { send(SysEx.frame(0x70, m[0])) }
                send(SysEx.frame(0x71, m[1]))
            }
            if CommandLine.arguments.contains("-clock") { message(0xF8) }
            func once(_ at: Int, _ what: String, _ body: () -> Void) {
                if now - t0 > Double(at), done.insert(at).inserted { print(what); body() }
            }
            once(2, "track 6 selected") { send(SysEx.frame(0x03, [0, 0x15])) }
            once(3, "edit: bass step 4") { send(SysEx.frame(0x02, [1, 0, UInt8(offset & 255), UInt8(offset >> 8), 0, 8, 0, 0, 0x0A, 0, 0, 0x38, 0x64, 0, 0])) }
            once(4, "knob: lead P1") { send(SysEx.frame(0x0E, [5, 250] + [UInt8](repeating: 100, count: 17))) }
            once(5, "page 2") { send(SysEx.frame(0x06, [0x40, 0x1F, 0, 0])) }
            once(6, "load report") {
                var b: [UInt8] = Array("GZL1".utf8)
                for v in [2400, 118_000, 176_400, 231_000, 318_200, 0, 23, 12] { for k in 0..<4 { b.append(UInt8(v >> (8 * k) & 255)) } }
                b += [0, 0, 0]
                b.append(b.reduce(0, &+))
                for (i, n) in b.flatMap({ [$0 >> 4, $0 & 15] }).enumerated() { message(0x90, UInt32(24 + (i & 63)), UInt32(n) + 1); message(0x80, UInt32(24 + (i & 63))) }
            }
            once(8, "an edit lost (timestamps 2, 4)") { for id in [2, 4] as [UInt8] { send(SysEx.frame(0x02, [id, 0, 0, 0, 0, 3, 5, 0, 0, 1])) } }
            once(9, "the pink page") { page = 4 }
            once(11, "the teal page") { page = 5 }
            once(10, "a pattern replaced") { send(SysEx.frame(0x02, [5, 0, 0, 0, 3, 0, 2])) }
            tick += 1
            try? await Task.sleep(for: .microseconds(20_161))        // 124 beats a minute
        }
        message(0xFC)
        send(SysEx.frame(0x03, [0, 0x05]))
        print("stops")
    }
}

let device = Device()
Task { @MainActor in for await f in frames { device.receive(f) } }
Task { @MainActor in await device.play() }
print("virtual OP-Z on")
Task { try? await Task.sleep(for: .seconds(seconds)); exit(0) }
RunLoop.main.run()
