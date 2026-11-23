@testable import OPZLink
import DotKit
@testable import OPZStage
import Testing

@Suite struct SoundCopyTests {
    func run(_ from: [Float], _ ci: Int, _ co: Int, _ c: inout SoundCopy, wanted: Float) -> [Float] {
        let frames = from.count / ci
        var out = [Float](repeating: 9, count: frames * co)
        from.withUnsafeBufferPointer { f in out.withUnsafeMutableBufferPointer { o in c.copy(f.baseAddress!, channels: ci, to: o.baseAddress!, channels: co, frames: frames, wanted: wanted) } }
        return out
    }

    @Test func itComesInSmoothlyAndGoesOutSmoothly() {
        var c = SoundCopy()
        let one = [Float](repeating: 0.5, count: 8820 * 2)
        let a = run(one, 2, 2, &c, wanted: 1)
        #expect(a[0] < 0.002 && abs(a[a.count - 1] - 0.5) < 0.001)
        #expect(zip(a, a.dropFirst(2)).allSatisfy { abs($0 - $1) < 0.0015 })          // no step anywhere
        let b = run(one, 2, 2, &c, wanted: 0)
        #expect(b[0] > 0.49 && abs(b[b.count - 1]) < 0.001 && zip(b, b.dropFirst(2)).allSatisfy { abs($0 - $1) < 0.0015 })
        #expect(c.peak > 0.49 && c.peak <= 0.5)
    }

    @Test func channels() {
        var c = SoundCopy()
        _ = run([Float](repeating: 0, count: 20_000), 1, 1, &c, wanted: 1)
        func near(_ a: [Float], _ b: [Float]) -> Bool { a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) < 0.001 } }
        #expect(near(run([0.1, 0.2, 0.3, 0.4], 2, 2, &c, wanted: 1), [0.1, 0.2, 0.3, 0.4]))
        #expect(near(run([0.1, 0.2, 0.3, 0.4], 2, 1, &c, wanted: 1), [0.15, 0.35]))
        #expect(near(run([0.1, 0.2], 1, 2, &c, wanted: 1), [0.1, 0.1, 0.2, 0.2]))
        #expect(near(run([0.1, 0.2], 2, 6, &c, wanted: 1), [0.1, 0.2, 0, 0, 0, 0]))
        #expect(near(run([0.1, 0.2, 0.7, 0.7], 4, 2, &c, wanted: 1), [0.1, 0.2]))
        #expect(run([.nan, .infinity, 7, -7], 2, 2, &c, wanted: 40).allSatisfy { $0.isFinite && abs($0) <= 1 })
    }

    @Test func whichDeviceIsIt() {
        #expect(SoundCopy.isOPZ("OP-Z") && SoundCopy.isOPZ("op\u{2013}z Audio") && !SoundCopy.isOPZ("MacBook Pro Speakers") && !SoundCopy.isOPZ("OP-Z Boot") && !SoundCopy.isOPZ("OP-1"))
    }

    @Test func theChoiceIsInTheHeaderWhereThereIsRoom() {
        for (w, room) in [(300, true), (453, true), (200, false)] {
            let s = StageTests().stage(), c = DotCanvas(width: w, height: 240)
            s.input.out = "OUT OP-Z"
            for k in 0..<200 { s.frame(c, time: 3 + Double(k) / 60, dt: 1 / 60) }
            let box = s.touches.first { if case .action(.sound) = $0.1 { true } else { false } }
            #expect((box != nil) == room, "\(w)")
            if let box { #expect(s.tap(box.0.midX, box.0.midY) == .sound) }
        }
    }
}
