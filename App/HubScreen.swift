import OPZFirmware
import SwiftUI
import UniformTypeIdentifiers

/// The hub: what is on the OP-Z, the newest Galax-z, how to put it there step by step, the way back, the boot animation.
struct HubScreen: View {
    let hub: Hub
    let live: Live
    @State private var importing = false
    @State private var showAll = false
    @State private var showLog = false
    @Environment(\.horizontalSizeClass) private var width

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                bar
                if let problem = hub.problem { warning(problem) }
                if hub.busy == nil, let what = hub.interrupted {
                    warning("WRITING \(what.uppercased()) DID NOT FINISH. Don't switch the OP-Z on normally. Switch it off, hold SCREEN, switch it on, "
                            + "press READ, and install TE's original (under OTHER VERSIONS). After that, any version.")
                }
                if hub.mustPowerCycle {
                    HStack(spacing: 14) {
                        Text("Switch the OP-Z off (the cable out is not enough: it has a battery).").font(Face.mono(11)).opacity(0.8)
                        Button("I SWITCHED IT OFF") { hub.switchedOff() }.buttonStyle(PillButton(fill: Face.yellow)).disabled(!hub.ports.isEmpty)
                    }
                }
                if let r = hub.newest { newest(r) }
                card {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("CHIME WHEN THE OP-Z IS SWITCHED ON").font(Face.mono(12, .bold))
                            Text(hub.chimeDiffers ? "Install it again for this: the OP-Z keeps it, not the app." : "Two Quindar tones are its start sound, at the OP-Z's own volume. Off: none. It goes with the version when that is installed.")
                                .font(Face.mono(10)).opacity(0.6).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Toggle("Chime when the OP-Z is switched on", isOn: Binding(get: { hub.chime }, set: { hub.chime = $0 })).labelsHidden().tint(Face.yellow).disabled(hub.busy != nil)
                    }
                }
                if Hub.canFlash { steps } else { ipad }
                working
                versions
                DotText("BOOT ANIMATION", font: .tiny, dot: 2, color: Face.yellow).padding(.top, 10)
                AnimationLibrary(hub: hub)
                if !hub.log.isEmpty { logView }
            }
            .padding(.horizontal, width == .compact ? 16 : 28).padding(.vertical, 24)
            .frame(maxWidth: 1180).frame(maxWidth: .infinity)
        }
        .task(id: live.backup) { await hub.lookForBackup() }
        .background(Face.background.ignoresSafeArea())
        .foregroundStyle(Face.ink)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(hub.busy != nil)
        .fileImporter(isPresented: $importing, allowedContentTypes: [Hub.releaseType, .json, .data]) { r in
            if case .success(let url) = r { hub.open(url) }
        }
        .task { while !Task.isCancelled { if hub.busy == nil { hub.refreshPorts() }; try? await Task.sleep(for: .seconds(1)) } }
    }

    private var bar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) { name; Spacer(minLength: 12); buttons }
            VStack(alignment: .leading, spacing: 14) { name; buttons }
            VStack(alignment: .leading, spacing: 14) { DotText("HUB", font: .big, dot: 2.2); Text(installedLine).font(Face.mono(10)).opacity(0.6); buttons }
        }
    }

    private var name: some View {
        VStack(alignment: .leading, spacing: 8) {
            DotText("GALAX-Z OS", font: .big, dot: 2.4)
            Text(installedLine).font(Face.mono(11)).opacity(0.6)
        }
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button("OPEN FILE") { importing = true }.buttonStyle(PillButton())
            Button(hub.looking ? "LOOKING…" : "LOOK FOR NEW") { Task { await hub.lookForReleases(asked: true) } }.buttonStyle(PillButton()).disabled(hub.looking)
        }
    }

    private var installedLine: String {
        if let i = hub.installed { return "ON YOUR OP-Z: \(hub.titleOf(i).uppercased())" }
        if let k = hub.lastKnown { return "ON YOUR OP-Z, WHEN LAST READ: \(hub.titleOf(k).uppercased())" }
        return "NOT READ YET"
    }

    private func newest(_ r: Hub.Version) -> some View {
        card {
            sideOrBelow {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        DotText(r.title, font: .big, dot: 2, color: Face.yellow)
                        if hub.isOn(r.label) { badge("ON YOUR OP-Z", Face.track(8)) } else { badge(hub.isNews(r.label) ? "NEW" : "NEWEST", Face.yellow) }
                    }
                    ForEach(r.notes, id: \.self) { n in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Circle().fill(Face.yellow).frame(width: 5, height: 5)
                            Text(n).font(Face.mono(12)).opacity(0.85).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Text(r.detail).font(Face.mono(9)).opacity(0.4)
                }
            } control: {
                if Hub.canFlash { install(r.label, r.title) }
            }
        }
    }

    @ViewBuilder private func install(_ label: String, _ title: String, color: Color = Face.yellow) -> some View {
        if hub.isOn(label) {
            EmptyView()
        } else {
            VStack(alignment: .trailing, spacing: 6) {
                HoldButton(title: "HOLD TO INSTALL", question: "Write \(title) to the OP-Z?", color: color) { hub.flash(label) }
                    .disabled(!hub.ready(label))
                if let why = hub.notReady(label) { Text(why).font(Face.mono(9)).opacity(0.5) }
            }
        }
    }

    /// A control beside the text, or under it where there is no room.
    private func sideOrBelow<A: View, B: View>(@ViewBuilder _ text: () -> A, @ViewBuilder control: () -> B) -> some View {
        let t = text(), c = control()
        return Group {
            if width == .compact { VStack(alignment: .leading, spacing: 12) { t; c } }
            else { HStack(alignment: .top, spacing: 20) { t.frame(maxWidth: .infinity, alignment: .leading); c } }
        }
    }

    // MARK: the way there

    private var steps: some View {
        let s = hub.step(backedUp: hub.recentContentBackup != nil)
        return VStack(alignment: .leading, spacing: 10) {
            DotText("HOW TO UPDATE", font: .tiny, dot: 2, color: Face.yellow).padding(.top, 6)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 10, alignment: .top)], alignment: .leading, spacing: 10) {
                step(1, "BACK UP", hub.recentContentBackup.map { "Done \($0.formatted(date: .omitted, time: .shortened))." }
                     ?? "Plug the OP-Z in, switched on normally. Copies your projects and sounds.", s) {
                    if hub.recentContentBackup == nil {
                        Button(backingUp ? "BACKING UP…" : "BACK UP NOW") { live.backUpNow() }.buttonStyle(PillButton())
                            .disabled(backingUp || live.source != .opz || live.deviceName == nil)
                    }
                }
                step(2, "UPDATE MODE", hub.ports.isEmpty ? "Switch the OP-Z off. Hold SCREEN and switch it on. Keep the cable in."
                     : "Found. Ready to be read.", s) { EmptyView() }
                step(3, "READ", hub.installed.map { "It has \(hub.titleOf($0))." } ?? "Reads what is on it. Changes nothing.", s, always: !hub.ports.isEmpty && hub.mustRead) {
                    if hub.installed == nil || hub.mustRead {
                        Button("READ") { hub.check() }.buttonStyle(PillButton(fill: Face.yellow)).disabled(hub.busy != nil || hub.ports.isEmpty || hub.mustPowerCycle)
                    }
                }
                step(4, "INSTALL", hub.justInstalled != nil ? "Written and read back, byte for byte." : "Hold the button on a version. Two files are written, and both read back.", s) { EmptyView() }
                step(5, "RESTART", "Switch it off, then on, with nothing held.", s) { EmptyView() }
            }
        }
    }

    private func step<C: View>(_ n: Int, _ name: String, _ text: String, _ now: Int, always: Bool = false, @ViewBuilder _ control: () -> C) -> some View {
        let done = n < now, here = n == now
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                DotText(done ? "✓" : "\(n)", font: .small, dot: 2, color: done ? Face.track(8) : here ? Face.yellow : Face.ink.opacity(0.4))
                DotText(name, font: .tiny, dot: 2, color: here ? Face.yellow : Face.ink.opacity(done ? 0.8 : 0.45))
            }
            Text(text).font(Face.mono(10)).opacity(here ? 0.85 : 0.45).fixedSize(horizontal: false, vertical: true)
            if here || always { control() }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(Face.panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(here ? Face.yellow.opacity(0.7) : .clear, lineWidth: 1.2))
    }

    private var backingUp: Bool { if case .running = live.backup { true } else { false } }

    private var ipad: some View {
        card {
            DotText("INSTALL FROM A MAC", font: .tiny, dot: 2, color: Face.yellow)
            Text("An iPad or iPhone cannot open the OP-Z's update port. Open Galax-z on a Mac, plug the OP-Z into it, and this page takes you through it. "
                 + "Here you can read what is new, keep backups, and make boot animations.")
                .font(Face.mono(11)).opacity(0.7).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var working: some View {
        if let busy = hub.busy {
            card {
                HStack(spacing: 12) {
                    DotMatrix(mode: .wave, color: Face.yellow)
                    DotText(busy + (hub.progress.map { " · \($0.name)" } ?? ""), font: .tiny, dot: 2, color: Face.yellow)
                }
                DotProgress(value: hub.progress.map { Double($0.done) / Double(max(1, $0.of)) })
                if hub.writing { Text("DON'T UNPLUG OR SWITCH OFF THE OP-Z.").font(Face.mono(11, .bold)).tracking(1.5).foregroundStyle(Face.track(0)) }
            }
        } else if let r = hub.result {
            if r.ok, let i = hub.justInstalled {
                card {
                    DotText("\(hub.titleOf(i)) IS ON YOUR OP-Z", font: .small, dot: 2, color: Face.track(8))
                    Text("Written, read back and identical. Switch it off, then on, with nothing held. If it does not start: switch off, hold SCREEN, "
                         + "switch on, and install the version you had or TE's original.")
                        .font(Face.mono(11)).opacity(0.7).fixedSize(horizontal: false, vertical: true)
                }
            } else if r.ok, r.text != "done" {
                card { DotText(r.text, font: .small, dot: 1.8, color: Face.track(8)) }
            } else if !r.ok {
                warning(r.text + (hub.mustPowerCycle ? " Switch the OP-Z off before trying again." : ""))
            }
        }
    }

    private func warning(_ s: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            DotText("!", font: .small, dot: 2.2, color: Face.track(0))
            Text(s).font(Face.mono(11)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Face.track(0).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: every version

    private var versions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DotText("OTHER VERSIONS", font: .tiny, dot: 2, color: Face.yellow)
                Spacer()
                Button(showAll ? "FEWER" : "ALL") { withAnimation(.snappy) { showAll.toggle() } }.buttonStyle(PillButton())
            }
            .padding(.top, 6)
            if !hub.hasOriginal, Hub.canFlash {
                Text("Every version is made on this Mac from TE's \(Original.firmware), read off your own OP-Z in step 3. No OS of TE's comes with the app.")
                    .font(Face.mono(11)).opacity(0.6).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(showAll ? Array(hub.versions.dropFirst()) : Array(hub.versions.dropFirst().prefix(2)) + hub.versions.filter { $0.label == "original" }) { version($0) }
        }
    }

    private func version(_ v: Hub.Version) -> some View {
        card {
            sideOrBelow {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 10) {
                        DotText(v.title, font: .small, dot: 2)
                        if hub.isOn(v.label) { badge("ON YOUR OP-Z", Face.track(8)) }
                        if v.downloaded { badge("SIGNED", Face.track(4)) }
                    }
                    Text(v.summary).font(Face.mono(11)).opacity(0.65).fixedSize(horizontal: false, vertical: true)
                    if !v.reason.isEmpty { Text(v.reason).font(Face.mono(9)).foregroundStyle(Face.track(0)) }
                }
            } control: {
                if Hub.canFlash { install(v.label, v.title, color: v.label == "original" ? Face.ink : Face.yellow) }
            }
        }
    }

    private func badge(_ s: String, _ c: Color) -> some View {
        DotText(s, font: .tiny, dot: 1.6, color: c).padding(.horizontal, 7).padding(.vertical, 5)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(c.opacity(0.7), lineWidth: 1))
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(showLog ? "HIDE LOG" : "SHOW LOG") { showLog.toggle() }.buttonStyle(PillButton())
            if showLog {
                card {
                    ScrollView {
                        Text(hub.log.joined(separator: "\n")).font(Face.mono(10)).opacity(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                    }
                    .frame(maxHeight: 240)
                    .defaultScrollAnchor(.bottom)
                }
            }
        }
    }
}

/// A bar of dots; without a value, a wave.
struct DotProgress: View {
    let value: Double?
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { g, size in
                let n = Int(size.width / 9)
                for i in 0..<n { for j in 0..<2 {
                    let f = Double(i) / Double(max(1, n - 1))
                    let a = value.map { f <= $0 ? 1.0 : 0.12 } ?? 0.12 + 0.88 * max(0, sin(t * 4 - f * 12))
                    g.fill(Path(ellipseIn: CGRect(x: CGFloat(i) * 9, y: CGFloat(j) * 9, width: 7, height: 7)), with: .color(Face.yellow.opacity(a)))
                } }
            }
        }
        .frame(height: 18)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(value.map { "\(Int($0 * 100)) percent" } ?? "working")
    }
}

func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10, content: content)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Face.panel, in: RoundedRectangle(cornerRadius: 14))
}
