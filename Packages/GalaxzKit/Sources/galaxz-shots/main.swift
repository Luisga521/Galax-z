import CoreGraphics
import ChopKit
import DotKit
import Foundation
import ImageIO
import OPZLink
import OPZModel
import OPZStage

/// galaxz-shots DIR [WxH] [PAGE…] [-project FILE.opz [-pattern N] [-settings FOLDER]]: every page with the demo song (or a project of
/// yours, from a backup), as PNGs drawn the way the Metal pass draws them, and what a frame costs.
var args = Array(CommandLine.arguments.dropFirst())
@MainActor func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    defer { args.removeSubrange(i...i + 1) }
    return args[i + 1]
}
let projectFile = option("-project"), patternNumber = option("-pattern").flatMap(Int.init) ?? 1, settingsFolder = option("-settings")
let noMachines = args.contains("-v9")
args.removeAll { $0 == "-v9" }
/// Pictures in a row for a film (Tools/gifs.sh) instead of one of each.
let film = args.contains("-film")
args.removeAll { $0 == "-film" }
let pitch = film ? 4 : 6
let dir = URL(filePath: args.first ?? ".")
let size = (args.dropFirst().first { $0.first?.isNumber == true } ?? "360x240").split(separator: "x").map { Int($0)! }
let only = args.dropFirst().filter { $0.first?.isNumber != true }
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

@MainActor func write(_ c: DotCanvas, _ name: String) {
    let W = c.width * pitch, H = c.height * pitch
    var light = [SIMD3<Float>](repeating: .zero, count: c.count)
    func lin(_ v: UInt32) -> Float { pow(Float(v & 255) / 255, 1.55) }
    for i in 0..<c.count { let v = c.dots[i]; light[i] = SIMD3(lin(v), lin(v >> 8), lin(v >> 16)) }
    var bloom = light
    for (dx, dy) in [(1, 0), (0, 1), (2, 0), (0, 2)] {
        var out = bloom
        for y in 0..<c.height { for x in 0..<c.width {
            func at(_ k: Int) -> SIMD3<Float> {
                let xx = min(max(x + dx * k, 0), c.width - 1), yy = min(max(y + dy * k, 0), c.height - 1)
                return bloom[yy * c.width + xx]
            }
            out[y * c.width + x] = at(0) * 0.34 + (at(1) + at(-1)) * 0.23 + (at(2) + at(-2)) * 0.1
        } }
        bloom = out
    }
    var px = [UInt8](repeating: 255, count: W * H * 4)
    for y in 0..<H { for x in 0..<W {
        let gx = x / pitch, gy = y / pitch, i = gy * c.width + gx
        let fx = Float(x % pitch) + 0.5 - Float(pitch) / 2, fy = Float(y % pitch) + 0.5 - Float(pitch) / 2
        let d = (fx * fx + fy * fy).squareRoot(), l = light[i], m = max(l.x, l.y, l.z)
        let r = Float(pitch) * (0.30 + 0.13 * min(1, m.squareRoot()))
        let cover = min(1, max(0, r - d + 0.5))
        var v = l * cover + SIMD3<Float>(repeating: 0.0035) * min(1, max(0, Float(pitch) * 0.3 - d + 0.5)) + bloom[i] * 0.22
        v = v / (v * 0.12 + 1)
        for (k, e) in [v.x, v.y, v.z].enumerated() { px[(y * W + x) * 4 + k] = UInt8(min(255, pow(max(0, e), 1 / 2.2) * 255)) }
    } }
    let ctx = CGContext(data: &px, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let dest = CGImageDestinationCreateWithURL(dir.appending(path: name + ".png") as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

// the demo OP-Z, read through the real client
let core = DemoOPZCore.bundled(), client = StateSyncClient()
var now = 0.0, queue = client.tick(now: 0, forceHello: true)
while !queue.isEmpty {
    now += 0.01
    let f = queue.removeFirst()
    for reply in core.receive(f, now: now) { queue += client.receive(reply, now: now) }
}
let files = FileClient()
queue = files.start(now: now)
for _ in 0..<4000 {
    now += 0.01
    if queue.isEmpty { queue = files.tick(now: now) }
    if files.phase == .done { break }
    guard !queue.isEmpty else { continue }
    let f = queue.removeFirst()
    for reply in core.receive(f, now: now) { queue += files.receive(reply, now: now) }
}
var settings = files.files[FileClient.plugs].flatMap { p in files.files[FileClient.slotConfiguration].flatMap { OPZSettings(plugsJSON: p, slotsJSON: $0) } }

let stage = Stage(), canvas = DotCanvas(width: size[0], height: size[1])
var input = StageInput()
canvas.clear()
for i in 0..<120 { stage.frame(canvas, time: Double(i) / 60, dt: 1 / 60) }
let fps = 15
if film {
    for k in 0..<(5 * fps) {
        for i in 0..<8 { stage.frame(canvas, time: 2 + (Double(k) + Double(i) / 8) / Double(fps), dt: 1 / 120) }
        write(canvas, String(format: "connect-%03d", k))
    }
}
write(canvas, "0-connect")

input.link = .live; input.linkName = "DEMO"
input.bank = client.bank; input.revision = 1; input.address = client.playAddress ?? client.bankAddress
input.tempo = client.global?.tempo; input.swing = client.global?.swing
input.notice = "GALAX-Z V13"
if let f = projectFile {
    let b = [UInt8](try Data(contentsOf: URL(filePath: f)))
    input.bank = Bank(Array(b[(4 + OPZ.globalSize)..<(4 + OPZ.globalSize + OPZ.bankSize)]))
    input.address = PatternAddress(raw: patternNumber - 1)
    let g = GlobalBlock(Array(b[4..<4 + OPZ.globalSize]))
    input.tempo = g?.tempo
    input.swing = g?.swing
    if let d = settingsFolder.map({ URL(filePath: $0) }) {
        settings = OPZSettings(plugsJSON: [UInt8](try Data(contentsOf: d.appending(path: "plugs.json"))), slotsJSON: [UInt8](try Data(contentsOf: d.appending(path: "slotConfiguration.json"))))
    }
    input.notice = nil
}
for t in 0..<16 {
    let s = Sound(plug: Int(input.bank!.track(input.address!.pattern, t).plug), settings: settings)
    input.sounds[t] = s
    input.slots[t] = s.flatMap { settings?.slot(of: $0.plug, track: t) }
}
input.panel.playing = true
input.panel.told = 1
var demo = DemoMachines()
let machinesOn = !noMachines
var told = 0.0
@MainActor func run(_ seconds: Double, from t0: Double) -> Double {
    var t = t0
    let end = t0 + seconds
    while t < end {
        if machinesOn, t - told > 0.04 { demo.step(0.04); told = t; let page = input.machines?.page ?? 0; input.machines = demo.machines; input.machines!.page = page }
        stage.input = input
        stage.frame(canvas, time: t, dt: 1 / 120)
        t += 1 / 120
    }
    return t
}
stage.chops.list = SungVoice.kit.chops; stage.chops.shape = SungVoice.kit.shape(320); stage.chops.length = SungVoice.kit.audio.count; stage.chops.sounding = 1 << 6; stage.chops.chosen = 6
var t = run(4, from: 2)
if film {
    @MainActor func shoot(_ name: String, _ page: Stage.Page, seconds: Int, _ each: (Int) -> Void = { _ in }) {
        stage.page = page
        t = run(0.4, from: t)
        for k in 0..<(seconds * fps) { each(k); t = run(1 / Double(fps), from: t); write(canvas, String(format: "\(name)-%03d", k)) }
    }
    let tracks = [0, 5, 4, 7, 6, 2]
    shoot("track", .track, seconds: 6) { k in if k % fps == 0 { stage.select(track: tracks[k / fps % tracks.count]) } }
    shoot("grid", .grid, seconds: 4)
    shoot("chops", .chops, seconds: 4) { k in if k % 4 == 0 { let c = (k / 4 * 7) % 24; stage.chops.sounding = 1 << UInt32(c); stage.chops.chosen = c } }
    stage.select(track: 4)
    shoot("fx", .fx, seconds: 5)
    shoot("notes", .notes, seconds: 4)
    shoot("sky", .sky, seconds: 5)
    exit(0)
}
for p in Stage.Page.allCases where only.isEmpty || only.contains(p.name.lowercased()) {
    stage.page = p
    if p == .notes { for (i, n) in [48, 55, 60, 64, 67].enumerated() { stage.noteOn(channel: 4 + i % 4, note: n, velocity: 100) } }
    t = run(1.2, from: t)
    write(canvas, "\(p.rawValue + 1)-\(p.name.lowercased())")
    // what a frame costs
    let start = DispatchTime.now().uptimeNanoseconds, n = 240
    for i in 0..<n { stage.frame(canvas, time: t + Double(i) / 120, dt: 1 / 120) }
    let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6 / Double(n)
    t += Double(n) / 120
    print(String(format: "%-6@ %.2f ms a frame, %dx%d", p.name as NSString, ms, canvas.width, canvas.height))
}
if only.isEmpty || only.contains("track") {
    stage.page = .track
    for k in 0..<16 { stage.select(track: k); t = run(0.7, from: t); write(canvas, "track-\(k + 1 < 10 ? "0" : "")\(k + 1)") }
}
if only.isEmpty || only.contains("machines"), machinesOn {
    for (p, name) in [(4, "tumbler"), (5, "euclid")] {
        input.machines?.page = p
        stage.page = .track; stage.select(track: 4); t = run(1, from: t); write(canvas, "track-\(name)")
        stage.page = .fx; t = run(1, from: t); write(canvas, "fx-\(name)")
    }
    input.machines?.page = 0
}
if only.contains("load") || only.isEmpty {
    var b: [UInt8] = Array("GZL1".utf8)
    for v in [2400, 118_000, 176_400, 231_000, 318_200, 0, 23, 12] { for k in 0..<4 { b.append(UInt8(v >> (8 * k) & 255)) } }
    b += [0, 0, 0]
    b.append(b.reduce(0, &+))
    input.load = LoadReport(b)
    t = run(1, from: t)
    write(canvas, "8-load-report")
}
