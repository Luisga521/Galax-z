import OPZLink
@testable import OPZModel
@testable import OPZStage
import Testing

@Suite struct MIDISettingsTests {
    static func bytes(channels: [Int] = Array(0..<16), off: Set<Int> = [], flags: UInt8 = 0b110) -> [UInt8] {
        (0..<16).map { off.contains($0) ? 0 : 1 } + channels.map(UInt8.init) + [UInt8](repeating: 20, count: 256) + [flags, 0, 0, 0]
    }
    /// zlib with nothing packed.
    static func zlib(_ b: [UInt8]) -> [UInt8] {
        let n = UInt16(b.count), a = Zlib.adler32(b)
        return [0x78, 0x01, 1, UInt8(n & 255), UInt8(n >> 8), UInt8(~n & 255), UInt8(~n >> 8)] + b + [UInt8(a >> 24), UInt8(a >> 16 & 255), UInt8(a >> 8 & 255), UInt8(a & 255)]
    }

    @Test func whoseNotesComeOnAChannel() {
        let usual = MIDISettings(Self.bytes())!
        #expect((0..<16).allSatisfy { usual.track(channel: $0, selected: 5) == $0 })
        // the kick on 16, the bass and the lead both on 5
        var c = Array(0..<16); c[0] = 15; c[15] = 0; c[5] = 4
        let m = MIDISettings(Self.bytes(channels: c, off: [0], flags: 0b111))!
        #expect(m.track(channel: 15, selected: nil) == 0 && m.track(channel: 0, selected: nil) == 15)
        #expect(m.track(channel: 4, selected: 5) == 5 && m.track(channel: 4, selected: 1) == 4 && m.track(channel: 5, selected: 5) == nil)
        #expect(m.placed(.noteOn(track: 0, note: 60, velocity: 1)) == [0x9F, 60, 1] && m.placed(.gain(track: 5, value: 9)) == [0xB4, 50, 9])
        #expect(m.placed(.pattern(project: 0, 3)) == [0xB0, 103, 3] && m.placed(.start) == [0xFA])
        #expect(!m.enabled[0] && m.channelOneToActive && m.incoming && m.outgoing)
        #expect(m.lines[1].contains("1 kick") && m.lines[2].contains("1 on 16") && usual.lines[1].hasSuffix("none"))
        #expect(MIDISettings([]) == nil && MIDISettings([UInt8](repeating: 200, count: 292)) == nil)
    }

    /// As the author's OP-Z answered (2026-11-22): the kick on 16, with motion.
    @Test func thekickOnSixteen() {
        var c = Array(0..<16); c[0] = 15
        let m = MIDISettings(Self.bytes(channels: c, flags: 0x97))!
        #expect(m.track(channel: 15, selected: 0) == 0 && m.track(channel: 15, selected: 4) == 0 && m.track(channel: 15, selected: 15) == 15)
        #expect(m.track(channel: 0, selected: 0) == nil && m.track(channel: 7, selected: 7) == 7)
        #expect(m.placed(.noteOn(track: 0, note: 60, velocity: 100)) == [0x9F, 60, 100])
    }

    @Test func itIsHeard() {
        let c = StateSyncClient()
        _ = c.receive(SysEx.frame(0x10, Self.zlib(Self.bytes(off: [0]))), now: 1)
        #expect(c.midi?.enabled[0] == false && c.midi?.channels == Array(0..<16))
        _ = c.receive(SysEx.frame(0x10, [1, 2, 3]), now: 2)                                     // nonsense: as it was
        #expect(c.midi != nil)
        c.reset()
        #expect(c.midi == nil)
        #expect(SysEx.frame(0x0F) == [0xF0, 0x00, 0x20, 0x76, 0x01, 0x0F, 0xF7])                // what asks for it: nothing in it
    }

    @Test func aTrackWhoseNotesCannotComeSaysSo() {
        let s = StageTests().stage()
        #expect(s.deaf(0) == nil)
        s.input.midi = MIDISettings(Self.bytes(off: [0]))
        #expect(s.deaf(0)!.contains("TRACK 1") && s.deaf(1) == nil)
        s.input.midi = MIDISettings(Self.bytes(flags: 2))
        #expect(s.deaf(1)!.contains("MIDI OUT"))
    }
}
