#if DEBUG
import DotKit
import MetalKit
import OPZFirmware
import OPZLink
import OPZStage
import UIKit

/// The app trying itself, with nobody there (debug builds): `-selftest DIR` follows whatever OP-Z there is (galaxz-fakeopz) and draws
/// every page with the real GPU passes; with `-updateport PATH -flash LABEL` it goes the hub's whole way over that port
/// (Firmware/tools/fake_update_port.py). `-scratch DIR` keeps its backups and releases out of the real ones. Writes DIR/report.txt and
/// pictures, and quits.
@MainActor enum SelfTest {
    static func value(_ name: String) -> String? {
        let a = ProcessInfo.processInfo.arguments
        return a.firstIndex(of: name).flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil }
    }
    nonisolated static var scratch: URL? {
        let a = ProcessInfo.processInfo.arguments
        return a.firstIndex(of: "-scratch").flatMap { $0 + 1 < a.count ? URL(filePath: a[$0 + 1]) : nil }
    }
    nonisolated static var port: String? {
        let a = ProcessInfo.processInfo.arguments
        return a.firstIndex(of: "-updateport").flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil }
    }

    private static var lines: [String] = []
    private static func say(_ s: String) { lines.append(s); print("selftest:", s) }

    static func start(_ live: Live, _ hub: Hub) {
        guard let dir = value("-selftest").map({ URL(filePath: $0) }) else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        Task {
            live.stage.set(.chopDial(7), to: 12)                  // hardly to be heard
            if value("-updateport") != nil { await update(hub) }
            else if ProcessInfo.processInfo.arguments.contains("-window") { await window(live, dir) }
            else { await follow(live, dir) }
            try? lines.joined(separator: "\n").write(to: dir.appending(path: "report.txt"), atomically: true, encoding: .utf8)
            exit(0)
        }
    }

    // MARK: the screen

    private static func follow(_ live: Live, _ dir: URL) async {
        let begin = CACurrentMediaTime()
        func t() -> String { String(format: "%5.2f", CACurrentMediaTime() - begin) }
        while live.status != .live || live.settings == nil, CACurrentMediaTime() - begin < 20 { try? await Task.sleep(for: .milliseconds(20)) }
        say("\(t()) status \(live.status) device \(live.deviceName ?? "-") sounds \(live.settings?.plugs.count ?? 0) project \(live.address.map { "\($0.project + 1)/\($0.pattern + 1)" } ?? "-") tempo \(live.tempo ?? 0)")
        guard MIDITransport.onlyVirtual, live.transport == .other else { return say("NOT a virtual OP-Z (\(String(describing: live.transport))): nothing is tried on a real one") }
        let stage = live.stage, canvas = DotCanvas(width: 320, height: 220), gpu = GPU()
        var before = "", steps: [Int] = [], frames = 0, worst = 0.0, hits = Set<Int>()
        func settle(_ seconds: Double) async {
            let end = CACurrentMediaTime() + seconds
            while CACurrentMediaTime() < end {
                let a = CACurrentMediaTime()
                stage.frame(canvas, time: a, dt: 1 / 120)
                worst = max(worst, CACurrentMediaTime() - a)
                frames += 1
                let p = stage.input.panel, h = stage.playhead
                if h.playing, steps.last != h.step { steps.append(h.step) }
                for k in 0..<16 where stage.hits[k] > 0.2 { hits.insert(k) }
                let now = "track \(stage.track + 1) playing \(h.playing) page \(p.page) P1 of lead \(live.bank?.sound(live.address?.pattern ?? 0, 5)[0] ?? -1) bass step 4 \(live.bank?.notes(live.address?.pattern ?? 0, 4, 3).first.map { "\($0.note)@\($0.velocity)" } ?? "-") load \(stage.input.load?.instrumentsTop ?? 0) reads \(live.bankReads) on \(stage.page.name) machines \(stage.input.machines.map { "track \($0.track + 1) page \($0.page) balls \($0.balls.count) rings \($0.rings.count)" } ?? "-")"
                if now != before { before = now; say("\(t()) \(now)") }
                try? await Task.sleep(for: .microseconds(8_300))
            }
        }
        func picture(_ name: String) {
            guard let png = gpu?.picture(of: canvas, pitch: 6) else { return say("no picture") }
            try? png.write(to: dir.appending(path: name + ".png"))
        }
        await settle(8.5)
        let order = zip(steps, steps.dropFirst()).filter { $1 == ($0 + 1) % 16 }.count
        say("\(t()) steps seen \(steps.count), in order \(order); tracks that sounded \(hits.sorted().map { $0 + 1 })")
        for p in Stage.Page.allCases { stage.page = p; await settle(0.9); picture("\(p.rawValue + 1)-\(p.name.lowercased())") }
        // MODULE's chops, and a file made into a kit
        say("\(t()) chops: \(live.sampler.kitName), loudest \(live.sampler.loudest), dial TONE \(stage.chops.dials[4])")
        let wav = dir.appending(path: "three hits.wav")
        var x = [Float](repeating: 0, count: 66_150)
        for h in 0..<3 { for i in 0..<6000 { x[4000 + h * 20_000 + i] = sin(Float(i) * 0.06) * exp(-Float(i) / 1500) } }
        try? Sampler.write(x, rate: 44_100, to: wav)
        live.sampler.open(wav)
        say("\(t()) opened: \(live.sampler.kitName), kits \(live.sampler.kitCount), line \(stage.chops.line)")
        stage.chops.cut = .eight; stage.ask(.cut(.eight))
        say("\(t()) cut again: \(live.sampler.kitName), kits \(live.sampler.kitCount)")
        stage.ask(.start(2, velocity: 1, id: 1, semitones: 0))
        await settle(0.4)
        say("\(t()) its chop: loudest \(live.sampler.loudest)")
        stage.ask(.kit(1)); say("\(t()) kit \(live.sampler.kitName)")
        stage.ask(.kit(-1)); say("\(t()) kit \(live.sampler.kitName)")
        // out to it: a fader, a mute, a chord's notes, a move and what it put back
        stage.set(.gain(track: 2), to: 64); _ = stage.press(.mute(track: 3), velocity: 1); _ = stage.press(.mute(track: 3), velocity: 1)
        stage.keyDown(60, velocity: 90)
        _ = stage.press(.move(pad: 0), velocity: 100)
        await settle(1)
        stage.keyUp(60)
        _ = stage.press(.move(pad: 0), velocity: 0)
        await settle(3)
        say("\(t()) frames \(frames), slowest to draw \(String(format: "%.2f", worst * 1000)) ms, still playing \(stage.playhead.playing), reads \(live.bankReads)")
        do { say("link check:\n" + (try String(contentsOf: live.saveCheck(), encoding: .utf8))) } catch { say("link check: \(error)") }
        while live.status == .live, CACurrentMediaTime() - begin < 60 { try? await Task.sleep(for: .milliseconds(100)) }
        await settle(0.5)
        say("\(t()) after it went away: status \(live.status)")
        picture("8-gone")
    }

    // MARK: the window, on the display there is (`-window`, with `-demo`)

    private static func window(_ live: Live, _ dir: URL) async {
        func cpu() -> Double { var u = rusage(); getrusage(RUSAGE_SELF, &u); return Double(u.ru_utime.tv_sec + u.ru_stime.tv_sec) + Double(u.ru_utime.tv_usec + u.ru_stime.tv_usec) / 1e6 }
        func dots(_ v: UIView) -> DotView? { (v as? DotView) ?? v.subviews.lazy.compactMap(dots).first }
        var view: DotView?
        for _ in 0..<100 where view == nil {
            try? await Task.sleep(for: .milliseconds(100))
            view = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first }.compactMap { $0.rootViewController?.view }.compactMap(dots).first
        }
        guard let view, let w = view.window else { return say("no window") }
        try? await Task.sleep(for: .seconds(2))
        say("window \(Int(w.bounds.width))x\(Int(w.bounds.height)) on \(Int(w.screen.bounds.width))x\(Int(w.screen.bounds.height)) at \(w.screen.maximumFramesPerSecond) Hz; scene \(w.windowScene?.activationState.rawValue ?? -9); \(view.shape)")
        for p in Stage.Page.allCases {
            live.stage.page = p
            view.changed()
            try? await Task.sleep(for: .milliseconds(500))
            let f = view.framesDrawn, c = cpu(), t = CACurrentMediaTime()
            try? await Task.sleep(for: .seconds(2))
            let s = CACurrentMediaTime() - t
            say(String(format: "%@: %.0f frames a second on the display, %.1f %% of a core", p.name, Double(view.framesDrawn - f) / s, (cpu() - c) / s * 100))
        }
        // resized, as a person drags it
        for size in [CGSize(width: 760, height: 560), CGSize(width: 1500, height: 900)] {
            w.windowScene?.requestGeometryUpdate(.Mac(systemFrame: CGRect(origin: CGPoint(x: 60, y: 60), size: size))) { e in say("resize: \(e)") }
            try? await Task.sleep(for: .seconds(1))
            say("resized: window \(Int(w.bounds.width))x\(Int(w.bounds.height)); \(view.shape)")
        }
        live.useDemo(false)
        try? await Task.sleep(for: .seconds(2))
        say("demo off: \(live.status)")
        let image = UIGraphicsImageRenderer(bounds: w.bounds).image { _ in w.drawHierarchy(in: w.bounds, afterScreenUpdates: false) }
        try? image.pngData()?.write(to: dir.appending(path: "window.png"))
    }

    // MARK: the hub

    private static func update(_ hub: Hub) async {
        func state(_ what: String) {
            hub.refreshPorts()
            say("\(what): ports \(hub.ports.count) installed \(hub.installed ?? "-") known \(hub.lastKnown ?? "-") just \(hub.justInstalled ?? "-") interrupted \(hub.interrupted ?? "-") "
                + "powercycle \(hub.mustPowerCycle) result \(hub.result.map { "\($0.ok) \($0.text)" } ?? "-") step \(hub.step(backedUp: true))")
        }
        func done() async { repeat { try? await Task.sleep(for: .milliseconds(50)) } while hub.busy != nil }
        while !hub.loaded { try? await Task.sleep(for: .milliseconds(5)) }
        say(String(format: "versions in after %.3f s, %d images", hub.loadSeconds, hub.images.count))
        state("at start")
        if let label = value("-flash") {
            say("before reading, \(label) is \(hub.notReady(label) ?? "READY (it must not be)")")
            hub.flash(label)
            say("flash before reading started a write: \(hub.busy != nil)")
            hub.check()
            await done()
            state("read")
            say("\(label): \(hub.notReady(label) ?? "ready")")
            hub.flash(label)
            hub.flash(label)                                  // twice: once is enough
            say("busy \(hub.busy ?? "-") writing \(hub.writing)")
            await done()
            state("after the install")
            hub.check()
            await done()
            state("read again")
        }
        for l in hub.log.suffix(6) { say("log: \(l)") }
    }
}

extension GPU {
    /// What the screen would show, as a PNG: the same passes into a texture.
    func picture(of c: DotCanvas, pitch: Int) -> Data? {
        let w = c.width * pitch, h = c.height * pitch
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        d.usage = [.renderTarget]
        d.storageMode = .shared
        guard let t = device.makeTexture(descriptor: d) else { return nil }
        let look = Look(origin: .zero, pitch: Float(pitch), glow: 0.8 * 0.42, unlit: 0.0046, decay: 0, size: SIMD2(Float(c.width), Float(c.height)))
        draw(c, into: t, look)?.waitUntilCompleted()
        var px = [UInt8](repeating: 0, count: w * h * 4)
        t.getBytes(&px, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue), let im = ctx.makeImage() else { return nil }
        return UIImage(cgImage: im).pngData()
    }
}
#endif
