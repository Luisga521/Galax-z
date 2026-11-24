import Foundation
import GalaxzAndroid
import Testing
@testable import GalaxzDesktop
#if os(Windows)
import WinSDK
#endif
#if canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import ImageIO
#endif

/// The demo OP-Z in a scratch folder, as the Windows app starts it, ticked on the real clock until its song is in.
func demoCore() -> DesktopCore {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("galaxz-desktop-\(UUID().uuidString)")
    let core = DesktopCore(folder: folder, files: nil, demo: true)
    let end = DesktopCore.now() + 4
    while DesktopCore.now() < end, core.spoken.hasPrefix("Galax-z.") { _ = core.tick(); Thread.sleep(forTimeInterval: 0.005) }
    #expect(!core.spoken.hasPrefix("Galax-z."), "the demo OP-Z never came")
    return core
}

/// Frames as the window would ask for them: `seconds` of them, 60 a second.
func run(_ core: DesktopCore, _ r: DotRenderer, seconds: Double) {
    var dots: [UInt8] = []
    var t = 1000.0
    for _ in 0..<Int(seconds * 60) {
        _ = core.tick()
        _ = core.frame(r.layout.w, r.layout.h, time: t, dt: 1.0 / 60, into: &dots)
        r.draw(dots, dt: 1.0 / 60)
        t += 1.0 / 60
    }
}

@Suite struct LayoutTests {
    @Test func asOnAndroid() {
        let l = DotRenderer.Layout(pxW: 1600, pxH: 1000, fineness: 240)
        #expect(l.pitch == 4 && l.w == 400 && l.h == 250 && l.ox == 0 && l.oy == 0)
        // never so few dots across that a page cannot be laid out
        let narrow = DotRenderer.Layout(pxW: 700, pxH: 1400, fineness: 240)
        #expect(narrow.w >= 200 || narrow.pitch == 3)
        let tiny = DotRenderer.Layout(pxW: 1, pxH: 1, fineness: 240)
        #expect(tiny.w >= 1 && tiny.h >= 1)
    }

    @Test func pixelsToDots() {
        let l = DotRenderer.Layout(pxW: 1003, pxH: 801, fineness: 240)
        #expect(l.dot(Double(l.ox), Double(l.oy)) == (0, 0))
        #expect(l.dot(Double(l.ox + l.pitch * 5 + 1), Double(l.oy + l.pitch * 2)) == (5, 2))
        #expect(l.dot(Double(l.ox) - 1, 0).x == -1)
    }
}

@Suite struct RendererTests {
    @Test func oneDotIsARoundLight() {
        let r = DotRenderer()
        r.resize(pxW: 800, pxH: 600)
        let l = r.layout
        var dots = [UInt8](repeating: 0, count: l.w * l.h * 4)
        let (cx, cy) = (l.w / 2, l.h / 2)
        dots[(cy * l.w + cx) * 4] = 255                  // one red dot
        r.draw(dots, dt: 1.0 / 60)
        func px(_ x: Int, _ y: Int) -> (r: UInt32, g: UInt32, b: UInt32) {
            let v = r.pixels[y * l.pxW + x]
            return (v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF)
        }
        let mid = px(l.ox + cx * l.pitch + l.pitch / 2, l.oy + cy * l.pitch + l.pitch / 2)
        // an unlit dot shows a little, on purpose (the shader's unlit glass); between dots it is dark
        let unlit = px(l.ox + l.pitch / 2, l.oy + l.pitch / 2), between = px(l.ox, l.oy)
        #expect(mid.r > 200 && mid.g < 60)
        #expect(unlit.r < 40 && unlit.r == unlit.g && unlit.g == unlit.b)
        #expect(between.r < 8 && between.g < 8 && between.b < 8)
        #expect(r.pixels.allSatisfy { $0 >> 24 == 0xFF })
    }

    @Test func anySizeAnyDots() {
        let r = DotRenderer()
        var g = SystemRandomNumberGenerator()
        for _ in 0..<12 {
            r.look.fineness = Int.random(in: 60...400, using: &g)
            r.resize(pxW: Int.random(in: 1...1300, using: &g), pxH: Int.random(in: 1...900, using: &g))
            let n = r.layout.w * r.layout.h * 4
            r.draw((0..<n).map { _ in UInt8.random(in: 0...255, using: &g) }, dt: Double.random(in: 0...0.2, using: &g))
            #expect(r.pixels.count == r.layout.pxW * r.layout.pxH)
        }
    }

    /// The demo, drawn: lights on, and fast enough for a window. GALAXZ_PREVIEW=folder also writes it as a picture.
    @Test func theDemoDraws() throws {
        let core = demoCore()
        let r = DotRenderer()
        r.resize(pxW: 1600, pxH: 1000)
        run(core, r, seconds: 2)
        let lit = r.pixels.filter { ($0 >> 16 & 0xFF) + ($0 >> 8 & 0xFF) + ($0 & 0xFF) > 150 }.count
        #expect(lit > 2000)

        var dots: [UInt8] = []
        _ = core.frame(r.layout.w, r.layout.h, time: 2000, dt: 1.0 / 60, into: &dots)
        let start = Date()
        for _ in 0..<20 { r.draw(dots, dt: 1.0 / 60) }
        let ms = Date().timeIntervalSince(start) / 20 * 1000
        print("1600 × 1000: \(String(format: "%.1f", ms)) ms a frame")

        #if canImport(CoreGraphics) && canImport(ImageIO)
        if let dir = ProcessInfo.processInfo.environment["GALAXZ_PREVIEW"] {
            for (i, page) in [0, 1, 2, 3].enumerated() {
                core.setPage(page)
                run(core, r, seconds: 1)
                try png(r, URL(fileURLWithPath: dir).appendingPathComponent("windows-\(i).png"))
            }
        }
        #endif
    }
}

#if canImport(CoreGraphics) && canImport(ImageIO)
func png(_ r: DotRenderer, _ url: URL) throws {
    let l = r.layout
    let data = r.pixels.withUnsafeBytes { Data($0) }
    let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    let image = CGImage(width: l.pxW, height: l.pxH, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: l.pxW * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info,
                        provider: CGDataProvider(data: data as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    #expect(CGImageDestinationFinalize(dest))
}
#endif

@Suite struct PointerTests {
    @Test func aSwipeTurnsThePage() {
        let core = demoCore()
        let p = Pointer(core)
        let l = DotRenderer.Layout(pxW: 1600, pxH: 1000, fineness: 240)
        let before = core.spoken
        p.down(1200, 990, l)
        p.move(800, 990, l)
        #expect(p.up(700, 995, l) == .none)
        #expect(core.spoken != before)
    }

    @Test func aShortWobbleIsNoSwipe() {
        let core = demoCore()
        let p = Pointer(core)
        let l = DotRenderer.Layout(pxW: 1600, pxH: 1000, fineness: 240)
        let before = core.spoken
        p.down(5, 995, l)
        _ = p.up(30, 995, l)            // 25 px: neither a tap nor a swipe
        #expect(core.spoken == before)
    }
}

@Suite struct TimedSenderTests {
    final class Got: @unchecked Sendable {
        let lock = NSLock(); var items: [(Double, [UInt8])] = []
        func add(_ t: Double, _ b: [UInt8]) { lock.lock(); items.append((t, b)); lock.unlock() }
        var all: [(Double, [UInt8])] { lock.lock(); defer { lock.unlock() }; return items }
    }

    @Test func inTimeAndInOrder() async throws {
        #if os(Windows)
        timeBeginPeriod(1)                  // as the app does: Windows' timers otherwise wake 15.6 ms apart
        defer { timeEndPeriod(1) }
        #endif
        let got = Got()
        let clock = DesktopCore.now             // the app's clock: on Windows, systemUptime counts whole milliseconds
        let s = TimedSender(clock: clock) { got.add(clock(), $0) }
        let t0 = clock()
        s.add([(t0 + 0.060, [0x90, 60, 100]), (t0 + 0.020, [0x90, 61, 100]), (0, [0xF0, 1, 0xF7]), (t0 + 0.040, [0x80, 61, 0])])
        try await Task.sleep(for: .milliseconds(150))
        s.stop()
        let all = got.all
        #expect(all.map { $0.1 } == [[0xF0, 1, 0xF7], [0x90, 61, 100], [0x80, 61, 0], [0x90, 60, 100]])
        for (sent, due) in zip(all.dropFirst().map(\.0), [t0 + 0.020, t0 + 0.040, t0 + 0.060]) {
            #expect(sent >= due && sent - due < 0.010, "late by \((sent - due) * 1000) ms")
        }
    }
}
