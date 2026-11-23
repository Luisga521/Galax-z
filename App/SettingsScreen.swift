import OPZLink
import SwiftUI

/// Where the OP-Z is heard.
private struct SoundCard: View {
    @Bindable var audio: AudioOut

    var body: some View {
        card {
            Text("PLAY THROUGH").font(Face.mono(9)).tracking(2).opacity(0.5)
            Picker("Play through", selection: $audio.out) {
                Text("OP-Z").tag(AudioOut.Out.opz)
                Text("THIS " + AudioOut.here).tag(AudioOut.Out.here)
            }
            .pickerStyle(.segmented)
            if audio.out == .here {
                HStack(spacing: 14) {
                    Text("VOLUME").font(Face.mono(9)).tracking(2).opacity(0.5).frame(width: 90, alignment: .leading)
                    Slider(value: $audio.volume, in: 0...1).tint(Face.yellow).accessibilityLabel("Volume")
                }
            }
            HStack(spacing: 10) {
                Circle().fill(light).frame(width: 8, height: 8)
                Text(audio.explained).font(Face.mono(11)).opacity(0.55).fixedSize(horizontal: false, vertical: true)
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

/// What has been heard from the OP-Z: a light for each thing the screen follows, and how to set it off.
private struct LinkCheckCard: View {
    let live: Live
    @State private var file: URL?
    @State private var failed: String?
    @Environment(\.horizontalSizeClass) private var width

    var body: some View {
        card {
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                let check = live.check, on = live.source == .demo || live.deviceName != nil
                VStack(alignment: .leading, spacing: 12) {
                    Text("LINK CHECK").font(Face.mono(13, .bold)).tracking(2)
                    Text(!on ? "What Galax-z hears from your OP-Z, once there is one."
                         : check.missing.isEmpty ? "Everything the screen follows has come." : "Set off what is not lit yet, with this open. SAVE keeps it as a file: it says what came and what did not.")
                        .font(Face.mono(11)).opacity(0.55).fixedSize(horizontal: false, vertical: true)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: width == .compact ? 280 : 330), spacing: 16, alignment: .leading)], alignment: .leading, spacing: 9) {
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
                .buttonStyle(PillButton())
                if let file { ShareLink(item: file) { Text("SHARE") }.buttonStyle(PillButton()) }
                Text(failed ?? (file == nil ? "" : "In Galax-z › Diagnostics: \(file!.lastPathComponent)")).font(Face.mono(10)).opacity(0.5)
            }
        }
    }
}

/// Everything that is not the OP-Z's screen, in one place.
struct SettingsScreen: View {
    let live: Live
    let hub: Hub
    @State var tab: Tab
    let keyTest: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var width

    enum Tab: String, CaseIterable, Identifiable { case general = "GENERAL", learn = "LEARN", os = "GALAX-Z OS"; var id: String { rawValue } }

    init(live: Live, hub: Hub, tab: Tab, keyTest: @escaping () -> Void) {
        (self.live, self.hub, self.keyTest) = (live, hub, keyTest)
        _tab = State(initialValue: tab)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                if width != .compact { DotText("SETTINGS", font: .big, dot: 1.8) }
                Picker("Settings", selection: $tab) { ForEach(Tab.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).disabled(hub.busy != nil)
                Button("DONE") { dismiss() }.buttonStyle(PillButton(fill: Face.yellow)).disabled(hub.busy != nil).keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, width == .compact ? 14 : 26).padding(.top, top).padding(.bottom, 10)
            .frame(maxWidth: 1180)
            switch tab {
            case .general: GeneralSettings(live: live, keyTest: keyTest)
            case .learn: LearnScreen(controllers: live.controllers)
            case .os: HubScreen(hub: hub, live: live)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Face.background.ignoresSafeArea())
        .foregroundStyle(Face.ink)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(hub.busy != nil)
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

/// How it looks, where it is heard, the demo, backups, the key test.
private struct GeneralSettings: View {
    let live: Live
    let keyTest: () -> Void
    @Environment(\.horizontalSizeClass) private var width
    @AppStorage("fineness") private var fineness = 240
    @AppStorage("glow") private var glow = 0.8
    @AppStorage("afterglow") private var afterglow = 0.3
    @AppStorage("lookForReleases") private var lookForReleases = true

    /// The newest backup there is, and how many.
    @State private var saved: (manifest: Backups.Manifest, count: Int)?
    @State private var looked = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section("SCREEN")
                card {
                    Text("DOTS").font(Face.mono(9)).tracking(2).opacity(0.5)
                    Picker("Dots", selection: $fineness) {
                        Text("BOLD").tag(190); Text("CLASSIC").tag(240); Text("FINE").tag(300)
                    }
                    .pickerStyle(.segmented)
                    slider("GLOW", $glow)
                    slider("AFTERGLOW", $afterglow)
                }
                section("SOUND")
                SoundCard(audio: live.audio)
                section("OP-Z")
                row("DEMO OP-Z", "A pretend OP-Z playing a song: every screen works with no unit attached.") {
                    Toggle("Demo OP-Z", isOn: Binding(get: { live.source == .demo }, set: { live.useDemo($0) })).labelsHidden().tint(Face.yellow)
                }
                row("BACKUPS", backupDetail) {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("AUTOMATIC").font(Face.mono(9)).tracking(2).opacity(0.45)
                        Toggle("Automatic backups", isOn: Binding(get: { live.autoBackup }, set: { live.autoBackup = $0 })).labelsHidden().tint(Face.yellow)
                    }
                    Button(running ? "BACKING UP…" : "BACK UP NOW") { live.backUpNow() }
                        .buttonStyle(PillButton())
                        .disabled(running || live.source != .opz || live.deviceName == nil)
                }
                row("KEY TEST", "Finds keys that double-trigger: every press timed from its MIDI note.") {
                    Button("OPEN", action: keyTest).buttonStyle(PillButton())
                }
                LinkCheckCard(live: live)
                row("LOOK FOR NEW VERSIONS", "Asks GitHub for the list of releases when the app opens. Nothing about you or your OP-Z is sent.") {
                    Toggle("Look for new versions", isOn: $lookForReleases).labelsHidden().tint(Face.yellow)
                }
                section("KEYS")
                Text("1–0 pages · ← → turn · ↑ ↓ track · H Galax-z OS · ⌘, settings").font(Face.mono(11)).opacity(0.55)
                section("CREDITS")
                CreditsCard()
                Text("Galax-z is not affiliated with teenage engineering. OP-Z is their trademark. Galax-z OS is installed at your own risk.").font(Face.mono(10)).opacity(0.35).padding(.top, 8)
            }
            .padding(26)
            .frame(maxWidth: 860).frame(maxWidth: .infinity)
        }
        .background(Face.background.ignoresSafeArea())
        .foregroundStyle(Face.ink)
        .preferredColorScheme(.dark)
        .task(id: live.backup) {
            if case .running = live.backup { return }
            let all = await Task.detached { Backups.all().map(\.1) }.value
            saved = all.first.map { ($0, all.count) }
            looked = true
        }
    }

    private func section(_ s: String) -> some View { DotText(s, font: .tiny, dot: 2, color: Face.yellow).padding(.top, 8) }

    private func slider(_ name: String, _ v: Binding<Double>) -> some View {
        HStack(spacing: 14) {
            Text(name).font(Face.mono(9)).tracking(2).opacity(0.5).frame(width: 90, alignment: .leading)
            Slider(value: v, in: 0...1.5).tint(Face.yellow).accessibilityLabel(name.capitalized)
        }
    }

    private var running: Bool { if case .running = live.backup { true } else { false } }

    /// When the last one was, and where they are.
    private var backupDetail: String {
        var line = "Copies the OP-Z's 10 projects and sound settings, reading only: seconds by cable, minutes over Bluetooth. In Files › Galax-z › Backups, "
            + "laid out like the OP-Z's disk: put one back in content mode."
        switch live.backup {
        case .running(let n): line += "\nNOW: project \(n + 1) of 10…"
        case .failed(let why): line += "\nLAST TRY FAILED: \(why)"
        default: break
        }
        if let (m, count) = saved {
            line += "\nNEWEST: \(m.taken.formatted(date: .abbreviated, time: .shortened))"
                + " · STILL MATCHED \(m.checked.formatted(date: .omitted, time: .shortened)) · \(count) KEPT"
        } else if looked {
            line += "\nNONE YET ON THIS DEVICE."
        }
        return line
    }

    private func row<Control: View>(_ title: String, _ detail: String, @ViewBuilder _ control: () -> Control) -> some View {
        let text = VStack(alignment: .leading, spacing: 5) {
            Text(title).font(Face.mono(13, .bold)).tracking(2)
            Text(detail).font(Face.mono(11)).opacity(0.55).fixedSize(horizontal: false, vertical: true)
        }
        let c = control()
        return card {
            if width == .compact, title == "BACKUPS" {
                VStack(alignment: .leading, spacing: 12) { text; HStack(spacing: 16) { c } }
            } else {
                HStack(spacing: 16) { text; Spacer(minLength: 8); c }
            }
        }
    }
}
