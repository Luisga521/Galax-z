import Foundation
@testable import OPZFirmware
import Testing

/// The bootloader's console, byte for byte as decoded (Firmware/notes/update-write.md); port of fake_console.py.
final class FakeConsole: ConsoleTransport {
    var files: [String: [UInt8]]
    var types: [UInt8] = [], forbidden: [UInt8] = []
    var dropReplyAfter: Int?, corruptAt: Int?
    /// The port fails on the write after this many bytes of file data (a cable pulled mid-upload).
    var failAfterData: Int?
    private var dataBytes = 0
    private var out: [UInt8] = [], eatFirst = true, esc = false
    private var state = "routing", hdr: [UInt8] = [], name: [UInt8] = [], size: [UInt8] = []
    private var type: UInt8 = 0, length = 0
    private var upload: (name: String, buf: [UInt8], counter: Int, pieces: Int)?

    init(_ files: [String: [UInt8]], dropReplyAfter: Int? = nil, corruptAt: Int? = nil) {
        self.files = files; self.dropReplyAfter = dropReplyAfter; self.corruptAt = corruptAt
    }

    func write(_ bytes: [UInt8]) throws {
        if let failAfterData, dataBytes > failAfterData { throw ConsoleError.refused("the OP-Z went away") }
        for var b in bytes {
            if b == 0xC0 { state = "routing"; esc = false; name = []; continue }
            if esc { b ^= 0x20; esc = false } else if b == 0x7D { esc = true; continue }
            byte(b)
        }
    }

    func read(timeout: TimeInterval) throws -> [UInt8] {
        if out.isEmpty { Thread.sleep(forTimeInterval: min(timeout, 0.01)) }
        defer { out = [] }
        return out
    }

    func discardInput() { out = [] }

    private func reply(_ t: UInt8, _ p: [UInt8] = []) {
        if eatFirst { eatFirst = false; return }
        out += [0xC0] + UpdateConsole.escape([0x1E, t] + LDR.le(UInt32(p.count)).reversed() + p)
    }

    private func byte(_ b: UInt8) {
        switch state {
        case "data": data(b)
        case "routing": hdr = [b]; state = "header"
        case "header":
            hdr.append(b)
            guard hdr.count == 6 else { return }
            type = hdr[1]; length = Int(UpdateConsole.be(hdr, 2)); types.append(type)
            switch type {
            case 0x00: state = "idle"; reply(0x01)
            case 0x19: state = "name"
            case 0x11: state = "size"; size = []
            default: forbidden.append(type); state = "idle"
            }
        case "size":
            size.append(b)
            if size.count == 4 { state = "name" }
        case "name":
            if b != 0 { name.append(b); return }
            let n = String(decoding: name, as: UTF8.self)
            if type == 0x19 {
                state = "idle"
                if let f = files[n] { reply(0x20, f) }
            } else {
                files[n] = []
                upload = (n, [], 4 + name.count + 1, 0)
                state = "data"
                if upload!.counter == length { finish() }
            }
        default: break
        }
    }

    private func data(_ b: UInt8) {
        guard var up = upload else { return }
        dataBytes += 1
        let index = up.counter - (4 + up.name.utf8.count + 1)
        up.buf.append(corruptAt == index ? b ^ 0xFF : b)
        up.counter += 1
        upload = up
        if up.counter == length { return finish() }
        if up.buf.count == 2048 {
            files[up.name, default: []] += up.buf
            upload!.buf = []; upload!.pieces += 1
            if dropReplyAfter == nil || upload!.pieces <= dropReplyAfter! { reply(0x12) }
        }
    }

    private func finish() {
        guard let up = upload else { return }
        files[up.name, default: []] += up.buf
        upload = nil; state = "idle"
        reply(0x13, [1, 0])
    }
}

/// FIRST|IGNORE header, two data blocks, a fill, FINAL: the shape of the OS image (no TE code).
func syntheticImage() -> [UInt8] {
    let code = Array(0..<16 as Range<UInt8>), table: [UInt8] = [0xC0, 0x7D, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]
    let body = LDR.header(flags: 4, target: 0x8000_0000, count: 16) + code
        + LDR.header(flags: 4, target: 0x8000_1000, count: 8) + table + LDR.header(flags: 0x104, target: 0x8000_2000, count: 0x100)
    return LDR.header(flags: 0x5004, target: 0x11A0_0000, count: 0, argument: UInt32(16 + body.count)) + body
        + LDR.header(flags: 0x8004, target: 0x11A0_0000, count: 0)
}

func record(for image: [UInt8], edits: [PatchRecord.Edit] = [], blocks: [PatchRecord.Block]? = nil, status: String = "TEST") -> PatchRecord {
    PatchRecord(name: "t", status: status, description: "",
                source: .init(size: image.count, sha256: Hash.sha256(image), crc32: Hash.crc32(image)), edits: edits, blocks: blocks)
}

struct FirmwareTests {
    let base = syntheticImage()

    var images: [FirmwareImage] {
        let edited = try! Patcher.apply(base, [record(for: base, edits: [.init(what: "t", device_address: "0x80001002",
            file_offset: "0x\(String(try! LDR.offset(of: 0x8000_1002, in: LDR.parse(base)), radix: 16))", expected: "33 44", new: "aa bb")])])
        return [FirmwareImage(label: "original", title: "o", description: "", patches: [], ldr: base, reason: ""),
                FirmwareImage(label: "next", title: "n", description: "", patches: [], ldr: edited, reason: ""),
                FirmwareImage(label: "draft", title: "d", description: "", patches: [], ldr: nil, reason: "DRAFT")]
    }

    func installed(_ im: FirmwareImage) -> [String: [UInt8]] { ["os.ldr": im.ldr!, "os.crc32": im.crcText] }

    @Test func framesMatchThePythonTool() throws {
        #expect(UpdateConsole.ping == [0xC0, 1, 0, 0, 0, 0, 0])
        #expect(UpdateConsole.read["os.ldr"]! == [0xC0, 1, 0x19, 0, 0, 0, 7] + Array("os.ldr".utf8) + [0])
        // flash.py's test: len 4 + 7 + 828136 = 0x000CA2F3, size 0x000CA2E8
        #expect(try UpdateConsole.writeHeader("os.ldr", size: 828_136)
                == [0xC0, 1, 0x11, 0, 0x0C, 0xA2, 0xF3, 0, 0x0C, 0xA2, 0xE8] + Array("os.ldr".utf8) + [0])
        #expect(throws: ConsoleError.self) { try UpdateConsole.writeHeader("bootloader.ldr", size: 1) }
        #expect(Hash.crc32(Array("123456789".utf8)) == 0xCBF4_3926)
    }

    @Test func roundTripAndNewImage() throws {
        for target in ["original", "next"] {
            let fake = FakeConsole(installed(images[0]))
            let con = UpdateConsole(fake, images: images) { _ in }
            _ = try con.flash(images.first { $0.label == target }!, all: images)
            #expect(fake.files == installed(images.first { $0.label == target }!))
            #expect(Set(fake.types) == [0x00, 0x19, 0x11] && fake.forbidden.isEmpty)
        }
    }

    @Test func refusals() throws {
        let fake = FakeConsole(installed(images[0]))
        let con = UpdateConsole(fake, images: images) { _ in }
        #expect(throws: ConsoleError.self) { try con.writeFile("os.ldr", base + [0]) }
        #expect(throws: ConsoleError.self) { try con.writeFile("os.crc32", Array("1".utf8)) }
        #expect(throws: ConsoleError.self) { try con.send([0xC0, 1, 0x15, 0, 0, 0, 0]) }
        #expect(throws: ConsoleError.self) { _ = try con.flash(images[2], all: images) }
        let unknown = FakeConsole(["os.ldr": [1, 2, 3], "os.crc32": [0x31]])
        #expect(throws: ConsoleError.self) { _ = try UpdateConsole(unknown, images: images) { _ in }.flash(images[1], all: images) }
        #expect(!unknown.types.contains(0x11))
    }

    @Test func missingAnswerStopsEverything() throws {
        let big = Array(repeating: UInt8(0xC0), count: 5000)        // three pieces, every byte escaped
        let im = FirmwareImage(label: "big", title: "", description: "", patches: [], ldr: big, reason: "")
        let fake = FakeConsole([:], dropReplyAfter: 1)
        let con = UpdateConsole(fake, images: [im]) { _ in }
        #expect(throws: ConsoleError.self) { try con.writeFile("os.ldr", big) }
        #expect(con.stalled)
        let sent = fake.types.count
        #expect(throws: ConsoleError.self) { try con.send(UpdateConsole.ping) }
        #expect(fake.types.count == sent)
    }

    @Test func theBackupIsSavedBeforeAnythingIsWritten() throws {
        let fake = FakeConsole(installed(images[0]))
        var typesAtBackup: [UInt8]?
        _ = try UpdateConsole(fake, images: images) { _ in }.flash(images[1], all: images, saveBackup: { files in
            typesAtBackup = fake.types
            #expect(Dictionary(uniqueKeysWithValues: files.map { ($0.name, $0.data) }) == self.installed(self.images[0]))
        })
        #expect(typesAtBackup?.contains(0x11) == false)
        struct DiskFull: Error {}
        let untouched = FakeConsole(installed(images[0]))
        #expect(throws: DiskFull.self) {
            _ = try UpdateConsole(untouched, images: images) { _ in }.flash(images[1], all: images, saveBackup: { _ in throw DiskFull() })
        }
        #expect(!untouched.types.contains(0x11) && untouched.files == installed(images[0]))
    }

    @Test func aPortFailingMidUploadCountsAsAnOpenUpload() throws {
        let big = Array(repeating: UInt8(7), count: 5000)
        let im = FirmwareImage(label: "big", title: "", description: "", patches: [], ldr: big, reason: "")
        let fake = FakeConsole([:])
        fake.failAfterData = 1000
        let con = UpdateConsole(fake, images: [im]) { _ in }
        #expect { try con.writeFile("os.ldr", big) } throws: { if case ConsoleError.stalled = $0 { true } else { false } }
        #expect(con.stalled)
    }

    @Test func aNamedInstalledOSMayBeWrittenOver() throws {
        let start = ["os.ldr": [1, 2, 3] as [UInt8], "os.crc32": [0x31]]
        let fake = FakeConsole(start)
        _ = try UpdateConsole(fake, images: images) { _ in }.flash(images[1], all: images, name: { _, _ in "galaxz-v2 (another animation)" })
        #expect(fake.files == installed(images[1]))
        let not = FakeConsole(start)
        #expect(throws: ConsoleError.self) { _ = try UpdateConsole(not, images: images) { _ in }.flash(images[1], all: images, name: { _, _ in "unknown os.ldr" }) }
        #expect(not.files == start)
    }

    @Test func badReadBack() throws {
        let fake = FakeConsole(installed(images[0]), corruptAt: 3)
        #expect(throws: ConsoleError.self) { _ = try UpdateConsole(fake, images: images) { _ in }.flash(images[0], all: images) }
    }

    @Test func blocksAddAndUndo() throws {
        let payload = Array(0..<8 as Range<UInt8>)
        let blk = PatchRecord.Block(what: "t", target: "0x80c00000", source: "x.S", data: payload.map { String(format: "%02x", $0) }.joined(),
                                    sha256: Hash.sha256(payload))
        let rec = record(for: base, blocks: [blk])
        let out = try Patcher.apply(base, [rec])
        let b = try LDR.parse(out)
        #expect(b.count == 6 && b[4].target == 0x80C0_0000 && b[0].argument == UInt32(out.count - 16))
        #expect(Patcher.unapply(out, [rec]) == base)
        let outside = PatchRecord.Block(what: "t", target: "0x80000000", source: "", data: blk.data, sha256: blk.sha256)
        #expect(throws: PatchError.self) { try Patcher.apply(base, [record(for: base, blocks: [outside])]) }
        #expect(throws: PatchError.self) { try Patcher.apply(base, [record(for: base, blocks: [blk], status: "DRAFT")]) }
    }

    /// The app's copies of the builds and records are Firmware/'s (run Tools/sync-firmware.sh after changing them).
    @Test func bundledCatalogMatchesTheRepository() throws {
        let repo = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../../../Firmware").standardized
        let app = try #require(Catalog.bundledRoot)
        let fm = FileManager.default
        for dir in ["builds", "patches"] {
            let mine = try fm.contentsOfDirectory(atPath: repo.appending(path: dir).path).filter { $0.hasSuffix(".json") }.sorted()
            let theirs = try fm.contentsOfDirectory(atPath: app.appending(path: dir).path).filter { $0.hasSuffix(".json") }.sorted()
            #expect(mine == theirs, "run Tools/sync-firmware.sh")
            for n in mine {
                #expect(try Data(contentsOf: repo.appending(path: "\(dir)/\(n)")) == Data(contentsOf: app.appending(path: "\(dir)/\(n)")),
                        "\(dir)/\(n) drifted: run Tools/sync-firmware.sh")
            }
        }
    }

    /// With TE's os.ldr on this Mac: every build applies, and the original comes back out of each.
    @Test func realImages() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let path = home.appending(path: "Desktop/Galax-z/Firmware/dumps/2026-11-21/os.ldr")
        guard let data = try? Data(contentsOf: path) else { return }
        let original = [UInt8](data), catalog = try Catalog.bundled()
        let images = try catalog.images(original: original)
        for im in images {
            guard let ldr = im.ldr else {
                #expect(im.reason.contains("DRAFT"), "\(im.label): \(im.reason)")   // only a DRAFT may not build
                continue
            }
            #expect(catalog.recoverOriginal(from: ldr) == original)
        }
        #expect(Hash.sha256(images.first { $0.label == "galaxz-v1" }!.ldr!)
                == "e6cce58145ae87d9fd3cd83bb2b65923ff24d536b8eccd18663dad17dcd1526a")   // what flash.py built and flashed
        #expect(Hash.sha256(images.first { $0.label == "led-walker" }!.ldr!)
                == "77d9520ff5ca429b61bdfbec47c58fb0e55d78941de31e7905e74369db83ec20")
    }
}

struct AnimationTests {
    @Test func everyAnimationFitsThePlayerAndEndsDark() throws {
        let layout = try LEDLayout.bundled()
        #expect(layout.points.count == 51)
        for a in LEDAnimation.library {
            let frames = a.frames(layout)
            #expect(frames.count == LEDAnimation.frameCount && frames.allSatisfy { $0.count == 53 }, "\(a.id)")
            #expect(frames.last!.allSatisfy { $0 == .zero }, "\(a.id) must end dark")
            if !a.isTest {   // an even, clean fade: in the last stretch the whole only gets darker, frame by frame
                let light = frames.suffix(20).map { $0.reduce(0.0) { $0 + $1[0] + $1[1] + $1[2] + $1[3] } }
                #expect(light.last == 0 && light.first! >= light[10], "\(a.id)")
            }
            #expect(a.bytes(layout).count == LEDAnimation.frameCount * 53 * 4)
            #expect(frames.dropLast().contains { $0.contains { $0 != .zero } }, "\(a.id) shows something")
        }
        #expect(Set(LEDAnimation.library.map(\.id)).count == LEDAnimation.library.count)
    }

    /// The two lower rows are white only (W, no R G B); the top row and the encoders keep colour; TRACK's guess has both.
    @Test func colourOnlyWhereTheLEDsHaveIt() throws {
        let layout = try LEDLayout.bundled()
        for a in LEDAnimation.library {
            let frames = a.frames(layout)
            for i in 0..<LEDLayout.ledCount where !LEDAnimation.rgb.contains(i) && i != LEDAnimation.trackGuess {
                #expect(frames.allSatisfy { $0[i][0] == 0 && $0[i][1] == 0 && $0[i][2] == 0 }, "\(a.id) LED \(i)")
            }
            #expect((16...39).contains { i in frames.contains { $0[i][3] > 0.3 } } || a.id == "keycheck", "\(a.id): the white bed plays")
            let coloured = LEDAnimation.rgb.contains { i in frames.contains { abs($0[i][0] - $0[i][2]) > 0.1 || abs($0[i][1] - $0[i][0]) > 0.1 } }
            #expect(coloured == (a.id != "keycheck"), "\(a.id)")
        }
        let track = LEDAnimation.shown(.init(level: 1, tone: 0), LEDStyle(0x0000FF, 0, 0), led: 44)
        #expect(track == RGBW(0, 0, 1, 1))
    }

    /// Full or off: while an animation plays nearly every LED is one or the other, and there is always some of both.
    @Test func highContrast() throws {
        let layout = try LEDLayout.bundled()
        for a in LEDAnimation.library where !a.isTest {
            let frames = a.frames(layout), playing = frames[30..<Int(LEDAnimation.fadeFrom * 239)]
            let levels = playing.flatMap { f in layout.points.keys.map { f[$0].max() } }
            let extreme = Double(levels.filter { $0 < 0.1 || $0 > 0.9 }.count) / Double(levels.count)
            let lit = Double(levels.filter { $0 > 0.5 }.count) / Double(levels.count)
            #expect(extreme > 0.75, "\(a.id): \(extreme) full or off")
            #expect(lit > 0.05 && lit < 0.75, "\(a.id): \(lit) lit")
        }
    }

    @Test func everyPatternTakesEveryStyle() throws {
        let layout = try LEDLayout.bundled(), rgb = LEDAnimation.rgb
        func sum(_ a: LEDAnimation, _ leds: some Sequence<Int>, _ ch: Range<Int>) -> Double {
            let f = a.frames(layout); return leds.reduce(0) { t, i in t + f.reduce(0) { x, fr in x + ch.reduce(0) { $0 + fr[i][$1] } } }
        }
        for p in LEDPattern.all where !p.isTest {
            var a = LEDAnimation(id: "t", name: "t", pattern: p.id, style: LEDStyle(0x00FF00, 0x00FF00, 0x00FF00))
            #expect(sum(a, rgb, 1..<2) > 0 && sum(a, rgb, 0..<1) == 0 && sum(a, rgb, 2..<4) == 0, "\(p.id): only the style's colour")
            let full = sum(a, rgb, 1..<2), bed = sum(a, 16...39, 3..<4)
            a.style.colorOpacity = 0.5
            #expect(abs(sum(a, rgb, 1..<2) - full / 2) < 1e-6 && abs(sum(a, 16...39, 3..<4) - bed) < 1e-6, "\(p.id): the layers are separate")
            a.style.bedOpacity = 0
            #expect(sum(a, 16...39, 0..<4) == 0, "\(p.id): the bed off")
            a.style = LEDStyle(0x00FF00, 0x00FF00, 0x00FF00, mono: true)
            #expect(sum(a, 0..<53, 0..<3) == 0 && sum(a, rgb, 3..<4) > 0, "\(p.id): black and white")
            #expect(a.bytes(layout).count == 50_880)
        }
        let mine = LEDAnimation(id: "my-1", name: "Mine", pattern: "pulse", style: LEDStyle(1, 2, 3, mono: true, colorOpacity: 0.4, bedOpacity: 0.2))
        #expect(try JSONDecoder().decode(LEDAnimation.self, from: JSONEncoder().encode(mine)) == mine)
        let gone = LEDAnimation(id: "x", name: "x", pattern: "no such pattern", style: mine.style)
        #expect(gone.bytes(layout).allSatisfy { $0 == 0 })                // an unknown pattern is dark, never a crash
    }

    /// The keyboard's LEDs are where the OS's own 24-key table (0x8111312c, F to E) says, left to right.
    @Test func theKeyboardIsInOrder() throws {
        let p = try LEDLayout.bundled().points
        let keys = [16, 30, 17, 31, 18, 32, 19, 20, 33, 21, 34, 22, 23, 35, 24, 36, 25, 37, 26, 27, 38, 28, 39, 29]
        #expect(zip(keys, keys.dropFirst()).allSatisfy { p[$0]!.x < p[$1]!.x })
        #expect((16...29).allSatisfy { p[$0]!.y > 0.9 } && (30...39).allSatisfy { abs(p[$0]!.y - 0.66) < 0.06 })
        let home = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop/Galax-z/Firmware/dumps/2026-11-21/os.ldr")
        guard let data = try? Data(contentsOf: home) else { return }
        let d = [UInt8](data), at = try LDR.offset(of: 0x8111_312C, in: LDR.parse(d))
        #expect((0..<24).map { Int(LDR.u32(d, at + 4 * $0)) } == keys)
    }

    /// Galax-z v3 (the A/B bars) plays any animation too, and is told from v2.
    @Test func animationsOnTheABBars() throws {
        let path = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop/Galax-z/Firmware/dumps/2026-11-21/os.ldr")
        guard let data = try? Data(contentsOf: path) else { return }
        let original = [UInt8](data), catalog = try Catalog.bundled(), layout = try LEDLayout.bundled()
        let images = try catalog.images(original: original)
        let v3 = try #require(images.first { $0.label == "galaxz-v3" }?.ldr), v2 = try #require(images.first { $0.label == "galaxz-v2" }?.ldr)
        let blocks = try LDR.parse(v3)
        #expect(Array(v3[0x80122..<0x80126]) == [0x58, 0xE3, 0x43, 0xAB] && blocks.contains { $0.target == 0x80C2_0000 && $0.count == 172 })
        #expect(Array(v2[0x80122..<0x80126]) == [0xF9, 0xE3, 0xA7, 0x8E])
        let pulse = try #require(LEDAnimation.library.first { $0.id == "pulse" })
        let v4 = try #require(images.first { $0.label == "galaxz-v4" }?.ldr)      // and the tumbler
        let v5 = try #require(images.first { $0.label == "galaxz-v5" }?.ldr)      // and EUCLID
        let v6 = try #require(images.first { $0.label == "galaxz-v6" }?.ldr)      // and older USB keyboards
        let v7 = try #require(images.first { $0.label == "galaxz-v7" }?.ldr)      // and their pedal and wheel, presets that stay
        let v8 = try #require(images.first { $0.label == "galaxz-v8" }?.ldr)      // and the load meter
        let v9 = try #require(images.first { $0.label == "galaxz-v9" }?.ldr)      // and more voices played live
        let v10 = try #require(images.first { $0.label == "galaxz-v10" }?.ldr)    // and the app is told of the tumbler and EUCLID
        let v11 = try #require(images.first { $0.label == "galaxz-v11" }?.ldr), still = try #require(images.first { $0.label == "galaxz-v11-quiet" }?.ldr)   // the red page, and its chime
        let v12 = try #require(images.first { $0.label == "galaxz-v12" }?.ldr), silent = try #require(images.first { $0.label == "galaxz-v12-quiet" }?.ldr)     // in place of TE's start sound; no start sound
        let v13 = try #require(images.first { $0.label == "galaxz-v13" }?.ldr)    // GROOVE light green
        let v14 = try #require(images.first { $0.label == "galaxz-v14" }?.ldr), hush = try #require(images.first { $0.label == "galaxz-v14-quiet" }?.ldr)     // SCREEN + the blue dial
        #expect(Hash.sha256(v14).hasPrefix("77e8e2cbed6bc305") && Hash.sha256(hush).hasPrefix("071fa295cf3efc11"))      // as Firmware/tools/patch.py builds them
        #expect(Hash.sha256(v12).hasPrefix("f32249ea0f706d56"))                   // v12 as it is on the unit
        #expect(Hash.sha256(v11).hasPrefix("b72c870828449255") && v12.count - silent.count == 16 + 604)       // v11 as it is on the unit
        #expect(v11.count - still.count == 16 + 576 && Hash.sha256(v10).hasPrefix("84cfd798a2fd2dce"))
        #expect(Hash.sha256(v9).hasPrefix("3dc41875e5d60f33") && v10.count - v9.count == 16 + 1448)
        for (base, built) in [("galaxz-v2", v2), ("galaxz-v3", v3), ("galaxz-v4", v4), ("galaxz-v5", v5), ("galaxz-v6", v6), ("galaxz-v7", v7), ("galaxz-v8", v8), ("galaxz-v9", v9), ("galaxz-v10", v10), ("galaxz-v11", v11), ("galaxz-v11-quiet", still), ("galaxz-v12", v12), ("galaxz-v12-quiet", silent), ("galaxz-v13", v13), ("galaxz-v14", v14), ("galaxz-v14-quiet", hush)] {
            #expect(try catalog.bootImage(original: original, .galaxy, layout: layout, on: base).ldr == built)
            let im = try catalog.bootImage(original: original, pulse, layout: layout, on: base)
            #expect(im.label == "\(base.dropFirst(7))-pulse" && catalog.underPlayer(im.ldr!)?.label == base)
            #expect(catalog.recoverOriginal(from: im.ldr!) == original && catalog.frames(playedBy: im.ldr!) == pulse.bytes(layout))
            #expect(catalog.name(images, ldr: im.ldr!, crc: nil) == "\(base) (another animation)")
        }
        // the first A/B bars (blue / purple), as they were flashed: known, and TE's original comes back out; never written
        let ab = try #require(catalog.records["ab-bars.json"]), was = try #require(ab.earlier?.first)
        let older = try Patcher.apply(original, [try catalog.record("debounce.json"), try catalog.record("galaxy-boot.json"), ab.versions[1]])
        #expect(try Patcher.bytes(was.data).count == 180 && Hash.sha256(Patcher.bytes(was.data)) == was.sha256)
        #expect(catalog.underPlayer(older)?.label == "galaxz-v3" && catalog.underPlayer(older)?.original == original)
        #expect(!images.contains { $0.ldr == older })
        // the tumbler before recording, as it was flashed: known, recovered, never written
        let tumbler = try #require(catalog.records["tumbler.json"])
        let first = try Patcher.apply(original, try ["debounce.json", "galaxy-boot.json", "ab-bars.json"].map(catalog.record) + [tumbler.versions[1]])
        #expect(Hash.sha256(first) == "80dd4b9b8322ec8cefc79dc845a52c04e0dacd8e0f5fdfedd3d7eb64c15e0d73")
        #expect(catalog.underPlayer(first)?.label == "galaxz-v4" && catalog.recoverOriginal(from: first) == original && !images.contains { $0.ldr == first })
        var bad = v3; bad[try #require(blocks.first { $0.target == 0x80C2_0000 }).dataOffset] ^= 1
        #expect(catalog.underPlayer(bad) == nil)                              // one byte of the A/B code off: not ours
    }

    @Test func theKeyCheckCountsSevenKeys() throws {
        let frames = LEDAnimation.keyCheck.frames(try LEDLayout.bundled())
        for n in 0..<7 {
            let f = frames[n * 34 + 17]
            #expect((44...50).filter { f[$0][3] > 0 } == [44 + n] && (0...15).filter { f[$0][3] > 0 }.count == n + 1)
        }
    }

    /// Galax-z v2 with frames this app does not have is recognised; one byte of code, or of TE's OS, off and it is not.
    @Test func anotherAnimationIsRecognisedAndNothingElse() throws {
        let path = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop/Galax-z/Firmware/dumps/2026-11-21/os.ldr")
        guard let data = try? Data(contentsOf: path) else { return }
        let original = [UInt8](data), catalog = try Catalog.bundled(), layout = try LEDLayout.bundled()
        let v2 = try catalog.bootImage(original: original, .galaxy, layout: layout).ldr!
        let images = try catalog.images(original: original)
        let b = try #require(try LDR.parse(v2).last { $0.target == 0x80C1_0000 })
        func changed(_ at: Int) -> [UInt8] { var d = v2; d[at] ^= 1; return d }
        let frames = changed(b.dataOffset + Int(b.count) - 9)
        #expect(catalog.originalUnderPlayer(frames) == original)
        #expect(catalog.recoverOriginal(from: frames) == original)
        #expect(catalog.name(images, ldr: frames, crc: nil) == "galaxz-v2 (another animation)")
        for at in [b.dataOffset + 4, b.headerOffset + 4, 0x1000, 0x80186, 0x82DB0, v2.count - 4] {
            #expect(catalog.originalUnderPlayer(changed(at)) == nil, "byte \(at)")
            #expect(catalog.name(images, ldr: changed(at), crc: nil).hasPrefix("unknown"))
        }
        // what the OP-Z really held: the hub's last backups
        let runs = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Documents/Backups/os")
        for run in (try? FileManager.default.contentsOfDirectory(at: runs, includingPropertiesForKeys: nil)) ?? [] {
            if let d = try? Data(contentsOf: run.appending(path: "installed-os.ldr")), [v2.count, 879_408].contains(d.count) {
                #expect(catalog.originalUnderPlayer([UInt8](d)) == original, "\(run.lastPathComponent)")
            }
        }
    }

    /// The firmware record's frames are the library's Galaxy: the hub's v2-galaxy is the catalog's galaxz-v2, byte for byte;
    /// every other animation changes only the frames, and TE's original comes back out of each.
    @Test func libraryImagesOnTheRealImage() throws {
        let path = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop/Galax-z/Firmware/dumps/2026-11-21/os.ldr")
        guard let data = try? Data(contentsOf: path) else { return }
        let original = [UInt8](data), catalog = try Catalog.bundled(), layout = try LEDLayout.bundled()
        let v2 = try #require(try catalog.images(original: original).first { $0.label == "galaxz-v2" }?.ldr)
        #expect(try catalog.bootImage(original: original, .galaxy, layout: layout).ldr == v2,
                "run galaxz-frames galaxy + asm.py: the record's frames drifted from the library")
        for a in LEDAnimation.library {
            let im = try catalog.bootImage(original: original, a, layout: layout)
            #expect(im.ldr!.count == v2.count)
            #expect(catalog.recoverOriginal(from: im.ldr!) == original, "\(a.id)")
            #expect(catalog.frames(playedBy: im.ldr!) == a.bytes(layout), "\(a.id)")
        }
    }
}
