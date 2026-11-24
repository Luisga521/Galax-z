#if os(Windows)
import Foundation
import GalaxzAndroid
import GalaxzDesktop
import OPZFirmware
import WinSDK

/// Everything that is not the OP-Z's screen, over it, as the Mac's Settings sheet (`App/SettingsScreen.swift`): GENERAL (the
/// look, the demo, backups, the key test, the link check, credits) and GALAX-Z OS (`App/HubScreen.swift`: the installer, every
/// version, boot animations and their editor).
final class SettingsPanel {
    enum Tab: Int { case general, os }

    unowned let app: App
    let ui = Ui()
    var tab: Tab
    private var keyTest = false
    /// PAIR AN OP-Z (the Mac's `BluetoothPairing`), over GENERAL.
    private var pairPage = false
    private var showAll = false, showLog = false
    /// The animation being edited (`AnimationEditor`), and the box its name is typed in.
    private var editing: LEDAnimation?
    /// Where the library was scrolled to: back there when the editor closes.
    private var scrollBeforeEditor: Int32 = 0
    private var nameBox: HWND?
    private var nameFont: HFONT?
    /// Saved link check, its file.
    private var savedCheck: String?
    private var general: [String: Any] = [:]
    private var generalAt = -1.0
    private var custom = [COLORREF](repeating: 0x0D0C0C, count: 16)

    init(app: App, tab: Tab) {
        self.app = app
        self.tab = tab
    }

    var hub: Hub { app.hub }
    var core: DesktopCore { app.core }
    var busy: Bool { hub.busy != nil }

    /// Esc: out of the editor or the key test, then out of Settings (not while the OP-Z is being written).
    func escape() -> Bool {
        if editing != nil { closeEditor(); return false }
        if keyTest { closeKeyTest(); return false }
        if pairPage { return true }                  // PAIR is a page of its own: Esc leaves Settings, as DONE does
        return !busy
    }

    func closing() {
        closeEditor()
        if keyTest { closeKeyTest() }
        closePairing()
    }

    func openPairing() {
        if keyTest { closeKeyTest() }
        tab = .general
        pairPage = true
        ui.scroll = 0
        app.midi.bluetooth.scan(true)
    }

    private func closePairing() {
        guard pairPage else { return }
        pairPage = false
        app.midi.bluetooth.scan(false)
        ui.scroll = 0
    }

    // MARK: the frame

    /// Lay the screen out from the app's state, taking the click if there was one. What is to run once it is painted.
    func layout(width: Int32, height: Int32, scale: Double) -> [() -> Void] {
        ui.rescale(scale)
        ui.size = (width, height)
        ui.begin()
        let now = ProcessInfo.processInfo.systemUptime
        if now - generalAt > 0.5 { general = Self.json(core.query("general")); generalAt = now }
        let bar = ui.px(64)
        ui.contentTop = bar
        let maxW = ui.px(tab == .os || editing != nil ? 1180 : 860)
        let w = min(width - ui.px(52), maxW), x = (width - w) / 2
        var y = bar + ui.px(14) - ui.scroll
        let top = y
        if editing != nil { y += editor(x, w, y) }
        else if keyTest { y += keyTestPage(x, w, y) }
        else if pairPage { y += pairingPage(x, w, y) }
        else if tab == .general { y += generalPage(x, w, y) }
        else { y += hubPage(x, w, y) }
        ui.contentHeight = y - top + ui.px(40)
        if ui.scroll > max(0, ui.contentHeight - (height - bar)) { ui.scroll = max(0, ui.contentHeight - (height - bar)) }
        topBar(width, bar)
        placeNameBox()
        return ui.end()
    }

    private func topBar(_ width: Int32, _ h: Int32) {
        ui.fill(RECT(left: 0, top: 0, right: width, bottom: h), Ink.background)
        ui.fill(RECT(left: 0, top: h - 1, right: width, bottom: h), Ink.mix(Ink.ink, 0.1))
        let x = ui.px(26), dy = (h - ui.dotHeight(font: 2, dot: 1.8)) / 2
        var at = x
        if width > ui.px(760) { at += ui.dotText("SETTINGS", x, dy, font: 2, dot: 1.8) + ui.px(22) }
        let done = ui.buttonWidth("DONE")
        let segW = min(ui.px(420), width - at - done - ui.px(60))
        if let t = ui.segmented("tab", ["GENERAL", "GALAX-Z OS"], tab.rawValue, at, (h - ui.px(30)) / 2, width: segW, enabled: !busy && editing == nil, fixed: true) {
            if keyTest { closeKeyTest() }
            closePairing()
            tab = Tab(rawValue: t) ?? .general
            ui.scroll = 0
        }
        if ui.button("DONE", width - x - done, (h - ui.buttonHeight) / 2, fill: Ink.yellow, enabled: !busy, fixed: true) {
            ui.defer_ { [weak app] in app?.closeSettings() }
        }
    }

    // MARK: pieces

    private func card(_ x: Int32, _ w: Int32, _ y: Int32, stroke: UInt32? = nil, fill: UInt32 = Ink.panel, _ body: (Int32, Int32, Int32) -> Int32) -> Int32 {
        let mark = ui.mark, pad = ui.px(18)
        let h = body(x + pad, w - pad * 2, y + pad) + pad * 2
        ui.card(from: mark, RECT(left: x, top: y, right: x + w, bottom: y + h), fill, stroke: stroke)
        return h
    }

    private func section(_ s: String, _ x: Int32, _ y: Int32) -> Int32 {
        ui.dotText(s, x, y + ui.px(8), font: 0, dot: 2, Ink.yellow)
        return ui.px(8) + ui.dotHeight(font: 0, dot: 2) + ui.px(12)
    }

    /// A title and its words on the left, controls on the right (`width` of them), in a card.
    private func row(_ title: String, _ detail: String, _ x: Int32, _ w: Int32, _ y: Int32, controls width: Int32,
                     _ controls: (Int32, Int32) -> Int32) -> Int32 {
        card(x, w, y) { ix, iw, iy in
            let tw = iw - width - ui.px(16)
            var h = ui.text(title, ix, iy, width: tw, ui.font(13, bold: true))
            h += ui.px(5)
            h += ui.text(detail, ix, iy + h, width: tw, ui.font(11), alpha: 0.55)
            let ch = controls(ix + iw - width, iy)
            return max(h, ch)
        }
    }

    private func warning(_ s: String, _ x: Int32, _ w: Int32, _ y: Int32) -> Int32 {
        card(x, w, y, fill: Ink.mix(Ink.red, 0.12)) { ix, iw, iy in
            ui.dotText("!", ix, iy, font: 1, dot: 2.2, Ink.red)
            return max(ui.dotHeight(font: 1, dot: 2.2), ui.text(s, ix + ui.px(28), iy, width: iw - ui.px(28), ui.font(11)))
        }
    }

    private func badge(_ s: String, _ c: UInt32, _ x: Int32, _ y: Int32) -> Int32 {
        let tw = Int32(Double(ui.dotHeight(font: 0, dot: 1.6)))
        let w = ui.dotText(s, x + ui.px(7), y + ui.px(5), font: 0, dot: 1.6, c) + ui.px(14)
        ui.stroke(RECT(left: x, top: y, right: x + w, bottom: y + tw + ui.px(10)), Ink.mix(c, 0.7, over: Ink.panel), corner: 5)
        return w
    }

    // MARK: GENERAL

    private func generalPage(_ x: Int32, _ w: Int32, _ y0: Int32) -> Int32 {
        var y = y0
        let gap = ui.px(14)
        y += section("SCREEN", x, y)
        y += card(x, w, y) { ix, iw, iy in
            var h: Int32 = 0
            ui.line("DOTS", RECT(left: ix, top: iy, right: ix + iw, bottom: iy + ui.px(14)), ui.font(9), alpha: 0.5)
            h += ui.px(20)
            let look = app.look
            let choices = [190, 240, 300]
            if let i = ui.segmented("fineness", ["BOLD", "CLASSIC", "FINE"], choices.firstIndex(of: look.fineness) ?? 1, ix, iy + h, width: iw) {
                app.setLook(fineness: choices[i])
            }
            h += ui.px(42)
            for (name, value, set) in [("GLOW", look.glow, { (v: Double) in self.app.setLook(glow: v) }),
                                       ("AFTERGLOW", look.afterglow, { (v: Double) in self.app.setLook(afterglow: v) })] {
                ui.line(name, RECT(left: ix, top: iy + h, right: ix + ui.px(100), bottom: iy + h + ui.px(22)), ui.font(9), alpha: 0.5)
                let v = ui.slider(name, value, 0...1.5, ix + ui.px(110), iy + h, width: iw - ui.px(110))
                if v != value { set(v) }
                h += ui.px(32)
            }
            ui.line("FULL SCREEN", RECT(left: ix, top: iy + h, right: ix + ui.px(200), bottom: iy + h + ui.px(24)), ui.font(9), alpha: 0.5)
            if let v = ui.toggle("fullScreen", app.isFullScreen, ix + ui.px(110), iy + h) { ui.defer_ { [weak app] in app?.fullScreen(v) } }
            ui.line("F11 OR ALT+ENTER · ESC LEAVES IT", RECT(left: ix + ui.px(170), top: iy + h, right: ix + iw, bottom: iy + h + ui.px(24)), ui.font(9), alpha: 0.4)
            h += ui.px(36)
            h += ui.text("FRAMES: UP TO \(app.hz) A SECOND, AS FAST AS THIS MONITOR SHOWS THEM", ix, iy + h, width: iw, ui.font(9), alpha: 0.45)
            return h
        }
        y += gap
        y += section("OP-Z", x, y)
        let demo = general["demo"] as? Bool ?? false
        y += row("DEMO OP-Z", "A pretend OP-Z playing a song: every screen works with no unit attached.", x, w, y, controls: ui.toggleWidth) { cx, cy in
            if let v = ui.toggle("demo", demo, cx, cy) { core.command("demo", v ? "1" : "0"); generalAt = -1 }
            return ui.px(24)
        }
        y += gap
        let bt = app.midi.bluetooth
        let btLine = bt.connectedName.map { "Connected over Bluetooth: \($0)." }
            ?? (bt.radio == 0 ? "This computer has no Bluetooth: use a USB-C cable." : "Pair your OP-Z once; Galax-z connects to it by itself when no cable is in.")
        y += row("BLUETOOTH", btLine, x, w, y, controls: ui.buttonWidth("PAIR")) { cx, cy in
            if ui.button("PAIR", id: "openPair", cx, cy, enabled: bt.radio != 0) { ui.defer_ { [weak self] in self?.openPairing() } }
            return ui.buttonHeight
        }
        y += gap
        y += backupsRow(x, w, y)
        y += gap
        y += row("KEY TEST", "Finds keys that double-trigger: every press timed from its MIDI note.", x, w, y, controls: ui.buttonWidth("OPEN")) { cx, cy in
            if ui.button("OPEN", id: "keytest", cx, cy) { openKeyTest() }
            return ui.buttonHeight
        }
        y += gap
        y += linkCheck(x, w, y)
        y += gap
        y += row("LOOK FOR NEW VERSIONS", "Asks GitHub for the list of releases when the app opens. Nothing about you or your OP-Z is sent.",
                 x, w, y, controls: ui.toggleWidth) { cx, cy in
            if let v = ui.toggle("look", app.prefs[\.lookForReleases], cx, cy) { app.prefs[\.lookForReleases] = v }
            return ui.px(24)
        }
        y += gap
        y += section("KEYS", x, y)
        y += ui.text("1–0 pages · ← → turn · ↑ ↓ track · D demo · H Galax-z OS · Ctrl+, settings · F11 full screen · Esc back",
                     x, y, width: w, ui.font(11), alpha: 0.55)
        y += gap
        y += section("CREDITS", x, y)
        y += card(x, w, y) { ix, iw, iy in
            let by = App.byline
            var h = ui.text(by.isEmpty ? "CREDITS AND LICENCES" : "GALAX-Z · \(by.uppercased())", ix, iy, width: iw, ui.font(13, bold: true))
            h += ui.px(6)
            h += ui.text("Galax-z is open source (LICENSE). It is built on op-free's engine catalogue and protocol notes, swift-crypto and Swift's "
                         + "runtime: their notices are in THIRD_PARTY.md, beside the program.", ix, iy + h, width: iw, ui.font(11), alpha: 0.6)
            h += ui.px(12)
            var bx = ix
            for (label, file) in [("LICENCES", "THIRD_PARTY.md"), ("LICENSE", "LICENSE"), ("DISCLAIMER", "DISCLAIMER.md")] {
                if ui.button(label, id: "file-\(file)", bx, iy + h) { app.show(App.besideProgram(file)) }
                bx += ui.buttonWidth(label) + ui.px(10)
            }
            return h + ui.buttonHeight
        }
        y += ui.px(16)
        y += ui.text("Galax-z is not affiliated with teenage engineering. OP-Z is their trademark. Galax-z OS is installed at your own risk.",
                     x, y, width: w, ui.font(10), alpha: 0.35)
        return y - y0
    }

    private var backingUp: Bool { general["running"] as? Bool ?? false }

    private func backupsRow(_ x: Int32, _ w: Int32, _ y: Int32) -> Int32 {
        var line = "Copies the OP-Z's 10 projects and sound settings, reading only: seconds by cable. In Documents › Galax-z › Backups, "
            + "laid out like the OP-Z's disk: put one back in content mode (hold TRACK while switching on)."
        if let s = general["backup"] as? String, !s.isEmpty { line += "\n" + s }
        if let newest = general["newest"] as? Double {
            let checked = general["checked"] as? Double ?? newest
            line += "\nNEWEST: \(Self.when(newest, date: true)) · STILL MATCHED \(Self.when(checked, date: false)) · \(general["kept"] as? Int ?? 1) KEPT"
        } else if general["looked"] as? Bool == true {
            line += "\nNONE YET ON THIS COMPUTER."
        }
        let now = backingUp ? "BACKING UP…" : "BACK UP NOW"
        let cw = max(ui.buttonWidth("BACKING UP…"), ui.buttonWidth("SHOW FOLDER"),
                     ui.measure("AUTOMATIC", ui.font(9)).cx + ui.px(12) + ui.toggleWidth)
        return row("BACKUPS", line, x, w, y, controls: cw) { cx, cy in
            var h: Int32 = 0
            ui.line("AUTOMATIC", RECT(left: cx, top: cy, right: cx + cw - ui.toggleWidth - ui.px(8), bottom: cy + ui.px(24)), ui.font(9), alpha: 0.45, align: 2)
            if let v = ui.toggle("auto", general["autoBackup"] as? Bool ?? false, cx + cw - ui.toggleWidth, cy) { core.command("autoBackup", v ? "1" : "0"); generalAt = -1 }
            h += ui.px(34)
            let can = !backingUp && general["connected"] as? Bool == true && general["demo"] as? Bool != true
            if ui.button(now, id: "backup", cx + cw - ui.buttonWidth(now), cy + h, enabled: can) { core.command("backUpNow"); generalAt = -1 }
            h += ui.buttonHeight + ui.px(8)
            if ui.button("SHOW FOLDER", id: "backupFolder", cx + cw - ui.buttonWidth("SHOW FOLDER"), cy + h) {
                try? FileManager.default.createDirectory(at: Folders.backups, withIntermediateDirectories: true)
                app.show(Folders.backups.path)
            }
            return h + ui.buttonHeight
        }
    }

    private func linkCheck(_ x: Int32, _ w: Int32, _ y: Int32) -> Int32 {
        card(x, w, y) { ix, iw, iy in
            let check = general["check"] as? [String: Any] ?? [:]
            let on = check["on"] as? Bool ?? false, missing = check["missing"] as? Int ?? 0
            var h = ui.text("LINK CHECK", ix, iy, width: iw, ui.font(13, bold: true))
            h += ui.px(6)
            h += ui.text(!on ? "What Galax-z hears from your OP-Z, once there is one."
                         : missing == 0 ? "Everything the screen follows has come."
                         : "Set off what is not lit yet, with this open. SAVE keeps it as a file: it says what came and what did not.",
                         ix, iy + h, width: iw, ui.font(11), alpha: 0.55)
            h += ui.px(12)
            let items = check["items"] as? [[String: Any]] ?? []
            let cols = max(1, Int(iw / ui.px(330))), colW = iw / Int32(cols), rowH = ui.px(22)
            for (i, item) in items.enumerated() {
                let cx = ix + colW * Int32(i % cols), cy = iy + h + rowH * Int32(i / cols)
                let n = item["count"] as? Int ?? 0, optional = item["optional"] as? Bool ?? false
                ui.ellipse(RECT(left: cx, top: cy + ui.px(6), right: cx + ui.px(8), bottom: cy + ui.px(14)),
                           n > 0 ? Ink.green : Ink.mix(Ink.ink, optional ? 0.1 : 0.25, over: Ink.panel))
                let name = item["name"] as? String ?? ""
                let nw = ui.measure(name, ui.font(10, bold: true)).cx
                ui.line(name, RECT(left: cx + ui.px(16), top: cy, right: cx + ui.px(16) + nw, bottom: cy + rowH), ui.font(10, bold: true), alpha: n > 0 ? 0.95 : 0.6)
                ui.line(n > 0 ? "\(n)" : item["how"] as? String ?? "", RECT(left: cx + ui.px(26) + nw, top: cy, right: cx + colW - ui.px(8), bottom: cy + rowH),
                        ui.font(10), alpha: 0.45)
            }
            h += rowH * Int32((items.count + cols - 1) / cols) + ui.px(10)
            if ui.button("SAVE", id: "saveCheck", ix, iy + h) {
                let r = core.command("saveCheck", Folders.diagnostics.path)
                savedCheck = r
            }
            var bx = ix + ui.buttonWidth("SAVE") + ui.px(10)
            if let f = savedCheck, !f.hasPrefix("!") {
                if ui.button("SHOW", id: "showCheck", bx, iy + h) { app.show(Folders.diagnostics.path) }
                bx += ui.buttonWidth("SHOW") + ui.px(10)
            }
            if let f = savedCheck {
                ui.line(f.hasPrefix("!") ? String(f.dropFirst()) : "In Documents › Galax-z › Diagnostics: \((f as NSString).lastPathComponent)",
                        RECT(left: bx, top: iy + h, right: ix + iw, bottom: iy + h + ui.buttonHeight), ui.font(10), alpha: 0.5)
            }
            return h + ui.buttonHeight
        }
    }

    // MARK: PAIR AN OP-Z

    private func pairingPage(_ x: Int32, _ w: Int32, _ y0: Int32) -> Int32 {
        let bt = app.midi.bluetooth
        var y = y0
        ui.animating = true                                      // the list fills in by itself
        if ui.button("‹ BACK", id: "pairBack", x, y) { ui.defer_ { [weak self] in self?.closePairing() } }
        ui.dotText("PAIR AN OP-Z", x + ui.buttonWidth("‹ BACK") + ui.px(18), y + (ui.buttonHeight - ui.dotHeight(font: 2, dot: 1.6)) / 2, font: 2, dot: 1.6)
        y += ui.buttonHeight + ui.px(16)
        y += ui.text("Switch the OP-Z on and close TE's OP-Z app on your phone: it shows up below. PAIR it once; after that Galax-z connects to it "
                     + "by itself whenever it is on and no cable is in. Or plug in a USB-C cable: quicker, and the only way to install Galax-z OS.",
                     x, y, width: w, ui.font(11), alpha: 0.65) + ui.px(16)
        // where it stands
        let radio = bt.radio
        let usb = app.midi.connected, over = bt.connectedName
        y += card(x, w, y) { ix, iw, iy in
            let (dot, line): (UInt32, String) =
                usb ? (Ink.green, "YOUR OP-Z IS CONNECTED BY CABLE. BLUETOOTH WAITS UNTIL THE CABLE IS OUT.")
                : over != nil ? (Ink.green, "CONNECTED OVER BLUETOOTH: \(over!.uppercased())")
                : radio == 0 ? (Ink.red, "THIS COMPUTER HAS NO BLUETOOTH. USE A USB-C CABLE.")
                : radio == 2 ? (Ink.red, "BLUETOOTH IS SWITCHED OFF. SWITCH IT ON IN WINDOWS' BLUETOOTH SETTINGS.")
                : (Ink.yellow, bt.looked ? "LOOKING FOR AN OP-Z NEAR…" : "LOOKING…")
            ui.ellipse(RECT(left: ix, top: iy + ui.px(5), right: ix + ui.px(10), bottom: iy + ui.px(15)), dot)
            var h = ui.text(line, ix + ui.px(20), iy, width: iw - ui.px(20), ui.font(12, bold: true))
            let note = bt.note
            if !note.isEmpty { h += ui.px(8) + ui.text(note, ix + ui.px(20), iy + h + ui.px(8), width: iw - ui.px(20), ui.font(11), Ink.yellow) }
            if !usb, over == nil, radio == 1 { h += ui.px(12); h += ui.progress(nil, ix + ui.px(20), iy + h, width: min(iw - ui.px(20), ui.px(300))) }
            return h
        } + ui.px(16)
        // OP-Zs near, not paired yet
        y += section("NEAR, NOT PAIRED", x, y)
        let near = bt.nearby, pairing = bt.isPairing
        if near.isEmpty {
            y += ui.text(bt.looked ? "None found. Is it on? An OP-Z paired with your phone or another computer may need switching off and on."
                                   : "Looking for a few seconds…", x, y, width: w, ui.font(11), alpha: 0.5) + ui.px(8)
        }
        for d in near {
            y += card(x, w, y) { ix, iw, iy in
                let b = pairing ? "PAIRING…" : "PAIR"
                ui.line(d.name.uppercased(), RECT(left: ix, top: iy, right: ix + iw - ui.buttonWidth("PAIRING…") - ui.px(14), bottom: iy + ui.buttonHeight),
                        ui.font(13, bold: true))
                if ui.button(b, id: "pair-\(d.id)", ix + iw - ui.buttonWidth(b), iy, fill: Ink.yellow, enabled: !pairing) { bt.pair(d) }
                return ui.buttonHeight
            } + ui.px(10)
        }
        y += ui.px(6)
        // paired, on and in reach
        let paired = bt.paired
        if !paired.isEmpty {
            y += section("PAIRED", x, y)
            for name in paired {
                let on = over == name
                y += card(x, w, y) { ix, iw, iy in
                    ui.line(name.uppercased(), RECT(left: ix, top: iy, right: ix + iw / 2, bottom: iy + ui.px(22)), ui.font(13, bold: true))
                    ui.line(on ? "CONNECTED" : usb ? "WAITING: THE CABLE HAS IT" : "CONNECTING…", RECT(left: ix + iw / 2, top: iy, right: ix + iw, bottom: iy + ui.px(22)),
                            ui.font(10, bold: true), on ? Ink.green : Ink.ink, alpha: on ? 1 : 0.55, align: 2)
                    return ui.px(22)
                } + ui.px(10)
            }
            y += ui.px(6)
        }
        // Windows' own way, for anything this cannot do
        let s = "WINDOWS' BLUETOOTH SETTINGS"
        if ui.button(s, id: "btSettings", x, y) { app.show("ms-settings:bluetooth") }
        y += ui.buttonHeight + ui.px(10)
        y += ui.text("If it does not show up here: Windows' Bluetooth settings › Add device › Bluetooth › OP-Z. Over Bluetooth, backups take minutes "
                     + "and are not taken by themselves; installing Galax-z OS needs the cable.", x, y, width: w, ui.font(10), alpha: 0.45)
        return y - y0
    }

    // MARK: KEY TEST

    private func openKeyTest() { core.command("keyTestOpen"); keyTest = true; ui.scroll = 0 }
    private func closeKeyTest() { core.command("keyTestClose"); keyTest = false; ui.scroll = 0 }

    private func keyTestPage(_ x: Int32, _ w: Int32, _ y0: Int32) -> Int32 {
        var y = y0
        let k = Self.json(core.query("keytest"))
        ui.animating = true                                  // presses come in all the time
        if ui.button("‹ BACK", id: "ktBack", x, y) { ui.defer_ { [weak self] in self?.closeKeyTest() } }
        ui.dotText("KEY TEST", x + ui.buttonWidth("‹ BACK") + ui.px(18), y + (ui.buttonHeight - ui.dotHeight(font: 2, dot: 1.6)) / 2, font: 2, dot: 1.6)
        y += ui.buttonHeight + ui.px(16)
        let device = k["demo"] as? Bool == true ? "DEMO OP-Z (PRETEND PRESSES)" : (k["device"] as? String).flatMap { $0.isEmpty ? nil : "\($0.uppercased()) · \(k["over"] as? String ?? "")" } ?? "NO OP-Z"
        y += ui.text("Press every key a few times, quickly and slowly. A press that comes twice within the window is a double: that key bounces. "
                     + (k["playing"] as? Bool == true ? "Stop the OP-Z first: its own notes would count." : ""), x, y, width: w, ui.font(11), alpha: 0.6)
        y += ui.px(8)
        y += ui.text(device, x, y, width: w, ui.font(10, bold: true), alpha: 0.5)
        y += ui.px(14)
        y += card(x, w, y) { ix, iw, iy in
            let stats: [(String, String, UInt32)] = [
                ("PRESSES", "\(k["presses"] as? Int ?? 0)", Ink.ink),
                ("DOUBLES", "\(k["doubles"] as? Int ?? 0)", (k["doubles"] as? Int ?? 0) > 0 ? Ink.red : Ink.ink),
                ("KEYS THAT BOUNCE", "\(k["bouncing"] as? Int ?? 0)", (k["bouncing"] as? Int ?? 0) > 0 ? Ink.red : Ink.ink),
                ("FASTEST AGAIN", (k["fastest"] as? Int).map { "\($0) MS" } ?? "—", Ink.ink),
            ]
            let cw = iw / Int32(stats.count + 1)
            for (i, s) in stats.enumerated() {
                let cx = ix + cw * Int32(i)
                ui.line(s.0, RECT(left: cx, top: iy, right: cx + cw, bottom: iy + ui.px(14)), ui.font(9), alpha: 0.5)
                ui.dotText(s.1, cx, iy + ui.px(20), font: 2, dot: 1.4, s.2)
            }
            let wx = ix + cw * Int32(stats.count)
            ui.line("WINDOW", RECT(left: wx, top: iy, right: ix + iw, bottom: iy + ui.px(14)), ui.font(9), alpha: 0.5)
            if ui.button("−", id: "ktLess", wx, iy + ui.px(20)) { core.command("keyTestWindow", "-0.005") }
            let mw = ui.buttonWidth("−") + ui.px(6)
            ui.line("\(k["window"] as? Int ?? 0) MS", RECT(left: wx + mw, top: iy + ui.px(20), right: wx + mw + ui.px(60), bottom: iy + ui.px(20) + ui.buttonHeight),
                    ui.font(12, bold: true), align: 1)
            if ui.button("+", id: "ktMore", wx + mw + ui.px(66), iy + ui.px(20)) { core.command("keyTestWindow", "0.005") }
            return ui.px(20) + max(ui.dotHeight(font: 2, dot: 1.4), ui.buttonHeight)
        }
        y += ui.px(12)
        if ui.button("RESET", id: "ktReset", x, y) { core.command("keyTestReset") }
        y += ui.buttonHeight + ui.px(14)
        let keys = k["keys"] as? [[String: Any]] ?? []
        let cols = max(4, min(16, Int(w / ui.px(64)))), kw = w / Int32(cols), kh = ui.px(58)
        for (i, key) in keys.enumerated() {
            let kx = x + kw * Int32(i % cols), ky = y + (kh + ui.px(6)) * Int32(i / cols)
            let presses = key["presses"] as? Int ?? 0, doubles = key["doubles"] as? Int ?? 0
            let r = RECT(left: kx + ui.px(3), top: ky, right: kx + kw - ui.px(3), bottom: ky + kh)
            ui.fill(r, doubles > 0 ? Ink.mix(Ink.red, 0.25, over: Ink.panel) : presses > 0 ? Ink.mix(Ink.green, 0.12, over: Ink.panel) : Ink.panel, corner: 8)
            ui.line(key["name"] as? String ?? "", RECT(left: r.left, top: r.top + ui.px(4), right: r.right, bottom: r.top + ui.px(22)), ui.font(10, bold: true), align: 1)
            ui.line("\(presses)", RECT(left: r.left, top: r.top + ui.px(22), right: r.right, bottom: r.top + ui.px(38)), ui.font(10), alpha: 0.6, align: 1)
            if doubles > 0 { ui.line("×\(doubles)", RECT(left: r.left, top: r.top + ui.px(38), right: r.right, bottom: r.bottom - ui.px(2)), ui.font(10, bold: true), Ink.red, align: 1) }
        }
        y += (kh + ui.px(6)) * Int32((keys.count + cols - 1) / cols) + ui.px(10)
        let log = k["log"] as? [[String: Any]] ?? []
        if !log.isEmpty {
            y += section("LAST PRESSES", x, y)
            for e in log.prefix(12) {
                let gap = (e["gap"] as? Int).map { "  \($0) ms after the last" } ?? ""
                let held = (e["held"] as? Int).map { ", held \($0) ms" } ?? ""
                let double = e["double"] as? Bool == true
                ui.line("\(e["name"] as? String ?? "")\(gap)\(held)\(double ? "  DOUBLE" : "")", RECT(left: x, top: y, right: x + w, bottom: y + ui.px(18)),
                        ui.font(10, bold: double), double ? Ink.red : Ink.ink, alpha: double ? 1 : 0.6)
                y += ui.px(18)
            }
        }
        if let report = k["report"] as? String, !report.isEmpty {
            y += ui.px(10)
            y += ui.text(report, x, y, width: w, ui.font(10), alpha: 0.5)
        }
        return y - y0
    }

    // MARK: GALAX-Z OS

    private var recentBackup: Bool {
        guard let checked = general["checked"] as? Double else { return false }
        return Date().timeIntervalSince1970 - checked / 1000 < 24 * 3600
    }

    private var installedLine: String {
        if let i = hub.installed { return "ON YOUR OP-Z: \(hub.titleOf(i).uppercased())" }
        if let k = hub.lastKnown { return "ON YOUR OP-Z, WHEN LAST READ: \(hub.titleOf(k).uppercased())" }
        return "NOT READ YET"
    }

    private func hubPage(_ x: Int32, _ w: Int32, _ y0: Int32) -> Int32 {
        var y = y0
        let gap = ui.px(16)
        if busy || hub.looking { ui.animating = true }
        // the bar: the name, what is on it, OPEN FILE and LOOK FOR NEW
        let bw = ui.buttonWidth("OPEN FILE") + ui.px(10) + ui.buttonWidth(hub.looking ? "LOOKING…" : "LOOK FOR NEW")
        ui.dotText("GALAX-Z OS", x, y, font: 2, dot: 2.4)
        let nameH = ui.dotHeight(font: 2, dot: 2.4)
        ui.line(installedLine, RECT(left: x, top: y + nameH + ui.px(8), right: x + w - bw - ui.px(12), bottom: y + nameH + ui.px(26)), ui.font(11), alpha: 0.6)
        if ui.button("OPEN FILE", id: "openFile", x + w - bw, y) { ui.defer_ { [weak self] in self?.openRelease() } }
        let look = hub.looking ? "LOOKING…" : "LOOK FOR NEW"
        if ui.button(look, id: "lookNew", x + w - ui.buttonWidth(look), y, enabled: !hub.looking) { hub.lookForReleases(asked: true) }
        y += nameH + ui.px(26) + gap
        if let problem = hub.problem { y += warning(problem, x, w, y) + gap }
        if !busy, let what = hub.interrupted {
            y += warning("WRITING \(what.uppercased()) DID NOT FINISH. Don't switch the OP-Z on normally. Switch it off, hold SCREEN, switch it on, "
                         + "press READ, and install TE's original (under OTHER VERSIONS). After that, any version.", x, w, y) + gap
        }
        if hub.mustPowerCycle {
            let b = "I SWITCHED IT OFF"
            ui.line("Switch the OP-Z off (the cable out is not enough: it has a battery).", RECT(left: x, top: y, right: x + w - ui.buttonWidth(b) - ui.px(14), bottom: y + ui.buttonHeight),
                    ui.font(11), alpha: 0.8)
            if ui.button(b, id: "switchedOff", x + w - ui.buttonWidth(b), y, fill: Ink.yellow, enabled: hub.ports.isEmpty) { hub.switchedOff() }
            y += ui.buttonHeight + gap
        }
        if let r = hub.newest { y += newest(r, x, w, y) + gap }
        y += row("CHIME WHEN THE OP-Z IS SWITCHED ON", hub.chimeDiffers ? "Install it again for this: the OP-Z keeps it, not the app."
                 : "Two Quindar tones are its start sound, at the OP-Z's own volume. Off: none. It goes with the version when that is installed.",
                 x, w, y, controls: ui.toggleWidth) { cx, cy in
            if let v = ui.toggle("chime", hub.chime, cx, cy, enabled: !busy) { hub.chime = v }
            return ui.px(24)
        } + gap
        y += steps(x, w, y) + gap
        y += working(x, w, y)
        y += versions(x, w, y)
        y += ui.px(10)
        ui.dotText("BOOT ANIMATION", x, y, font: 0, dot: 2, Ink.yellow)
        y += ui.dotHeight(font: 0, dot: 2) + ui.px(12)
        y += animations(x, w, y)
        if !hub.log.isEmpty || !busy {
            y += gap
            var bx = x
            if !hub.log.isEmpty {
                if ui.button(showLog ? "HIDE LOG" : "SHOW LOG", id: "log", bx, y) { showLog.toggle() }
                bx += ui.buttonWidth(showLog ? "HIDE LOG" : "SHOW LOG") + ui.px(10)
            }
            if ui.button("OS BACKUPS", id: "osBackups", bx, y) {
                let os = Folders.backups.appendingPathComponent("os")
                try? FileManager.default.createDirectory(at: os, withIntermediateDirectories: true)
                app.show(os.path)
            }
            y += ui.buttonHeight
            if showLog, !hub.log.isEmpty {
                y += ui.px(10)
                y += card(x, w, y) { ix, iw, iy in
                    ui.text(hub.log.suffix(60).joined(separator: "\n"), ix, iy, width: iw, ui.font(10), alpha: 0.75)
                }
            }
        }
        return y - y0
    }

    private func newest(_ r: Hub.Version, _ x: Int32, _ w: Int32, _ y: Int32) -> Int32 {
        card(x, w, y) { ix, iw, iy in
            let controlW = hub.isOn(r.label) ? 0 : ui.px(200)
            let tw = iw - controlW - ui.px(20)
            let tWidth = ui.dotText(r.title, ix, iy, font: 2, dot: 2, Ink.yellow)
            let th = ui.dotHeight(font: 2, dot: 2)
            let by = iy + (th - ui.dotHeight(font: 0, dot: 1.6) - ui.px(10)) / 2
            if hub.isOn(r.label) { _ = badge("ON YOUR OP-Z", Ink.green, ix + tWidth + ui.px(12), by) }
            else { _ = badge(hub.isNews(r.label) ? "NEW" : "NEWEST", Ink.yellow, ix + tWidth + ui.px(12), by) }
            var h = th + ui.px(10)
            for n in r.notes {
                ui.ellipse(RECT(left: ix, top: iy + h + ui.px(6), right: ix + ui.px(5), bottom: iy + h + ui.px(11)), Ink.yellow)
                h += ui.text(n, ix + ui.px(15), iy + h, width: tw - ui.px(15), ui.font(12), alpha: 0.85) + ui.px(4)
            }
            if !r.detail.isEmpty { h += ui.px(4) + ui.text(r.detail, ix, iy + h + ui.px(4), width: tw, ui.font(9), alpha: 0.4) }
            if controlW > 0 { h = max(h, install(r.label, r.title, ix + iw - controlW, iy, width: controlW)) }
            return h
        }
    }

    /// HOLD TO INSTALL, and why not when it cannot.
    private func install(_ label: String, _ title: String, _ x: Int32, _ y: Int32, width: Int32, color: UInt32 = Ink.yellow) -> Int32 {
        guard !hub.isOn(label) else { return 0 }
        var h = ui.holdButton("install-\(label)", "HOLD TO INSTALL", question: "Write \(title) to the OP-Z?", x + width - ui.px(190), y, color: color,
                              enabled: hub.ready(label), hwnd: app.window) { [weak self] in self?.hub.flash(label) }
        if let why = hub.notReady(label), !why.isEmpty {
            h += ui.px(6)
            ui.line(why, RECT(left: x - ui.px(60), top: y + h, right: x + width, bottom: y + h + ui.px(14)), ui.font(9), alpha: 0.5, align: 2)
            h += ui.px(14)
        }
        return h
    }

    private func steps(_ x: Int32, _ w: Int32, _ y0: Int32) -> Int32 {
        let s = hub.step(backedUp: recentBackup)
        var y = y0
        ui.dotText("HOW TO UPDATE", x, y + ui.px(6), font: 0, dot: 2, Ink.yellow)
        y += ui.px(6) + ui.dotHeight(font: 0, dot: 2) + ui.px(10)
        let cols = max(1, min(5, Int((w + ui.px(10)) / ui.px(215)))), gap = ui.px(10)
        let cw = (w - gap * Int32(cols - 1)) / Int32(cols)
        let checked = general["checked"] as? Double
        let items: [(Int, String, String, Bool, (Int32, Int32) -> Int32)] = [
            (1, "BACK UP", recentBackup && checked != nil ? "Done \(Self.when(checked!, date: false))."
                : "Plug the OP-Z in, switched on normally. Copies your projects and sounds.", false, { [self] bx, by in
                guard !recentBackup else { return 0 }
                let can = !backingUp && general["connected"] as? Bool == true && general["demo"] as? Bool != true
                if ui.button(backingUp ? "BACKING UP…" : "BACK UP NOW", id: "stepBackup", bx, by, enabled: can) { core.command("backUpNow"); generalAt = -1 }
                return ui.buttonHeight
            }),
            (2, "UPDATE MODE", hub.ports.isEmpty ? "Switch the OP-Z off. Hold SCREEN and switch it on. Keep the cable in." : "Found (\(hub.ports.joined(separator: ", "))). Ready to be read.",
             false, { _, _ in 0 }),
            (3, "READ", hub.installed.map { "It has \(hub.titleOf($0))." } ?? "Reads what is on it. Changes nothing.", !hub.ports.isEmpty && hub.mustRead, { [self] bx, by in
                guard hub.installed == nil || hub.mustRead else { return 0 }
                if ui.button("READ", id: "read", bx, by, fill: Ink.yellow, enabled: !busy && !hub.ports.isEmpty && !hub.mustPowerCycle) { hub.check() }
                return ui.buttonHeight
            }),
            (4, "INSTALL", hub.justInstalled != nil ? "Written and read back, byte for byte." : "Hold the button on a version. Two files are written, and both read back.",
             false, { _, _ in 0 }),
            (5, "RESTART", "Switch it off, then on, with nothing held.", false, { _, _ in 0 }),
        ]
        var rowH: Int32 = 0
        for (i, item) in items.enumerated() {
            let (n, name, text, always, control) = item
            let cx = x + (cw + gap) * Int32(i % cols)
            if i % cols == 0, i > 0 { y += rowH + gap; rowH = 0 }
            let done = n < s, here = n == s
            let mark = ui.mark, pad = ui.px(14)
            var h = pad
            let numW = ui.dotText(done ? "✓" : "\(n)", cx + pad, y + h, font: 1, dot: 2, done ? Ink.green : here ? Ink.yellow : Ink.mix(Ink.ink, 0.4, over: Ink.panel))
            ui.dotText(name, cx + pad + numW + ui.px(10), y + h + ui.px(2), font: 0, dot: 2, here ? Ink.yellow : Ink.mix(Ink.ink, done ? 0.8 : 0.45, over: Ink.panel))
            h += ui.dotHeight(font: 1, dot: 2) + ui.px(8)
            h += ui.text(text, cx + pad, y + h, width: cw - pad * 2, ui.font(10), alpha: here ? 0.85 : 0.45) + ui.px(8)
            if here || always { h += control(cx + pad, y + h) }
            h = max(h + pad, ui.px(112))
            ui.card(from: mark, RECT(left: cx, top: y, right: cx + cw, bottom: y + h), Ink.panel, corner: 12, stroke: here ? Ink.mix(Ink.yellow, 0.7, over: Ink.panel) : nil)
            rowH = max(rowH, h)
        }
        y += rowH
        if hub.hasOriginal {
            y += ui.px(10)
            let b = "SHOW IT"
            let th = ui.text("TE's \(Original.firmware) is kept in %LOCALAPPDATA%\\Galax-z\\os-1.2.45.ldr: copy it somewhere safe, it is the way back.",
                             x, y + ui.px(6), width: w - ui.buttonWidth(b) - ui.px(14), ui.font(10), alpha: 0.5)
            if ui.button(b, id: "showOriginal", x + w - ui.buttonWidth(b), y) { app.show(hub.support.path) }
            y += max(th + ui.px(6), ui.buttonHeight)
        }
        return y - y0
    }

    private func working(_ x: Int32, _ w: Int32, _ y: Int32) -> Int32 {
        let gap = ui.px(16)
        if let busy = hub.busy {
            return card(x, w, y) { ix, iw, iy in
                var h = ui.px(4)
                ui.dotText(busy + (hub.progress.map { " · \($0.name)" } ?? ""), ix, iy + h, font: 0, dot: 2, Ink.yellow)
                h += ui.dotHeight(font: 0, dot: 2) + ui.px(12)
                h += ui.progress(hub.progress.map { Double($0.done) / Double(max(1, $0.of)) }, ix, iy + h, width: iw)
                if hub.writing {
                    h += ui.px(10)
                    h += ui.text("DON'T UNPLUG OR SWITCH OFF THE OP-Z.", ix, iy + h, width: iw, ui.font(11, bold: true), Ink.red)
                }
                return h
            } + gap
        }
        guard let r = hub.result else { return 0 }
        if r.ok, let i = hub.justInstalled {
            return card(x, w, y) { ix, iw, iy in
                ui.dotText("\(hub.titleOf(i)) IS ON YOUR OP-Z", ix, iy, font: 1, dot: 2, Ink.green)
                let h = ui.dotHeight(font: 1, dot: 2) + ui.px(10)
                return h + ui.text("Written, read back and identical. Switch it off, then on, with nothing held. If it does not start: switch off, hold SCREEN, "
                                   + "switch on, and install the version you had or TE's original.", ix, iy + h, width: iw, ui.font(11), alpha: 0.7)
            } + gap
        }
        if r.ok, r.text != "done" {
            return card(x, w, y) { ix, iw, iy in ui.text(r.text, ix, iy, width: iw, ui.font(12, bold: true), Ink.green) } + gap
        }
        if !r.ok { return warning(r.text + (hub.mustPowerCycle ? " Switch the OP-Z off before trying again." : ""), x, w, y) + gap }
        return 0
    }

    private func versions(_ x: Int32, _ w: Int32, _ y0: Int32) -> Int32 {
        var y = y0 + ui.px(6)
        ui.dotText("OTHER VERSIONS", x, y + ui.px(8), font: 0, dot: 2, Ink.yellow)
        let b = showAll ? "FEWER" : "ALL"
        if ui.button(b, id: "all", x + w - ui.buttonWidth(b), y) { showAll.toggle() }
        y += ui.buttonHeight + ui.px(10)
        if !hub.hasOriginal {
            y += ui.text("Every version is made on this computer from TE's \(Original.firmware), read off your own OP-Z in step 3. No OS of TE's comes with the app.",
                         x, y, width: w, ui.font(11), alpha: 0.6) + ui.px(10)
        }
        let rest = Array(hub.versions.dropFirst())
        let shown = showAll ? rest : Array(rest.filter { $0.label != "original" }.prefix(2)) + hub.versions.filter { $0.label == "original" }
        for v in shown {
            y += card(x, w, y) { ix, iw, iy in
                let controlW = hub.isOn(v.label) ? 0 : ui.px(200)
                let tw = iw - controlW - ui.px(20)
                var bx = ix + ui.dotText(v.title, ix, iy, font: 1, dot: 2) + ui.px(10)
                let th = ui.dotHeight(font: 1, dot: 2)
                if hub.isOn(v.label) { bx += badge("ON YOUR OP-Z", Ink.green, bx, iy - ui.px(2)) + ui.px(8) }
                if v.downloaded { _ = badge("SIGNED", Ink.blue, bx, iy - ui.px(2)) }
                var h = th + ui.px(8)
                h += ui.text(v.summary, ix, iy + h, width: tw, ui.font(11), alpha: 0.65)
                if !v.reason.isEmpty { h += ui.px(4) + ui.text(v.reason, ix, iy + h + ui.px(4), width: tw, ui.font(9), Ink.red) }
                if controlW > 0 { h = max(h, install(v.label, v.title, ix + iw - controlW, iy, width: controlW, color: v.label == "original" ? Ink.ink : Ink.yellow)) }
                return h
            } + ui.px(10)
        }
        return y - y0
    }

    // MARK: boot animations (`AnimationLibrary`)

    private func animations(_ x: Int32, _ w: Int32, _ y0: Int32) -> Int32 {
        var y = y0
        let bases = hub.bases
        if bases.count > 1 {
            ui.line("FLASH ANIMATIONS ONTO", RECT(left: x, top: y, right: x + w, bottom: y + ui.px(16)), ui.font(9), alpha: 0.45)
            y += ui.px(20)
            // many builds: by their short names (V2, V13 QUIET)
            let names = bases.map { $0.1.uppercased().replacingOccurrences(of: "GALAX-Z ", with: "") }
            if let i = ui.segmented("base", names, bases.firstIndex { $0.0 == hub.base } ?? 0, x, y,
                                    width: min(w, ui.px(names.contains { $0.count > 4 } ? 110 : 64) * Int32(bases.count)), enabled: !busy) { hub.base = bases[i].0 }
            y += ui.px(42)
        }
        if !hub.store.mine.isEmpty { y += animationSection("YOUR ANIMATIONS", hub.store.mine, x, w, y) }
        y += animationSection("BOOT ANIMATIONS", LEDAnimation.library, x, w, y)
        return y - y0
    }

    private func animationSection(_ title: String, _ list: [LEDAnimation], _ x: Int32, _ w: Int32, _ y0: Int32) -> Int32 {
        var y = y0 + ui.px(6)
        ui.line(title, RECT(left: x, top: y, right: x + w, bottom: y + ui.px(16)), ui.font(9), alpha: 0.45)
        y += ui.px(24)
        let gap = ui.px(12), cols = max(1, Int((w + gap) / ui.px(312)))
        let cw = (w - gap * Int32(cols - 1)) / Int32(cols)
        var rowH: Int32 = 0
        for (i, a) in list.enumerated() {
            if i % cols == 0, i > 0 { y += rowH + gap; rowH = 0 }
            let cx = x + (cw + gap) * Int32(i % cols)
            rowH = max(rowH, animationCard(a, cx, cw, y))
        }
        return y + rowH + gap - y0
    }

    private func animationCard(_ a: LEDAnimation, _ x: Int32, _ w: Int32, _ y: Int32) -> Int32 {
        card(x, w, y) { ix, iw, iy in
            var h: Int32 = 0
            if let layout = hub.layout {
                preview(hub.store.frames(a, layout), layout, RECT(left: ix, top: iy, right: ix + iw, bottom: iy + ui.px(92)), fps: 24)
                h += ui.px(92) + ui.px(10)
            }
            let editW = a.isTest ? 0 : ui.buttonWidth("EDIT")
            let tw = iw - editW - ui.px(8)
            let name = a.name.uppercased()
            let nw = min(tw, ui.measure(name, ui.font(13, bold: true)).cx)
            ui.line(name, RECT(left: ix, top: iy + h, right: ix + nw, bottom: iy + h + ui.px(20)), ui.font(13, bold: true))
            if hub.playing(a) {
                let bw = ui.measure("ON THE OP-Z", ui.font(8, bold: true)).cx + ui.px(12)
                let r = RECT(left: ix + nw + ui.px(8), top: iy + h + ui.px(3), right: ix + nw + ui.px(8) + bw, bottom: iy + h + ui.px(17))
                ui.fill(r, Ink.green, corner: 7)
                ui.line("ON THE OP-Z", r, ui.font(8, bold: true), Ink.background, align: 1)
            }
            if editW > 0, ui.button("EDIT", id: "edit-\(a.id)", ix + iw - editW, iy + h - ui.px(4)) {
                let e = hub.store.isMine(a) ? a : hub.store.copy(of: a)
                ui.defer_ { [weak self] in self?.openEditor(e) }
            }
            h += ui.px(24)
            h += ui.text(a.blurb, ix, iy + h, width: tw, ui.font(10), alpha: 0.6) + ui.px(10)
            let base = hub.titleOf(hub.base)
            h += ui.holdButton("anim-\(a.id)", "HOLD TO INSTALL", question: "Write \(base) playing \(a.name) to the OP-Z?", ix, iy + h,
                               enabled: hub.animationReady, hwnd: app.window) { [weak self] in self?.hub.flash(a) }
            h += ui.px(6)
            h += ui.text("WRITES \(base.uppercased()) PLAYING IT", ix, iy + h, width: iw, ui.font(9), hub.isOn(hub.base) || hub.installed == nil ? Ink.ink : Ink.yellow,
                         alpha: hub.isOn(hub.base) ? 0.45 : 1)
            return h
        }
    }

    /// An animation on a drawing of the OP-Z's keys (`LEDPreview`): 240 frames at 60 a second, blended, then a breath of dark.
    private func preview(_ frames: [[RGBW]], _ layout: LEDLayout, _ r: RECT, fps: Double) {
        ui.fill(r, Ink.background, corner: 10)
        guard !frames.isEmpty else { return }
        ui.animating = true
        let frameTime = 1.0 / 60, rest = 0.8
        let t = ProcessInfo.processInfo.systemUptime
        let length = Double(frames.count) * frameTime
        let at = t.truncatingRemainder(dividingBy: length + rest) / frameTime
        let i = min(frames.count - 1, Int(at)), j = min(frames.count - 1, i + 1), k = min(1, at - Double(i))
        let w = Double(r.right - r.left), h = Double(r.bottom - r.top)
        let ay = layout.points.values.map(\.aspectY).max() ?? 0.15
        let scale = min(w - 16, (h - 16) / max(ay, 0.01))
        let ox = Double(r.left) + (w - scale) / 2, oy = Double(r.top) + (h - ay * scale) / 2
        let dot = max(4, scale / 34)
        for (n, p) in layout.points {
            let c = frames[i][n] * (1 - k) + frames[j][n] * k
            let cx = ox + p.x * scale, cy = oy + p.aspectY * scale
            let rr = RECT(left: Int32(cx - dot / 2), top: Int32(cy - dot / 2), right: Int32(cx + dot / 2), bottom: Int32(cy + dot / 2))
            ui.ellipse(rr, Self.shown(c))
        }
    }

    /// An RGBW LED as a screen shows it: its colour at full, as see-through as the LED is dim; white adds to all three.
    static func shown(_ c: RGBW) -> UInt32 {
        func v(_ i: Int) -> Double { min(1, c[i] + c[3]) }
        let top = max(v(0), v(1), v(2))
        guard top >= 0.001 else { return Ink.mix(Ink.ink, 0.08) }
        func byte(_ x: Double) -> UInt32 { UInt32(max(0, min(255, (x / top * 255).rounded()))) }
        return Ink.mix(byte(v(0)) << 16 | byte(v(1)) << 8 | byte(v(2)), max(top, 0.08))
    }

    // MARK: the editor (`AnimationEditor`)

    private func openEditor(_ a: LEDAnimation) {
        editing = a
        scrollBeforeEditor = ui.scroll
        ui.scroll = 0
        guard let parent = app.window else { return }
        let cls = Array("EDIT".utf16) + [0], text = Array(a.name.utf16) + [0]
        nameBox = CreateWindowExW(0, cls, text, DWORD(WS_CHILD) | DWORD(WS_VISIBLE) | DWORD(ES_AUTOHSCROLL), 0, 0, 10, 10, parent, nil, GetModuleHandleW(nil), nil)
        nameFont = CreateFontW(-ui.px(22), 0, 0, 0, 700, 0, 0, 0, 1, 0, 0, 5, 0, Array("Consolas".utf16) + [0])
        if let nameBox, let nameFont { SendMessageW(nameBox, UINT(WM_SETFONT), WPARAM(UInt(bitPattern: Int(bitPattern: UnsafeRawPointer(nameFont)))), 1) }
    }

    private func closeEditor() {
        editing = nil
        if let nameBox { DestroyWindow(nameBox) }
        if let nameFont { DeleteObject(nameFont) }
        nameBox = nil
        nameFont = nil
        ui.scroll = scrollBeforeEditor
        SetFocus(app.window)
    }

    private var typedName: String {
        guard let nameBox else { return editing?.name ?? "" }
        var buf = [WCHAR](repeating: 0, count: 256)
        let n = Int(GetWindowTextW(nameBox, &buf, Int32(buf.count)))
        return String(decoding: buf[0..<n], as: UTF16.self)
    }

    private var nameRect = RECT()

    private func placeNameBox() {
        guard let nameBox else { return }
        let r = nameRect
        if editing == nil || r.top < ui.contentTop || r.bottom <= r.top { ShowWindow(nameBox, SW_HIDE); return }
        MoveWindow(nameBox, r.left, r.top, r.right - r.left, r.bottom - r.top, true)
        ShowWindow(nameBox, SW_SHOWNA)
    }

    /// The colours of the name box (WM_CTLCOLOREDIT).
    func colorBox(_ dc: HDC) -> LRESULT {
        SetTextColor(dc, Ink.ref(Ink.ink))
        SetBkColor(dc, Ink.ref(Ink.panel))
        return LRESULT(Int(bitPattern: UnsafeRawPointer(App.panelBrush)))
    }

    private func editor(_ x: Int32, _ w: Int32, _ y0: Int32) -> Int32 {
        guard var a = editing, let layout = hub.layout else { return 0 }
        var y = y0
        let named = !typedName.trimmingCharacters(in: .whitespaces).isEmpty
        // name, DELETE, CANCEL, SAVE
        var right = x + w
        right -= ui.buttonWidth("SAVE")
        if ui.button("SAVE", id: "edSave", right, y + ui.px(4), fill: Ink.yellow, enabled: named) {
            a.name = typedName.trimmingCharacters(in: .whitespaces)
            hub.store.save(a)
            ui.defer_ { [weak self] in self?.closeEditor() }
        }
        right -= ui.buttonWidth("CANCEL") + ui.px(10)
        if ui.button("CANCEL", id: "edCancel", right, y + ui.px(4)) { ui.defer_ { [weak self] in self?.closeEditor() } }
        if hub.store.isMine(a) {
            right -= ui.buttonWidth("DELETE") + ui.px(10)
            if ui.button("DELETE", id: "edDelete", right, y + ui.px(4), fill: Ink.red) {
                let gone = a
                ui.defer_ { [weak self] in
                    guard let self else { return }
                    let q = Array("Delete \(gone.name)?".utf16) + [0], t = Array("Galax-z".utf16) + [0]
                    if MessageBoxW(self.app.window, q, t, UINT(0x04 | 0x30 | 0x100)) == 6 { self.hub.store.delete(gone); self.closeEditor() }
                }
            }
        }
        let box = RECT(left: x, top: y, right: right - ui.px(14), bottom: y + ui.px(38))
        ui.fill(box, Ink.panel, corner: 19)
        ui.stroke(box, Ink.mix(Ink.ink, 0.25), corner: 19)
        nameRect = RECT(left: box.left + ui.px(16), top: box.top + ui.px(7), right: box.right - ui.px(16), bottom: box.bottom - ui.px(6))
        y += ui.px(54)
        preview(hub.store.frames(a, layout), layout, RECT(left: x, top: y, right: x + w, bottom: y + ui.px(150)), fps: 60)
        y += ui.px(166)
        ui.line("PATTERN", RECT(left: x, top: y, right: x + w, bottom: y + ui.px(14)), ui.font(9), alpha: 0.45)
        y += ui.px(20)
        var px = x, rowH = ui.buttonHeight
        for p in LEDPattern.all where !p.isTest {
            let label = p.name.uppercased(), bw = ui.buttonWidth(label)
            if px + bw > x + w { px = x; y += rowH + ui.px(6) }
            if ui.button(label, id: "pattern-\(p.id)", px, y, fill: a.pattern == p.id ? Ink.yellow : nil) { a.pattern = p.id }
            px += bw + ui.px(6)
        }
        y += rowH + ui.px(18)
        ui.line("COLOURS", RECT(left: x, top: y, right: x + ui.px(200), bottom: y + ui.px(14)), ui.font(9), alpha: 0.45)
        ui.line("BLACK AND WHITE", RECT(left: x + ui.px(220), top: y, right: x + ui.px(420), bottom: y + ui.px(14)), ui.font(9), alpha: 0.45)
        y += ui.px(20)
        for i in 0..<3 {
            let r = RECT(left: x + ui.px(Double(i) * 50), top: y, right: x + ui.px(Double(i) * 50 + 38), bottom: y + ui.px(38))
            let c = a.style.colors[i]
            ui.ellipse(r, a.style.mono ? Ink.mix(c, 0.3) : c)
            ui.stroke(r, Ink.mix(Ink.ink, 0.3), corner: 38)
            if ui.interact("colour-\(i)", r, enabled: !a.style.mono) {
                let id = a.id
                ui.defer_ { [weak self] in self?.pickColour(i, of: id) }
            }
        }
        if let v = ui.toggle("mono", a.style.mono, x + ui.px(220), y + ui.px(7)) { a.style.mono = v }
        y += ui.px(54)
        for (title, key) in [("TOP ROW + ENCODERS", \LEDStyle.colorOpacity), ("WHITE ROWS", \LEDStyle.bedOpacity)] {
            ui.line(title, RECT(left: x, top: y, right: x + ui.px(170), bottom: y + ui.px(22)), ui.font(10, bold: true))
            let v = ui.slider(title, a.style[keyPath: key], 0...1, x + ui.px(180), y, width: w - ui.px(250))
            a.style[keyPath: key] = (v * 20).rounded() / 20
            ui.line("\(Int((a.style[keyPath: key] * 100).rounded()))%", RECT(left: x + w - ui.px(60), top: y, right: x + w, bottom: y + ui.px(22)), ui.font(12, bold: true), align: 2)
            y += ui.px(34)
        }
        y += ui.text("The top 17 keys and the encoders have colour; the two rows below are white only.", x, y, width: w, ui.font(10), alpha: 0.45)
        if editing?.id == a.id { editing = a }
        return y - y0
    }

    private func pickColour(_ i: Int, of id: String) {
        guard var a = editing, a.id == id else { return }
        let c = a.style.colors[i]
        var cc = CHOOSECOLORW()
        cc.lStructSize = DWORD(MemoryLayout<CHOOSECOLORW>.size)
        cc.hwndOwner = app.window
        cc.rgbResult = Ink.ref(c)
        cc.Flags = DWORD(0x1 | 0x2)                                       // CC_RGBINIT | CC_FULLOPEN
        let ok = custom.withUnsafeMutableBufferPointer { p -> Bool in
            cc.lpCustColors = p.baseAddress
            return ChooseColorW(&cc)
        }
        guard ok else { return }
        let r = cc.rgbResult
        a.style.colors[i] = (r & 255) << 16 | (r & 0xFF00) | (r >> 16) & 255
        editing = a
    }

    // MARK: files

    private func openRelease() {
        var file = [WCHAR](repeating: 0, count: 1024)
        let filter = Array("Galax-z release (*.galaxz)\0*.galaxz\0All files\0*.*\0\0".utf16)
        var o = OPENFILENAMEW()
        o.lStructSize = DWORD(MemoryLayout<OPENFILENAMEW>.size)
        o.hwndOwner = app.window
        o.Flags = DWORD(0x1000 | 0x800 | 0x8)                            // FILEMUSTEXIST | PATHMUSTEXIST | NOCHANGEDIR
        let ok = filter.withUnsafeBufferPointer { f in
            file.withUnsafeMutableBufferPointer { b -> Bool in
                o.lpstrFilter = f.baseAddress
                o.lpstrFile = b.baseAddress
                o.nMaxFile = DWORD(b.count)
                return GetOpenFileNameW(&o)
            }
        }
        guard ok else { return }
        let path = String(decoding: file.prefix { $0 != 0 }, as: UTF16.self)
        hub.open(URL(fileURLWithPath: path))
    }

    // MARK: words

    static func json(_ s: String) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(s.utf8))) as? [String: Any] ?? [:]
    }

    /// A time from the core (milliseconds since 1970), as the Mac writes it.
    static func when(_ ms: Double, date: Bool) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateStyle = date ? .medium : .none
        f.timeStyle = .short
        return f.string(from: Date(timeIntervalSince1970: ms / 1000))
    }
}
#endif
