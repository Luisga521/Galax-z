@testable import OPZLink
import OPZModel
import Testing

@Suite struct LinkCheckTests {
    @Test func whatCameAndWhatDidNot() {
        var c = LinkCheck()
        #expect(c.missing.count == LinkCheck.Item.allCases.count - 2)          // the clock and v10's are not asked for
        for (k, id) in [0x01, 0x0A, 0x03, 0x05, 0x06, 0x0E, 0x02].enumerated() { c.heard(SysEx.frame(UInt8(id), [UInt8(k), 0xFF]), at: Double(k)) }
        c.gotSounds()
        c.heard(.noteOn(note: 60, channel: 4, velocity: 100, time: 1))
        #expect(c.missing == [.mixer])
        c.heard([0xF0, 1, 2], at: 9)
        c.heard(.playing(true)); c.heard(.clock); c.heard(.noteOff(note: 60, channel: 4, time: 2))
        #expect(c.broken == 1 && c.notes == 1 && c.starts == 1 && c.clocks == 1)
        let t = c.text(device: "OP-Z", over: "USB", seconds: 61, banksRead: 2, refetches: 1)
        #expect(t.contains("by channel: 5: 1"))
        #expect(t.contains("[x] EDITS") && t.contains("[ ] MIXER") && t.contains("[-] TUMBLER AND EUCLID") && t.contains("$05 position: 1, 2 bytes\n      03 ff"))
    }

    /// A long session keeps little, and nothing of the project.
    @Test func itStaysSmall() {
        var c = LinkCheck()
        for i in 0..<5000 { for id in UInt8(0)...0x7F { c.heard(SysEx.frame(id, [UInt8(i & 255), UInt8(i >> 8)] + [UInt8](repeating: 0x5A, count: 170)), at: Double(i)) } }
        #expect(c.messages.values.allSatisfy { $0.samples.count <= 3 && $0.samples.allSatisfy { $0.count <= 48 } && $0.count == 5000 })
        let t = c.text(device: "OP-Z", over: "USB", seconds: 1, banksRead: 1, refetches: 0)
        #expect(t.utf8.count < 70_000 && t.contains("$09 bank part: 5000, 172 bytes, 1.0 a second\n$0a"))
    }

    /// The demo has everything but notes and the mixer (and what is optional).
    @Test func theDemosDials() {
        let b = DemoOPZCore.bundled().bank
        #expect(b != nil && b!.sound(0, 4).count == 18)
    }
}
