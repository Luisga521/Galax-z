#if canImport(CoreMIDI)
import CoreMIDI
#endif
import Foundation
import Testing
@testable import OPZLink
@testable import OPZModel

@Suite struct KeyTestTests {
    @Test func aBounceIsADouble() {
        var test = KeyTest()
        test.noteOn(53, channel: 4, at: 1.000)
        test.noteOff(53, channel: 4, at: 1.004)
        test.noteOn(53, channel: 4, at: 1.012) // 12 ms later: the key bounced
        test.noteOff(53, channel: 4, at: 1.090)
        test.noteOn(53, channel: 4, at: 1.400) // a real second press
        #expect(test.presses == 3)
        #expect(test.doubles == 1)
        #expect(test.keysWithDoubles == [53])
        #expect(abs((test.fastest ?? 0) - 0.012) < 1e-9)
        #expect(test.log.count == 3)
        #expect(test.isDouble(test.log[1]))
        #expect(!test.isDouble(test.log[0]))
        #expect(abs((test.log[1].heldBefore ?? 0) - 0.004) < 1e-9) // the first press was held 4 ms
        test.window = 0.010
        #expect(test.doubles == 0) // a narrower window: 12 ms is no longer a double
    }

    @Test func fastPlayingIsNotADouble() {
        var test = KeyTest()
        for i in 0..<8 { test.noteOn(60, channel: 0, at: Double(i) * 0.09) } // 90 ms apart: a fast trill
        #expect(test.presses == 8 && test.doubles == 0)
    }

    @Test func listensOnTheFirstChannelOnly() {
        var test = KeyTest()
        test.noteOn(53, channel: 4, at: 0)
        test.noteOn(53, channel: 0, at: 0.005) // the sequencer on another track
        #expect(test.presses == 1 && test.ignored == 1 && test.channel == 4)
    }

    @Test func followsTheOctave() {
        var test = KeyTest()
        test.noteOn(53 + 30, channel: 0, at: 0) // played an octave up
        #expect(test.firstNote == 65)
        #expect(test.key(of: 83) == 18)
        test.noteOn(41, channel: 0, at: 1) // and two octaves down
        #expect(test.firstNote == 41)
        #expect(KeyTest.name(53) == "F3" && KeyTest.name(76) == "E5")
        test.reset()
        #expect(test.presses == 0 && test.firstNote == 53)
    }

    @Test func theReportNamesTheBouncingKeys() {
        var test = KeyTest()
        test.noteOn(57, channel: 1, at: 0)
        test.noteOn(57, channel: 1, at: 0.009)
        #expect(test.report.contains("A3: 2 presses, 1 doubles, fastest 9 ms"))
        #expect(test.report.contains("channel 2"))
    }
}

#if canImport(CoreMIDI)
/// Notes and start/stop arrive through the same CoreMIDI read block as SysEx, on CoreMIDI's thread.
@Suite struct KeyEventReaderTests {
    static func at(_ e: KeyEvent) -> Double { if case .playing(_, let t) = e { t } else { -1 } }

    struct Call: @unchecked Sendable { let block: MIDIReceiveBlock; let list: UnsafeMutablePointer<MIDIEventList> }

    @Test func notesComeWithTheirTimestamps() async {
        let (frames, framesIn) = AsyncStream.makeStream(of: [UInt8].self)
        let (keys, keysIn) = AsyncStream.makeStream(of: KeyEvent.self)
        _ = frames
        let size = 1024
        let raw = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 8)
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: MIDIEventList.self, capacity: 1)
        let t0: MIDITimeStamp = 1_000_000_000
        var packet = MIDIEventListInit(list, ._1_0)
        // channel 5 note on F3 (vel 100), its note off (as note on vel 0), MIDI start
        for (word, stamp) in [(UInt32(0x2094_3564), t0), (UInt32(0x2094_3500), t0 + 240_000), (UInt32(0x10FA_0000), t0)] {
            var w = word
            packet = MIDIEventListAdd(list, size, packet, stamp, 1, &w)
        }
        let call = Call(block: MIDITransport.readBlock(UMPReader(framesIn, keys: keysIn)), list: list)
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            Thread.detachNewThread {
                call.block(call.list, nil)
                done.resume()
            }
        }
        keysIn.finish()
        var got: [KeyEvent] = []
        for await k in keys { got.append(k) }
        let t = Double(t0) * UMPReader.tick
        let off = Double(t0 + 240_000) * UMPReader.tick
        #expect(got == [.noteOn(note: 53, channel: 4, velocity: 100, time: t), .noteOff(note: 53, channel: 4, time: off), .playing(true, time: KeyEventReaderTests.at(got[2]))])
    }
}
#endif
