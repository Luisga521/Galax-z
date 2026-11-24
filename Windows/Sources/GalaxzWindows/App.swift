#if os(Windows)
import Foundation
import GalaxzAndroid
import GalaxzDesktop
import OPZFirmware
import WinSDK

/// Galax-z for Windows: one window that is the OP-Z's screen, as on the Mac. The dots are drawn by the CPU
/// (`DotRenderer`) and put on the window by GDI; a frame is drawn only while something moves. Settings and the Galax-z OS
/// installer open over it (`SettingsPanel`), as the Mac's sheet does.
final class App {
    nonisolated(unsafe) static var shared: App?
    nonisolated(unsafe) static let panelBrush = CreateSolidBrush(Ink.ref(Ink.panel))

    let core: DesktopCore
    let renderer = DotRenderer()
    let pointer: Pointer
    let midi: WinMIDI
    let prefs: Prefs
    let main = MainQueue()
    let hub: Hub
    var window: HWND?
    /// Settings, over the screen; nil: the screen.
    private var panel: SettingsPanel?
    private var panelAt = 0.0, panelDirty = false, painting = false
    private var portsAt = 0.0
    private var lookedForReleases = false
    /// The monitor's refresh rate, and a frame at that rate: drawn as often as the monitor the window is on shows them.
    private(set) var hz = 60
    private var frameTime = 1.0 / 60
    /// Frames drawn, counted for the log.
    private var counted = 0, countedSince = 0.0
    /// How long a frame takes to draw (smoothed), and frames since the resolution was last weighed.
    private var cost = 0.0, sinceAdapt = 0
    private var dots: [UInt8] = []
    private var lastFrame = 0.0, movedAt = 0.0
    private var still = false
    /// Rendered pixels to window pixels: 2 on a very big window, so a frame stays quick.
    private var scale = 1
    private var size = (w: 1, h: 1)
    private var windowed: (style: LONG_PTR, rect: RECT)?     // the window as it was before full screen
    private var note = ""

    static func run() {
        Log.say("Galax-z for Windows starting")
        // says that Galax-z runs, for its setup (Galax-z.iss, AppMutex): it asks for it to be closed before replacing it
        let running = CreateMutexW(nil, false, Array("Galax-z.App".utf16) + [0])
        defer { if let running { CloseHandle(running) } }
        _ = SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)
        timeBeginPeriod(1)                                    // waits to the millisecond, for MIDI's timing
        defer { timeEndPeriod(1) }
        let demo = CommandLine.arguments.contains("--demo")
        let app = App(demo: demo)
        shared = app
        guard app.open() else { Log.say("no window"); return }
        if app.prefs[\.fullScreen] { app.fullScreen(true) }
        app.loop()
        app.midi.close()
        Log.say("Galax-z for Windows closed")
    }

    init(demo: Bool) {
        try? FileManager.default.createDirectory(at: Folders.support, withIntermediateDirectories: true)
        core = DesktopCore(folder: Folders.support, files: nil, demo: demo)
        core.command("backups", Folders.backups.path)
        pointer = Pointer(core)
        midi = WinMIDI(core: core, main: main)
        prefs = Prefs(folder: Folders.support)
        let p = prefs.all
        renderer.look = DotRenderer.Look(fineness: p.fineness, glow: p.glow, afterglow: p.afterglow)
        // the update mode: a COM port of a teenage engineering USB device, exactly one (`UpdatePorts`)
        hub = Hub(support: Folders.support, backups: Folders.backups, prefs: prefs,
                  mode: Hub.UpdateMode(ports: { SerialPort.candidates() }, choose: { UpdatePorts.choose(WindowsPorts.present()) },
                                       open: { try SerialPort(path: $0) }), main: main)
        hub.keepAwake = { [weak self] on in self?.keepAwake(on) }
    }

    /// Who made this build (`build.ps1` writes it beside the program), shown in Settings › Credits.
    static let byline = ((try? String(contentsOfFile: besideProgram("byline.txt"), encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

    // MARK: Settings

    var look: DotRenderer.Look { renderer.look }

    func setLook(fineness: Int? = nil, glow: Double? = nil, afterglow: Double? = nil) {
        var l = renderer.look
        if let fineness { l.fineness = fineness; prefs[\.fineness] = fineness }
        if let glow { l.glow = glow; prefs[\.glow] = glow }
        if let afterglow { l.afterglow = afterglow; prefs[\.afterglow] = afterglow }
        renderer.look = l
        resized(window, size.w, size.h)
    }

    func openSettings(_ tab: SettingsPanel.Tab) {
        if let panel { panel.tab = tab } else { panel = SettingsPanel(app: self, tab: tab) }
        pointer.cancel()
        hub.refreshPorts()
        panelDirty = true
    }

    func closeSettings() {
        guard let p = panel, hub.busy == nil else { return }
        p.closing()
        panel = nil
        moved()
        InvalidateRect(window, nil, false)
    }

    /// A file or folder, opened as Explorer opens it.
    func show(_ path: String) {
        let verb = Array("open".utf16) + [0], p = Array(path.utf16) + [0]
        ShellExecuteW(window, verb, p, nil, nil, 1)                          // SW_SHOWNORMAL
    }

    /// While the OP-Z is written: the computer stays awake, and Windows is asked not to shut down.
    private func keepAwake(_ on: Bool) {
        SetThreadExecutionState(on ? 0x8000_0001 : 0x8000_0000)            // ES_CONTINUOUS (| ES_SYSTEM_REQUIRED)
        guard let window else { return }
        if on { ShutdownBlockReasonCreate(window, Array("Galax-z is writing to the OP-Z".utf16) + [0]) }
        else { ShutdownBlockReasonDestroy(window) }
    }

    private func paintPanel(_ given: HDC? = nil) {
        guard let panel, let window, !painting else { return }
        painting = true
        let scale = Double(max(96, GetDpiForWindow(window))) / 96
        var later = panel.layout(width: Int32(size.w), height: Int32(size.h), scale: scale)
        if !later.isEmpty || panelDirty { _ = panel.layout(width: Int32(size.w), height: Int32(size.h), scale: scale) }  // what the click changed
        panelDirty = false
        if let dc = given ?? GetDC(window) {
            panel.ui.paint(dc)
            if given == nil { ReleaseDC(window, dc) }
        }
        panelAt = DesktopCore.now()
        painting = false
        // dialog boxes, closing: after the frame
        while !later.isEmpty {
            for f in later { f() }
            later = []
            if self.panel != nil { panelDirty = true }
        }
    }

    // MARK: the window

    private func open() -> Bool {
        let instance = GetModuleHandleW(nil)
        let className = Array("GalaxzScreen".utf16) + [0]
        var wc = WNDCLASSEXW()
        wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wc.style = UINT(CS_HREDRAW | CS_VREDRAW)
        wc.lpfnWndProc = windowProc
        wc.hInstance = instance
        wc.hCursor = LoadCursorW(nil, UnsafePointer<WCHAR>(bitPattern: 32512))          // IDC_ARROW
        let registered = className.withUnsafeBufferPointer { p -> Bool in
            wc.lpszClassName = p.baseAddress
            return RegisterClassExW(&wc) != 0
        }
        guard registered else { return false }
        let dpi = Int(GetDpiForSystem())
        let title = Array("Galax-z".utf16) + [0]
        window = CreateWindowExW(0, className, title, DWORD(WS_OVERLAPPEDWINDOW) | DWORD(WS_VISIBLE),
                                 CW_USEDEFAULT, CW_USEDEFAULT, Int32(1280 * dpi / 96), Int32(820 * dpi / 96), nil, nil, instance, nil)
        guard let window else { return false }
        refreshRate()
        setIcon(window)
        ShowWindow(window, SW_SHOW)
        UpdateWindow(window)
        return true
    }

    /// Galax-z's icon, from the file beside the program (`build.ps1` puts it there).
    private func setIcon(_ w: HWND) {
        let path = Array(Self.besideProgram("Galax-z.ico").utf16) + [0]
        guard let icon = LoadImageW(nil, path, UINT(IMAGE_ICON), 0, 0, UINT(LR_LOADFROMFILE | LR_DEFAULTSIZE)) else { return }
        let l = LPARAM(Int(bitPattern: UInt(bitPattern: icon)))
        SendMessageW(w, UINT(WM_SETICON), WPARAM(1), l)              // ICON_BIG
        SendMessageW(w, UINT(WM_SETICON), WPARAM(0), l)              // ICON_SMALL
    }

    static func besideProgram(_ name: String) -> String {
        var buf = [WCHAR](repeating: 0, count: 32_768)
        let n = Int(GetModuleFileNameW(nil, &buf, DWORD(buf.count)))
        let exe = String(decoding: buf[0..<n], as: UTF16.self)
        guard let cut = exe.lastIndex(of: "\\") else { return name }
        return String(exe[...cut]) + name
    }

    // MARK: the loop

    private func loop() {
        var msg = MSG()
        while true {
            while PeekMessageW(&msg, nil, 0, 0, UINT(PM_REMOVE)) {
                if msg.message == UINT(WM_QUIT) { return }
                TranslateMessage(&msg)
                DispatchMessageW(&msg)
            }
            let next = step()
            // sleep until the next frame is due, or a message comes, whichever is first
            let ms = DWORD(max(0, min(16, Int((next - DesktopCore.now()) * 1000))))
            MsgWaitForMultipleObjectsEx(0, nil, ms, DWORD(QS_ALLINPUT), DWORD(MWMO_INPUTAVAILABLE))
        }
    }

    /// Tick, look for the OP-Z, draw if something moves. When the next frame is due.
    @discardableResult
    func step() -> Double {
        let now = DesktopCore.now()
        if core.tick() { movedAt = now }
        midi.look(now)
        midi.pump()
        if main.drain() { panelDirty = true }
        if hub.loaded, !lookedForReleases { lookedForReleases = true; hub.lookForReleases() }
        if let panel {
            // the update mode comes and goes with the cable: looked for every second, not while it is in use
            if hub.busy == nil, now - portsAt > 1 { portsAt = now; hub.refreshPorts() }
            let wait = panelDirty ? 0 : panel.ui.animating || hub.busy != nil ? frameTime : 0.5
            if now - panelAt >= wait - 0.001 { paintPanel() }
            return panel.ui.animating || hub.busy != nil ? min(now + 0.016, panelAt + frameTime) : now + 0.016
        }
        noticeInTitle()
        // after the last change: long enough for the afterglow to go out, then rest until something changes
        let moving = !still || now - movedAt < 1.2
        let due = lastFrame + frameTime
        guard moving else { return now + 0.016 }
        if now >= due - 0.0005 { draw(now); return now + frameTime }
        return due
    }

    private func draw(_ now: Double, into dc: HDC? = nil) {
        let dt = lastFrame == 0 ? 1.0 / 120 : min(0.1, max(0.001, now - lastFrame))
        lastFrame = now
        counted += 1
        if now - countedSince >= 10 {
            if countedSince > 0, counted > 20 { Log.say("frames: \(Int(Double(counted) / (now - countedSince))) a second while moving (monitor: \(hz) Hz)") }
            (counted, countedSince) = (0, now)
        }
        let l = renderer.layout
        still = core.frame(l.w, l.h, time: now, dt: dt, into: &dots).still
        renderer.draw(dots, dt: dt)
        cost = cost == 0 ? DesktopCore.now() - now : cost * 0.95 + (DesktopCore.now() - now) * 0.05
        blit(dc)
        adapt()
    }

    private func blit(_ given: HDC? = nil) {
        guard let window else { return }
        let l = renderer.layout
        var bmi = BITMAPINFO()
        bmi.bmiHeader.biSize = DWORD(MemoryLayout<BITMAPINFOHEADER>.size)
        bmi.bmiHeader.biWidth = LONG(l.pxW)
        bmi.bmiHeader.biHeight = -LONG(l.pxH)                       // top row first
        bmi.bmiHeader.biPlanes = 1
        bmi.bmiHeader.biBitCount = 32
        bmi.bmiHeader.biCompression = 0                              // BI_RGB
        guard let dc = given ?? GetDC(window) else { return }
        renderer.pixels.withUnsafeBytes { p in
            if scale == 1 {
                _ = SetDIBitsToDevice(dc, 0, 0, DWORD(l.pxW), DWORD(l.pxH), 0, 0, 0, UINT(l.pxH), p.baseAddress, &bmi, 0)   // DIB_RGB_COLORS
            } else {
                SetStretchBltMode(dc, 3)                             // COLORONCOLOR: each pixel doubled, the dots stay sharp
                _ = StretchDIBits(dc, 0, 0, Int32(size.w), Int32(size.h), 0, 0, Int32(l.pxW), Int32(l.pxH), p.baseAddress, &bmi, 0, 0x00CC_0020)   // SRCCOPY
            }
        }
        if given == nil { ReleaseDC(window, dc) }
    }

    private func resized(_ hwnd: HWND?, _ w: Int, _ h: Int) {
        guard w > 0, h > 0 else { return }
        if size != (w, h) { cost = 0; sinceAdapt = 0 }                  // weighed again at the new size
        size = (w, h)
        if w * h > 8_500_000 { scale = 2 }                              // past 4K: half to begin with, `adapt` may go up
        else if size.w * size.h <= 1_500_000 { scale = 1 }
        renderer.resize(pxW: max(1, w / scale), pxH: max(1, h / scale))
        pointer.scale = Double(max(96, GetDpiForWindow(hwnd))) / 96 / Double(scale)     // `window` is not set yet at the first size
        movedAt = DesktopCore.now()
        still = false
        panelDirty = true
    }

    /// Full resolution while a frame is drawn in time for the monitor; every other window pixel (×2) when it is not.
    /// Weighed every 2 s or so of moving, with room either way so it does not go back and forth.
    private func adapt() {
        sinceAdapt += 1
        guard sinceAdapt >= max(60, hz * 2), cost > 0 else { return }
        sinceAdapt = 0
        let next = scale == 1 && cost > frameTime * 0.75 && size.w * size.h > 1_500_000 ? 2
                 : scale == 2 && cost * 3.5 < frameTime * 0.6 ? 1 : scale
        guard next != scale else { return }
        Log.say("frames take \(Int(cost * 10_000) / 10) ms at \(hz) Hz: drawing at \(next == 1 ? "full" : "half") resolution")
        scale = next
        cost = 0
        resized(window, size.w, size.h)
    }

    // MARK: what the window is told

    /// Settings has the mouse and the keys while it is open.
    private func handlePanel(_ panel: SettingsPanel, _ hwnd: HWND?, _ msg: UINT, _ w: WPARAM, _ l: LPARAM) -> LRESULT? {
        let p = POINT(x: Int32(Int16(truncatingIfNeeded: l)), y: Int32(Int16(truncatingIfNeeded: l >> 16)))
        switch msg {
        case UINT(WM_LBUTTONDOWN):
            SetCapture(hwnd)
            SetFocus(hwnd)
            panel.ui.press(p)
        case UINT(WM_MOUSEMOVE):
            panel.ui.mouse = p
            guard panel.ui.down else { return 0 }
        case UINT(WM_LBUTTONUP):
            panel.ui.release(p)                                      // first: letting the capture go says WM_CAPTURECHANGED, a cancel
            ReleaseCapture()
        case 0x020A:                                                 // WM_MOUSEWHEEL
            panel.ui.wheel(Int32(Int16(truncatingIfNeeded: w >> 16)))
        case 0x020E:                                                 // WM_MOUSEHWHEEL: no pages to turn here
            return 0
        case 0x0215, UINT(WM_CANCELMODE):                            // WM_CAPTURECHANGED
            if panel.ui.down { panel.ui.cancel() }
            return nil
        case UINT(WM_KEYDOWN):
            switch Int(w) {
            case 0x1B: if panel.escape() { closeSettings(); return 0 }       // Esc
            case 0x7A: fullScreen(windowed == nil)                           // F11
            case 0xBC where GetKeyState(0x11) < 0: closeSettings(); return 0  // Ctrl+,
            case 0x21: panel.ui.wheel(Int32(size.h) * 120 / max(1, panel.ui.px(48)) * 3 / 4)        // Page Up
            case 0x22: panel.ui.wheel(-Int32(size.h) * 120 / max(1, panel.ui.px(48)) * 3 / 4)       // Page Down
            default: return 0
            }
        default:
            return nil
        }
        panelDirty = true
        paintPanel()
        return 0
    }

    fileprivate func handle(_ hwnd: HWND?, _ msg: UINT, _ w: WPARAM, _ l: LPARAM) -> LRESULT? {
        switch msg {
        case 0x0010:                                                 // WM_CLOSE
            if hub.busy != nil {
                let t = Array("Galax-z is talking to the OP-Z's update mode. Wait for it to finish: half an OS does not start.".utf16) + [0]
                MessageBoxW(hwnd, t, Array("Galax-z".utf16) + [0], UINT(0x30))       // MB_ICONWARNING
                return 0
            }
            return nil
        case 0x0011:                                                 // WM_QUERYENDSESSION: not in the middle of a write
            return hub.busy != nil ? 0 : nil
        case 0x0133:                                                 // WM_CTLCOLOREDIT: the animation's name box
            if let panel, let dc = HDC(bitPattern: UInt(w)) { return panel.colorBox(dc) }
            return nil
        default: break
        }
        if let panel {
            switch msg {
            case UINT(WM_PAINT):
                var ps = PAINTSTRUCT()
                let dc = BeginPaint(hwnd, &ps)
                panelDirty = true
                paintPanel(dc)
                EndPaint(hwnd, &ps)
                return 0
            case UINT(WM_ERASEBKGND):
                return 1
            default:
                if let r = handlePanel(panel, hwnd, msg, w, l) { return r }
            }
        }
        let x = Double(Int16(truncatingIfNeeded: l)) / Double(scale), y = Double(Int16(truncatingIfNeeded: l >> 16)) / Double(scale)
        switch msg {
        case UINT(WM_SIZE):
            resized(hwnd, Int(l & 0xFFFF), Int((l >> 16) & 0xFFFF))
            return 0
        case UINT(WM_ERASEBKGND):
            return 1                                                 // the whole window is drawn: no flicker
        case UINT(WM_PAINT):
            var ps = PAINTSTRUCT()
            let dc = BeginPaint(hwnd, &ps)
            if renderer.pixels.count > 1 { draw(DesktopCore.now(), into: dc) }
            EndPaint(hwnd, &ps)
            return 0
        case 0x0231:                                                 // WM_ENTERSIZEMOVE
            SetTimer(hwnd, 1, UINT(max(10, Int(frameTime * 1000))), nil)  // Windows' own loop runs while a window is dragged
            return 0
        case 0x0232:                                                 // WM_EXITSIZEMOVE
            KillTimer(hwnd, 1)
            refreshRate()                                            // it may be on another monitor now
            return 0
        case 0x007E:                                                 // WM_DISPLAYCHANGE: a monitor's mode changed
            refreshRate()
            return nil
        case UINT(WM_TIMER):
            step()
            return 0
        case UINT(WM_LBUTTONDOWN):
            SetCapture(hwnd)
            pointer.down(x, y, renderer.layout)
            moved()
            return 0
        case UINT(WM_MOUSEMOVE):
            if pointer.held { pointer.move(x, y, renderer.layout); moved() }
            return 0
        case UINT(WM_LBUTTONUP):
            ReleaseCapture()
            act(pointer.up(x, y, renderer.layout))
            moved()
            return 0
        case 0x0215, UINT(WM_CANCELMODE), UINT(WM_KILLFOCUS):        // WM_CAPTURECHANGED too
            if pointer.held { pointer.cancel(); moved() }
            return nil
        case 0x020E:                                                 // WM_MOUSEHWHEEL: a sideways scroll turns the page
            let delta = Int16(truncatingIfNeeded: w >> 16)
            if delta != 0 { core.turn(delta > 0 ? 1 : -1); moved() }
            return 0
        case UINT(WM_KEYDOWN):
            key(Int(w))
            return 0
        case UINT(WM_SYSKEYDOWN) where w == 0x0D:                  // Alt+Enter: full screen, and back
            fullScreen(windowed == nil)
            return 0
        case 0x0106 where w == 0x0D:                                 // WM_SYSCHAR of it: no beep
            return 0
        case 0x0219:                                                 // WM_DEVICECHANGE: a USB device came or went
            midi.look(DesktopCore.now(), soon: true)
            return nil
        case 0x02E0:                                                 // WM_DPICHANGED: moved to another monitor
            refreshRate()
            // Windows suggests where the window goes at the new scale
            if let r = UnsafePointer<RECT>(bitPattern: Int(l)) {
                SetWindowPos(hwnd, nil, r.pointee.left, r.pointee.top, r.pointee.right - r.pointee.left, r.pointee.bottom - r.pointee.top,
                             UINT(SWP_NOZORDER | SWP_NOACTIVATE))
            }
            return 0
        case UINT(WM_DESTROY):
            PostQuitMessage(0)
            return 0
        default:
            return nil
        }
    }

    private func moved() { movedAt = DesktopCore.now(); still = false }

    private func key(_ k: Int) {
        switch k {
        case 0x25: core.turn(-1)                                     // ←
        case 0x27: core.turn(1)                                      // →
        case 0x26: core.selectTrack(-1)                              // ↑
        case 0x28: core.selectTrack(1)                               // ↓
        case 0x30...0x39: core.setPage((k - 0x30 + 9) % 10)          // 1 is the first page, 0 the tenth
        case 0x44: core.useDemo(!core.isDemo)                        // D: the demo OP-Z, on or off
        case 0x48: openSettings(.os)                                 // H: Galax-z OS
        case 0xBC where GetKeyState(0x11) < 0: openSettings(.general)    // Ctrl+,: Settings
        case 0x7A: fullScreen(windowed == nil)                       // F11
        case 0x1B: if windowed != nil { fullScreen(false) }          // Esc
        default: return
        }
        moved()
    }

    /// A tap asked the app for something: Settings, the installer; or for what this build does not have, said in the title.
    private func act(_ a: DesktopCore.Action) {
        switch a {
        case .none: return
        case .settings: openSettings(.general)
        case .hub: openSettings(.os)
        case .pair: openSettings(.general); panel?.openPairing()
        case .sound: say("The OP-Z's sound through this computer comes in a later Windows test build")
        }
    }

    private func say(_ text: String) {
        note = text
        guard let window else { return }
        let t = Array("Galax-z  ·  \(text)".utf16) + [0]
        SetWindowTextW(window, t)
    }

    /// A newer Galax-z OS than the OP-Z is known to have, in the title (the Mac shows it in the screen's corner).
    private func noticeInTitle() {
        guard let n = hub.notice, note.isEmpty || note.hasPrefix("NEW: ") || note.hasPrefix("NEW:"), note != n + "  (H)" else { return }
        say(n + "  (H)")
    }

    /// The refresh rate of the monitor the window is on (most of it), from Windows' display settings.
    private func refreshRate() {
        guard let window else { return }
        var info = MONITORINFOEXW()
        info.cbSize = DWORD(MemoryLayout<MONITORINFOEXW>.size)
        let monitor = MonitorFromWindow(window, DWORD(MONITOR_DEFAULTTONEAREST))
        let got = withUnsafeMutablePointer(to: &info) { $0.withMemoryRebound(to: MONITORINFO.self, capacity: 1) { GetMonitorInfoW(monitor, $0) } }
        var mode = DEVMODEW()
        mode.dmSize = WORD(MemoryLayout<DEVMODEW>.size)
        let device = withUnsafeBytes(of: info.szDevice) { Array($0.bindMemory(to: WCHAR.self)) }
        let ok = got && EnumDisplaySettingsW(device, DWORD.max, &mode)        // ENUM_CURRENT_SETTINGS
        // 0 or 1 mean "the hardware's default": 60 then; nothing above 500 is believed
        let rate = ok && mode.dmDisplayFrequency > 1 ? min(500, Int(mode.dmDisplayFrequency)) : 60
        guard rate != hz else { return }
        hz = rate
        frameTime = 1 / Double(rate)
        Log.say("monitor: \(rate) Hz: drawing up to \(rate) frames a second")
    }

    var isFullScreen: Bool { windowed != nil }

    /// The whole monitor, no frame (F11, Alt+Enter, Settings), remembered for the next start.
    func fullScreen(_ on: Bool) {
        defer { prefs[\.fullScreen] = windowed != nil; refreshRate(); panelDirty = true }
        guard let window else { return }
        if on {
            var mi = MONITORINFO()
            mi.cbSize = DWORD(MemoryLayout<MONITORINFO>.size)
            var r = RECT()
            guard GetWindowRect(window, &r), GetMonitorInfoW(MonitorFromWindow(window, DWORD(MONITOR_DEFAULTTONEAREST)), &mi) else { return }
            windowed = (GetWindowLongPtrW(window, GWL_STYLE), r)
            SetWindowLongPtrW(window, GWL_STYLE, windowed!.style & ~LONG_PTR(WS_OVERLAPPEDWINDOW))
            let m = mi.rcMonitor
            SetWindowPos(window, nil, m.left, m.top, m.right - m.left, m.bottom - m.top, UINT(SWP_NOZORDER | SWP_FRAMECHANGED))
        } else if let was = windowed {
            windowed = nil
            let r = was.rect
            SetWindowLongPtrW(window, GWL_STYLE, was.style)
            SetWindowPos(window, nil, r.left, r.top, r.right - r.left, r.bottom - r.top, UINT(SWP_NOZORDER | SWP_FRAMECHANGED))
        }
    }
}

/// The window's messages, to the app (a C function: Windows calls it).
private func windowProc(_ hwnd: HWND?, _ msg: UINT, _ w: WPARAM, _ l: LPARAM) -> LRESULT {
    if let app = App.shared, let r = app.handle(hwnd, msg, w, l) { return r }
    return DefWindowProcW(hwnd, msg, w, l)
}
#endif
