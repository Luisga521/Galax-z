import OPZLink
import SwiftUI

/// Everything that is not the OP-Z's screen: a list of sections, beside the page on a wide screen, pushing into it on a narrow one.
struct SettingsScreen: View {
    let live: Live
    let hub: Hub
    let keyTest: () -> Void
    /// The section beside the list (wide).
    @State private var tab: Tab
    /// The sections pushed (narrow): empty is the list itself.
    @State private var path: [Tab]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var width

    enum Tab: String, CaseIterable, Identifiable, Hashable {
        /// Settings as a whole: the list on a phone, DISPLAY beside it on a wide screen.
        case general
        case display, sound, opz, backups, learn, bridge, os, shortcuts, about
        var id: String { rawValue }

        /// The sections in the list. The bridge is the Mac's for now.
        #if targetEnvironment(macCatalyst)
        static let shown: [Tab] = [.display, .sound, .opz, .backups, .learn, .bridge, .os, .shortcuts, .about]
        #else
        static let shown: [Tab] = [.display, .sound, .opz, .backups, .learn, .os, .shortcuts, .about]
        #endif

        var name: String {
            switch self {
            case .general: "SETTINGS"
            case .display: "DISPLAY"
            case .sound: "SOUND"
            case .opz: "OP-Z"
            case .backups: "BACKUPS"
            case .learn: "CONTROLLERS"
            case .bridge: "BRIDGE"
            case .os: "GALAX-Z OS"
            case .shortcuts: "SHORTCUTS"
            case .about: "ABOUT"
            }
        }

        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .display: "circle.grid.3x3.fill"
            case .sound: "speaker.wave.2.fill"
            case .opz: "pianokeys"
            case .backups: "externaldrive.fill"
            case .learn: "slider.horizontal.3"
            case .bridge: "cable.connector"
            case .os: "cpu"
            case .shortcuts: "keyboard"
            case .about: "info.circle"
            }
        }

        /// One line under the name.
        var line: String {
            switch self {
            case .general: ""
            case .display: "Dots, glow and afterglow."
            case .sound: "Where the OP-Z is heard."
            case .opz: "Connection, demo, troubleshooting."
            case .backups: "Copies of your projects and sounds."
            case .learn: "Teach a MIDI controller what to do."
            case .bridge: "Controllers on this Mac, played into the OP-Z."
            case .os: "Install and update Galax-z OS."
            case .shortcuts: "Keys and OP-Z combinations."
            case .about: "Versions, updates, credits."
            }
        }
    }

    init(live: Live, hub: Hub, tab: Tab, keyTest: @escaping () -> Void) {
        (self.live, self.hub, self.keyTest) = (live, hub, keyTest)
        _tab = State(initialValue: tab == .general ? .display : tab)
        _path = State(initialValue: tab == .general ? [] : [tab])
    }

    var body: some View {
        Group {
            if width == .compact { narrow } else { wide }
        }
        .background(Face.background.ignoresSafeArea())
        .foregroundStyle(Face.ink)
        .tint(Face.yellow)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(hub.busy != nil)
    }

    private var busy: Bool { hub.busy != nil }

    private var done: some View {
        Button("DONE") { dismiss() }.buttonStyle(TallPill(fill: Face.yellow)).disabled(busy).keyboardShortcut(.cancelAction)
    }

    // MARK: Wide: the list beside the page

    private var wide: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                DotText("SETTINGS", font: .big, dot: 1.8)
                Spacer()
                done
            }
            .padding(.horizontal, 26).padding(.top, top).padding(.bottom, 10)
            HStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 4) { ForEach(Tab.shown) { t in sidebarRow(t) } }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                }
                .frame(width: 250)
                .disabled(busy)
                Rectangle().fill(Face.ink.opacity(0.08)).frame(width: 1)
                VStack(alignment: .leading, spacing: 0) {
                    if tab != .os {
                        VStack(alignment: .leading, spacing: 8) {
                            DotText(tab.name, font: .small, dot: 2.2, color: Face.yellow)
                            Text(tab.line).font(Face.mono(11)).opacity(0.55)
                        }
                        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 4)
                    }
                    page(tab).id(tab)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func sidebarRow(_ t: Tab) -> some View {
        let on = tab == t
        return Button { tab = t } label: {
            HStack(spacing: 12) {
                Image(systemName: t.symbol).font(.system(size: 15, weight: .semibold)).frame(width: 24)
                Text(t.name).font(Face.mono(12, .bold)).tracking(2)
                Spacer(minLength: 0)
                badge(t)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .foregroundStyle(on ? Face.yellow : Face.ink.opacity(0.85))
            .background(on ? Face.yellow.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .opacity(busy && !on ? 0.4 : 1)
    }

    /// Writing, or a new version: on GALAX-Z OS's row.
    @ViewBuilder private func badge(_ t: Tab) -> some View {
        if t == .os {
            if busy {
                ProgressView().controlSize(.small)
            } else if let r = hub.newest, hub.isNews(r.label), !hub.isOn(r.label) {
                Text("NEW").font(Face.mono(9, .bold)).tracking(1).foregroundStyle(Face.background)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Face.yellow, in: Capsule())
            }
        }
    }

    // MARK: Narrow: a list that pushes

    private var narrow: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Tab.shown) { t in
                        NavigationLink(value: t) {
                            HStack(spacing: 14) {
                                Image(systemName: t.symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(Face.yellow).frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(t.name).font(Face.mono(13, .bold)).tracking(2)
                                    Text(t.line).font(Face.mono(10)).opacity(0.5).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                badge(t)
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).opacity(0.35)
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 56)
                            .background(Face.panel, in: RoundedRectangle(cornerRadius: 12))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .disabled(busy)
            .background(Face.background.ignoresSafeArea())
            .bar("SETTINGS") { done }
            .navigationDestination(for: Tab.self) { t in
                page(t)
                    .background(Face.background.ignoresSafeArea())
                    .navigationBarBackButtonHidden(busy)
                    .bar(t.name) { done }
            }
        }
    }

    @ViewBuilder private func page(_ t: Tab) -> some View {
        switch t {
        case .general, .display: DisplaySection()
        case .sound: SoundCard(audio: live.audio)
        case .opz: OPZSection(live: live, keyTest: keyTest)
        case .backups: BackupsSection(live: live)
        case .learn: LearnScreen(controllers: live.controllers)
        case .bridge: BridgeScreen(live: live)
        case .os: HubScreen(hub: hub, live: live)
        case .shortcuts: ShortcutsSection()
        case .about: AboutSection(hub: hub)
        }
    }

    /// Clear of the Mac window's buttons.
    private var top: CGFloat {
        #if targetEnvironment(macCatalyst)
        34
        #else
        14
        #endif
    }
}

private extension View {
    /// The narrow layout's bar: dark, the name in dots, DONE on the right.
    func bar<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        let t = trailing()
        return self
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Face.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) { DotText(title, font: .small, dot: 1.6) }
                ToolbarItem(placement: .topBarTrailing) { t }
            }
    }
}

// MARK: - Pieces

/// The app's pill, at least 44 points tall to touch, dimmed when it can't be pressed.
private struct TallPill: ButtonStyle {
    var fill: Color? = nil
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        PillButton(fill: fill).makeBody(configuration: configuration)
            .opacity(enabled ? 1 : 0.4)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

/// A page of settings: cards down a column.
private struct Page<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) { content }
                .padding(.horizontal, 20).padding(.vertical, 14)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A heading inside a page.
private struct Heading: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { DotText(text, font: .tiny, dot: 2, color: Face.yellow).padding(.top, 10) }
}

/// Small caps over a control.
private struct Caption: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(Face.mono(10)).tracking(2).opacity(0.55) }
}

/// The (i) that opens the longer story.
private struct InfoButton: View {
    @Binding var open: Bool
    let about: String

    var body: some View {
        Button { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } } label: {
            Image(systemName: open ? "info.circle.fill" : "info.circle")
                .font(.system(size: 16))
                .foregroundStyle(open ? Face.yellow : Face.ink.opacity(0.5))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More about \(about.lowercased())")
    }
}

/// The longer story, once (i) is touched.
private struct More: View {
    let text: String
    var body: some View {
        Text(text).font(Face.mono(11)).opacity(0.7).fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Face.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            .transition(.opacity)
    }
}

/// One setting: its name, one short line, what changes it, and the longer story behind (i).
private struct Row<Control: View>: View {
    let title: String
    let line: String
    var more: String?
    let control: Control
    @State private var open = false

    init(_ title: String, _ line: String, more: String? = nil, @ViewBuilder control: () -> Control) {
        (self.title, self.line, self.more, self.control) = (title, line, more, control())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(Face.mono(13, .bold)).tracking(2)
                    Text(line).font(Face.mono(11)).opacity(0.55).fixedSize(horizontal: false, vertical: true)
                }
                if more != nil { InfoButton(open: $open, about: title) }
                Spacer(minLength: 8)
                control
            }
            .frame(minHeight: 44)
            if open, let more { More(text: more) }
        }
    }
}

extension Row where Control == EmptyView {
    init(_ title: String, _ line: String, more: String? = nil) {
        self.init(title, line, more: more) { EmptyView() }
    }
}

/// A slider with its value beside it.
private struct Level: View {
    let name: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1.5

    var body: some View {
        HStack(spacing: 14) {
            Caption(name).frame(width: 96, alignment: .leading)
            Slider(value: $value, in: range).accessibilityLabel(name.capitalized).accessibilityValue(shown)
            Text(shown).font(Face.mono(11, .bold)).monospacedDigit().frame(width: 46, alignment: .trailing)
        }
        .frame(minHeight: 44)
    }

    private var shown: String { value < 0.005 ? "OFF" : "\(Int((value * 100).rounded()))%" }
}

/// A key or a combination, and what it does.
private struct Combo: View {
    let keys: String
    let does: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) { cap.frame(width: 200, alignment: .leading); text }
            VStack(alignment: .leading, spacing: 6) { cap; text }
        }
        .frame(minHeight: 36, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var cap: some View {
        Text(keys).font(Face.mono(11, .bold)).tracking(1).lineLimit(1).fixedSize()
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Face.ink.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }

    private var text: some View { Text(does).font(Face.mono(11)).opacity(0.75).fixedSize(horizontal: false, vertical: true) }
}

// MARK: - DISPLAY

private struct DisplaySection: View {
    @AppStorage("fineness") private var fineness = 240
    @AppStorage("glow") private var glow = DotDisplay.Look.defaultGlow
    @AppStorage("afterglow") private var afterglow = DotDisplay.Look.defaultAfterglow

    var body: some View {
        Page {
            Swatch(fineness: fineness, glow: glow, afterglow: afterglow)
            card {
                Caption("DOTS")
                Picker("Dots", selection: $fineness) {
                    Text("BOLD").tag(190); Text("CLASSIC").tag(240); Text("FINE").tag(300)
                }
                .pickerStyle(.segmented).controlSize(.large).frame(minHeight: 44)
                Level(name: "GLOW", value: $glow)
                Level(name: "AFTERGLOW", value: $afterglow)
                HStack(spacing: 0) {
                    Text("Glow is the light around a dot; afterglow, how long it lingers.").font(Face.mono(10)).opacity(0.45)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button("CRISP") { (glow, afterglow) = (0, 0) }.buttonStyle(TallPill())
                        .disabled(glow == 0 && afterglow == 0)
                    Spacer(minLength: 8).frame(maxWidth: 8)
                    Button("RESET") { (fineness, glow, afterglow) = (240, DotDisplay.Look.defaultGlow, DotDisplay.Look.defaultAfterglow) }.buttonStyle(TallPill())
                        .disabled(fineness == 240 && glow == DotDisplay.Look.defaultGlow && afterglow == DotDisplay.Look.defaultAfterglow)
                }
            }
        }
    }
}

/// A few dots going by, drawn the way the screen draws them: pitch from the fineness, a blurred halo for the glow, a fading trail for the afterglow.
private struct Swatch: View {
    let fineness: Int
    let glow: Double
    let afterglow: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { g, size in
                let pitch = 9.0 * 240 / Double(fineness)
                let cols = max(1, Int(size.width / pitch)), rows = max(1, Int(size.height / pitch))
                let x0 = (size.width - Double(cols) * pitch) / 2, y0 = (size.height - Double(rows) * pitch) / 2
                func cell(_ x: Int, _ y: Int, _ grow: Double = 0) -> CGRect {
                    CGRect(x: x0 + Double(x) * pitch, y: y0 + Double(y) * pitch, width: pitch, height: pitch).insetBy(dx: pitch * (0.12 - grow), dy: pitch * (0.12 - grow))
                }
                var unlit = Path()
                for y in 0..<rows { for x in 0..<cols { unlit.addEllipse(in: cell(x, y)) } }
                g.fill(unlit, with: .color(Face.ink.opacity(0.06)))

                // a wave drawn left to right, 24 columns a second; the same half-life as the screen's afterglow
                let speed = 24.0, half = 0.012 + afterglow * 0.06
                let head = (t * speed).truncatingRemainder(dividingBy: Double(cols + 12))
                var lit: [(CGRect, Double)] = []
                for x in 0..<cols {
                    let age = (head - Double(x)) / speed
                    guard age >= 0 else { continue }
                    let a = afterglow <= 0 ? (age < 1 / speed ? 1 : 0) : pow(0.5, age / half)
                    guard a > 0.02 else { continue }
                    let y = Int((Double(rows - 1) / 2 * (1 + 0.8 * sin(Double(x) * 0.45))).rounded())
                    lit.append((cell(x, y), a))
                }
                if glow > 0 {
                    g.drawLayer { l in
                        l.addFilter(.blur(radius: pitch * 0.9))
                        for (r, a) in lit { l.fill(Path(ellipseIn: r.insetBy(dx: -pitch * 0.25, dy: -pitch * 0.25)), with: .color(Face.ink.opacity(a * min(1, glow * 0.7)))) }
                    }
                }
                for (r, a) in lit { g.fill(Path(ellipseIn: r), with: .color(Face.ink.opacity(a))) }
            }
        }
        .frame(height: 96)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .topLeading) { Caption("PREVIEW").padding(10) }
        .accessibilityHidden(true)
    }
}

// MARK: - SOUND

/// Where the OP-Z is heard.
private struct SoundCard: View {
    @Bindable var audio: AudioOut
    @State private var open = false

    var body: some View {
        Page {
            card {
                HStack(spacing: 6) {
                    Caption("PLAY THROUGH")
                    InfoButton(open: $open, about: "Play through")
                }
                Picker("Play through", selection: $audio.out) {
                    Text("OP-Z").tag(AudioOut.Out.opz)
                    Text("THIS " + AudioOut.here).tag(AudioOut.Out.here)
                }
                .pickerStyle(.segmented).controlSize(.large).frame(minHeight: 44)
                if audio.out == .here { Level(name: "VOLUME", value: $audio.volume, range: 0...1) }
                HStack(spacing: 10) {
                    Circle().fill(light).frame(width: 8, height: 8)
                    Text(audio.explained).font(Face.mono(11)).opacity(0.6).fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 28)
                if audio.out == .here, Microphone.denied {        // the system will not ask again: only its settings can
                    Button("ALLOW THE MICROPHONE") { Microphone.openSettings() }.buttonStyle(PillButton(fill: Face.yellow))
                }
                if open {
                    More(text: "Through this \(AudioOut.here) needs the USB cable: Bluetooth carries no sound. The system asks for the microphone, as it does "
                         + "for any sound coming in; only the OP-Z's is used. Nothing is recorded unless you touch RECORD on CHOPS, and it is never sent back to the OP-Z. "
                         + "OUT at the top of the screen switches this too.")
                }
            }
        }
    }

    private var light: Color {
        switch audio.state {
        case .playing: Face.green
        case .failed: Color(hex: 0xFF4A2E)
        case .waiting: Face.yellow
        case .off: Face.ink.opacity(0.2)
        }
    }
}

// MARK: - OP-Z

private struct OPZSection: View {
    let live: Live
    let keyTest: () -> Void
    @State private var pairing = false

    var body: some View {
        Page {
            card {
                let c = connection
                HStack(spacing: 12) {
                    Circle().fill(c.light).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(c.title).font(Face.mono(13, .bold)).tracking(2).lineLimit(1).minimumScaleFactor(0.7)
                        Text(c.detail).font(Face.mono(11)).opacity(0.55).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    if live.source == .opz, live.deviceName == nil {
                        Button("PAIR") { pairing = true }.buttonStyle(TallPill())
                    }
                }
                .frame(minHeight: 44)
                .accessibilityElement(children: .contain)
                if live.deviceName != nil, live.midiIn == false {
                    Text("ITS MIDI IN IS OFF: hold TEMPO + SCREEN, then key 2. Touching the app needs it.")
                        .font(Face.mono(11)).foregroundStyle(Face.yellow).fixedSize(horizontal: false, vertical: true)
                }
                Divider().overlay(Face.ink.opacity(0.08))
                Row("DEMO OP-Z", "A pretend OP-Z plays a song.",
                    more: "Every screen works with no unit attached. Switch it off to follow your own OP-Z again.") {
                    Toggle("Demo OP-Z", isOn: Binding(get: { live.source == .demo }, set: { live.useDemo($0) })).labelsHidden()
                }
            }
            Heading("TROUBLESHOOTING")
            card {
                Row("KEY TEST", "Find keys that double-trigger.",
                    more: "Every press is timed from its MIDI note, so a key that sends two presses for one shows up.") {
                    Button("OPEN", action: keyTest).buttonStyle(TallPill())
                }
            }
            LinkCheckCard(live: live)
        }
        .sheet(isPresented: $pairing) { BluetoothPairing() }
        .onChange(of: live.deviceName) { _, name in if name != nil { pairing = false } }
    }

    private var connection: (title: String, detail: String, light: Color) {
        let dim = Face.ink.opacity(0.25)
        if live.source == .demo { return ("DEMO OP-Z", "A pretend OP-Z is playing. Switch DEMO off for yours.", Face.yellow) }
        if let name = live.deviceName {
            let by = switch live.transport { case .usb?: "a USB cable"; case .bluetooth?: "Bluetooth"; default: "MIDI" }
            switch live.status {
            case .live: return (name.uppercased(), "Linked by \(by).", Face.green)
            case .hello, .loading: return (name.uppercased(), "Reading the project, by \(by)…", Face.yellow)
            case .lost: return (name.uppercased(), "Lost. Is it switched on? Is TE's app closed?", Color(hex: 0xFF4A2E))
            case .noOPZ: break
            }
        }
        switch live.bluetooth {
        case .searching: return ("NO OP-Z YET", "Looking over Bluetooth… or plug in a cable.", Face.yellow)
        case .connecting(let n): return (n.uppercased(), "Connecting over Bluetooth…", Face.yellow)
        case .linked(let n): return (n.uppercased(), "Linked over Bluetooth.", Face.green)
        case .off: return ("NO OP-Z", "Bluetooth is off. Plug in a cable, or switch Bluetooth on.", dim)
        case .unauthorized: return ("NO OP-Z", "Galax-z may not use Bluetooth. Plug in a cable, or allow it in Settings.", dim)
        case .unsupported, .idle: return ("NO OP-Z", "Plug it in with a USB-C cable, or pair it over Bluetooth. Close TE's app first.", dim)
        }
    }
}

/// What has been heard from the OP-Z: a light for each thing the screen follows, and how to set it off.
private struct LinkCheckCard: View {
    let live: Live
    @State private var file: URL?
    @State private var failed: String?
    @State private var open = false
    @Environment(\.horizontalSizeClass) private var width

    var body: some View {
        card {
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                let check = live.check, on = live.source == .demo || live.deviceName != nil
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LINK CHECK").font(Face.mono(13, .bold)).tracking(2)
                            Text(!on ? "Connect an OP-Z to see what comes in." : check.missing.isEmpty ? "Everything the screen follows has come in." : "Set off what isn't lit yet.")
                                .font(Face.mono(11)).opacity(0.55).fixedSize(horizontal: false, vertical: true)
                        }
                        InfoButton(open: $open, about: "Link check")
                    }
                    .frame(minHeight: 44)
                    if open {
                        More(text: "Each light is something the screen follows; it lights once it has come from your OP-Z, with how to set off the rest beside it. "
                             + "If something on the screen does not follow, SAVE a file and send it along: it says what came and what did not, with the first few "
                             + "messages of each kind. No project or sounds.")
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: width == .compact ? 280 : 300), spacing: 16, alignment: .leading)], alignment: .leading, spacing: 9) {
                        ForEach(LinkCheck.Item.allCases, id: \.rawValue) { i in
                            let n = check.count(i)
                            HStack(spacing: 10) {
                                Circle().fill(n > 0 ? Face.green : Face.ink.opacity(i.optional ? 0.1 : 0.25)).frame(width: 8, height: 8)
                                Text(i.name).font(Face.mono(10, .bold)).tracking(1).opacity(n > 0 ? 0.95 : 0.6)
                                Text(n > 0 ? "\(n)" : i.how).font(Face.mono(10)).opacity(0.45).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(i.name.lowercased()): \(n > 0 ? "heard" : "not yet, \(i.how)")")
                        }
                    }
                }
            }
            HStack(spacing: 12) {
                Button("SAVE") {
                    do { file = try live.saveCheck(); failed = nil } catch { failed = error.localizedDescription }
                }
                .buttonStyle(TallPill())
                if let file { ShareLink(item: file) { Text("SHARE") }.buttonStyle(TallPill()) }
                Text(failed ?? (file == nil ? "" : "In Galax-z › Diagnostics: \(file!.lastPathComponent)")).font(Face.mono(10)).opacity(0.5)
            }
        }
    }
}

// MARK: - BACKUPS

private struct BackupsSection: View {
    let live: Live
    /// The newest backup there is, and how many.
    @State private var saved: (manifest: Backups.Manifest, count: Int)?
    @State private var looked = false

    var body: some View {
        Page {
            card {
                Row("BACK UP NOW", state,
                    more: "Copies the OP-Z's 10 projects and sound settings, reading only: seconds by cable, minutes over Bluetooth. They are kept in "
                        + "Files › Galax-z › Backups (on the Mac, the app's Documents), laid out like the OP-Z's own disk: to put one back, copy it over in "
                        + "content mode (hold TRACK while switching on).") {
                    Button(running ? "BACKING UP…" : "BACK UP") { live.backUpNow() }
                        .buttonStyle(TallPill())
                        .disabled(running || live.source != .opz || live.deviceName == nil)
                }
                Divider().overlay(Face.ink.opacity(0.08))
                Row("AUTOMATIC", "Back up each time the OP-Z is plugged in.") {
                    Toggle("Automatic backups", isOn: Binding(get: { live.autoBackup }, set: { live.autoBackup = $0 })).labelsHidden()
                }
            }
            if let (m, count) = saved {
                card {
                    Caption("NEWEST")
                    Text(m.taken.formatted(date: .abbreviated, time: .shortened)).font(Face.mono(13, .bold))
                    Text("Still matched the OP-Z at \(m.checked.formatted(date: .omitted, time: .shortened)) · \(count) kept").font(Face.mono(11)).opacity(0.55)
                }
            }
        }
        .task(id: live.backup) {
            if case .running = live.backup { return }
            let all = await Task.detached { Backups.all().map(\.1) }.value
            saved = all.first.map { ($0, all.count) }
            looked = true
        }
    }

    private var running: Bool { if case .running = live.backup { true } else { false } }

    /// What is happening, in one line.
    private var state: String {
        switch live.backup {
        case .running(let n): return "Now: project \(n + 1) of 10…"
        case .failed(let why): return "Last try failed: \(why)"
        default: break
        }
        if live.source != .opz || live.deviceName == nil { return "Connect your OP-Z to back it up." }
        return saved == nil && looked ? "None yet on this device." : "Copies your projects and sounds, reading only."
    }
}

// MARK: - SHORTCUTS

private struct ShortcutsSection: View {
    var body: some View {
        Page {
            Heading("KEYBOARD").padding(.top, -10)
            card {
                Combo(keys: "1 – 0", does: "Go to a page")
                Combo(keys: "← →", does: "Previous or next page")
                Combo(keys: "↑ ↓", does: "Previous or next track")
                Combo(keys: "H", does: "Galax-z OS")
                Combo(keys: "⌘ ,", does: "Settings")
                Combo(keys: "ESC", does: "Close settings")
            }
            Heading("ON THE OP-Z")
            card {
                Combo(keys: "SCREEN + GREEN DIAL", does: "Hold SCREEN and turn the green dial: move through the app's pages")
                Combo(keys: "SCREEN + BLUE DIAL", does: "The OP-Z's parameter pages, both ways (Galax-z OS v14)")
                Combo(keys: "TEMPO + SCREEN, 2", does: "Let MIDI in: touching MIX, PLAY and PERFORM needs it")
                Combo(keys: "SHIFT, THEN SCREEN", does: "Send the load figures to the LOAD page (v8)")
            }
            Text("Every OP-Z combination with Galax-z OS is in SHORTCUTS.md, in the Galax-z repository.").font(Face.mono(10)).opacity(0.4)
        }
    }
}

// MARK: - ABOUT

private struct AboutSection: View {
    let hub: Hub
    @AppStorage("lookForReleases") private var lookForReleases = true

    var body: some View {
        Page {
            card {
                Row("GALAX-Z", "Version \(version)")
                Divider().overlay(Face.ink.opacity(0.08))
                Row("GALAX-Z OS", installed)
                Divider().overlay(Face.ink.opacity(0.08))
                Row("LOOK FOR NEW VERSIONS", "Check GitHub when the app opens.",
                    more: "Asks GitHub for the list of releases when the app opens. Nothing about you or your OP-Z is sent. A new one lights up in the corner.") {
                    Toggle("Look for new versions", isOn: $lookForReleases).labelsHidden()
                }
            }
            CreditsCard()
            Text("Galax-z is not affiliated with teenage engineering. OP-Z is their trademark. Galax-z OS is installed at your own risk.")
                .font(Face.mono(10)).opacity(0.4).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
        }
    }

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return b.map { "\(v) (\($0))" } ?? v
    }

    private var installed: String {
        if let i = hub.installed { return "On your OP-Z: \(hub.titleOf(i))" }
        if let k = hub.lastKnown { return "On your OP-Z, when last read: \(hub.titleOf(k))" }
        return "Not read from your OP-Z yet."
    }
}
