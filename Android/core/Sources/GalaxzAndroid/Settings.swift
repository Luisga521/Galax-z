import DotKit
import Foundation
import OPZLink
import OPZModel
import OPZPlay
import OPZStage

/// What Settings and the key test read and do, for the Kotlin screens: JSON out, a word and an argument in.
extension Core {
    func query(_ what: String) -> String {
        let parts = what.split(separator: ":").map(String.init)
        let any: Any
        switch parts.first {
        case "general": any = general
        case "keytest": any = keyTestState
        case "learn": any = learnState(family: Int(parts.count > 1 ? parts[1] : "") ?? 0, track: parts.count > 2 ? Int(parts[2]) : nil)
        default: any = [:] as [String: Any]
        }
        guard let d = try? JSONSerialization.data(withJSONObject: any), let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }

    /// Returns a word for the Kotlin side when there is one (a file's path, why not).
    func command(_ what: String, _ arg: String) -> String {
        defer { changed = true }
        switch what {
        case "demo": useDemo(arg == "1")
        case "autoBackup":
            autoBackup = arg == "1"
            try? Data(arg.utf8).write(to: folder.appendingPathComponent("autoBackup.json"), options: .atomic)
            if autoBackup { refreshNow() }
        case "backUpNow": backUpNow()
        case "backups": backups = URL(fileURLWithPath: arg)
        case "saveCheck": return saveCheck(in: URL(fileURLWithPath: arg))
        case "keyTestOpen": openKeyTest()
        case "keyTestClose": closeKeyTest()
        case "keyTestReset": keyTest.reset()
        case "keyTestWindow": keyTest.window = min(0.08, max(0.01, ((keyTest.window + (Double(arg) ?? 0)) * 200).rounded() / 200))
        case "controllers": controllers.devices = arg.isEmpty ? [] : arg.components(separatedBy: "\n").sorted()
        case "learn":
            let n = arg.split(separator: ",", omittingEmptySubsequences: false).map { Int($0) }
            guard n.count == 3, let f = n[0], let i = n[2] else { break }
            let t = Controllers.targets(f, track: n[1])
            if t.indices.contains(i) { controllers.learn(t[i]) }
        case "learnOff": controllers.learn(nil)
        case "forget": if let i = Int(arg), controllers.learned.entries.indices.contains(i) { controllers.forget(controllers.learned.entries[i].control) }
        case "forgetAll": controllers.forgetAll()
        case "way":
            let n = arg.split(separator: ",")
            if n.count == 2, let i = Int(n[0]), controllers.learned.entries.indices.contains(i) {
                controllers.set(n[1] == "relative" ? .relative : .absolute, for: controllers.learned.entries[i].control)
            }
        default: break
        }
        return ""
    }

    // MARK: GENERAL

    private var general: [String: Any] {
        var g: [String: Any] = [
            "demo": source == .demo,
            "connected": device != nil,
            "over": source == .demo ? "DEMO" : device?.bluetooth == true ? "BLUETOOTH" : device != nil ? "USB" : "",
            "device": device?.name ?? "",
            "autoBackup": autoBackup,
        ]
        switch backup {
        case .idle: g["backup"] = ""
        case .running(let n): g["backup"] = "NOW: project \(n + 1) of 10…"; g["running"] = true
        case .saved: g["backup"] = ""
        case .failed(let why): g["backup"] = "LAST TRY FAILED: \(why)"
        }
        if let root = backups {
            let all = Backups.all(root)
            g["looked"] = true
            if let m = all.first?.1 { g["newest"] = m.taken.timeIntervalSince1970 * 1000; g["checked"] = m.checked.timeIntervalSince1970 * 1000; g["kept"] = all.count }
        }
        let on = source == .demo || device != nil
        g["check"] = [
            "on": on,
            "missing": check.missing.count,
            "items": LinkCheck.Item.allCases.map { ["name": $0.name, "count": check.count($0), "how": $0.how, "optional": $0.optional] as [String: Any] },
        ] as [String: Any]
        return g
    }

    private func refreshNow() { tick() }

    /// The link check as a file to share: `Diagnostics/link-<time>.txt`.
    private func saveCheck(in dir: URL) -> String {
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd-HHmmss"
            let url = dir.appendingPathComponent("link-\(f.string(from: Date())).txt")
            let text = check.text(device: device?.name ?? (source == .demo ? "demo" : "no OP-Z"),
                                  over: source == .demo ? "demo" : device?.bluetooth == true ? "Bluetooth" : "USB",
                                  seconds: now - checkStart, banksRead: client.bankRevision, refetches: client.refetches,
                                  also: ["Galax-z for Android", "showing \(stage.page.name) track \(stage.track + 1)"],
                                  tracks: (client.midi?.lines ?? ["MIDI settings: not answered"]) + stage.report)
            try Data(text.utf8).write(to: url, options: .atomic)
            return url.path
        } catch { return "!" + error.localizedDescription }
    }

    // MARK: KEY TEST

    private var keyTestState: [String: Any] {
        let t = keyTest
        func ms(_ s: Double) -> Int { Int((s * 1000).rounded()) }
        var k: [String: Any] = [
            "presses": t.presses, "doubles": t.doubles, "bouncing": t.keysWithDoubles.count,
            "window": ms(t.window), "firstNote": t.firstNote, "ignored": t.ignored,
            "demo": source == .demo, "device": device?.name ?? "", "over": device?.bluetooth == true ? "BLUETOOTH" : "USB",
            "playing": opzPlaying, "report": t.report,
        ]
        if let f = t.fastest { k["fastest"] = ms(f) }
        if let c = t.channel { k["channel"] = c }
        k["keys"] = (0..<KeyTest.keys).map { i -> [String: Any] in
            let note = t.note(ofKey: i), key = t.byNote[note]
            return ["note": note, "name": KeyTest.name(note), "presses": key?.presses ?? 0, "doubles": key?.doubles(window: t.window) ?? 0]
        }
        k["log"] = t.log.prefix(24).map { p -> [String: Any] in
            var e: [String: Any] = ["name": KeyTest.name(p.note), "double": t.isDouble(p)]
            if let g = p.gap { e["gap"] = ms(g) }
            if let h = p.heldBefore { e["held"] = ms(h) }
            return e
        }
        return k
    }

    // MARK: LEARN

    private func learnState(family: Int, track: Int?) -> [String: Any] {
        let l = controllers.learned
        return [
            "devices": controllers.devices,
            "waiting": l.waiting.map { "Move or press what should be \($0.name). Touch it again to leave it." } ?? "",
            "last": controllers.last ?? "",
            "targets": Controllers.targets(family, track: track).map { t -> [String: Any] in
                let has = l.controls(of: t)
                return ["name": t.name, "on": l.waiting == t, "learned": has.first.map { "\($0.device) \($0.name)" } ?? ""]
            },
            "entries": l.entries.map { e -> [String: Any] in
                ["target": e.target.name, "control": "\(e.control.device) · \(e.control.name)",
                 "ways": e.target.continuous && e.control.kind == .cc, "relative": e.way == .relative]
            },
            "tracks": OPZ.trackNames.map { $0.uppercased() },
        ]
    }
}

/// The matrix's type, for the Kotlin screens: [width, height, then 1 for each lit dot, row by row].
func dotText(_ s: String, font: Int) -> [Int32] {
    let f = [DotFont.tiny, .small, .big, .huge][max(0, min(3, font))]
    let text = s.uppercased(), w = max(1, f.width(text))
    let c = DotCanvas(width: w, height: f.height)
    _ = c.text(text, 0, 0, DotColor(255, 255, 255), font: f)
    var out: [Int32] = [Int32(w), Int32(f.height)]
    for y in 0..<f.height { for x in 0..<w { out.append(c[x, y].r > 100 ? 1 : 0) } }
    return out
}
