import OPZLink
import OPZStage
import SwiftUI
import UniformTypeIdentifiers

/// The OP-Z's screen, whole window; everything else comes over it.
struct Root: View {
    let live: Live
    let hub: Hub
    @State private var over: Over?
    @State private var pairing = false
    /// The pairing list opened by itself: once, so that closing it is the last word.
    @State private var offered = false
    @Environment(\.scenePhase) private var phase
    @AppStorage("fineness") private var fineness = 240
    @AppStorage("glow") private var glow = 0.8
    @AppStorage("afterglow") private var afterglow = 0.3

    /// What the offer to pair waits on: it starts again when one of these changes.
    private struct Looking: Equatable { let bluetooth: BluetoothLink.State, active: Bool }

    /// The settings, on a tab.
    typealias Over = SettingsScreen.Tab

    var body: some View {
        DotDisplay(live: live, look: .init(fineness: fineness, glow: glow, afterglow: afterglow), covered: over != nil || live.keyTestOpen) { what in
            switch what {
            case .hub: over = .os
            case .settings: over = .general
            case .pair: pairing = true
            case .sound: live.audio.toggle()
            case .none: break
            }
        }
        .ignoresSafeArea(.container, edges: ignored)
        .background(Color.black.ignoresSafeArea())
        .fullScreenCover(item: $over) { o in
            SettingsScreen(live: live, hub: hub, tab: o) { live.openKeyTest(); over = nil }
        }
        .fullScreenCover(isPresented: Binding(get: { live.keyTestOpen }, set: { if !$0 { live.closeKeyTest() } })) {
            KeyTestScreen(live: live)
        }
        .fileImporter(isPresented: Binding(get: { live.sampler.opening }, set: { live.sampler.opening = $0 }), allowedContentTypes: [.audio]) { r in
            if case .success(let u) = r { live.sampler.open(u) }
        }
        .sheet(isPresented: $pairing) { BluetoothPairing() }
        .onChange(of: live.deviceName) { _, name in if name != nil { pairing = false } }      // linked: straight to its screen
        .onOpenURL { url in
            hub.open(url)
            over = .os
        }
        .onChange(of: hub.notice, initial: true) { _, n in live.notice = n }
        .task(id: Looking(bluetooth: live.bluetooth, active: phase == .active)) { await offerPairing() }
        .task { await hub.lookForReleases() }
        .onChange(of: live.status == .live, initial: true) { _, on in Awake.keep(on) }
        #if targetEnvironment(macCatalyst)
        .frame(minWidth: 720, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)      // never too small for a page
        #endif
        .onAppear {
            MacWindow.setUp()
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-hub") { over = .os } else if args.contains("-learn") { over = .learn } else if args.contains("-bridge") { over = .bridge } else if args.contains("-settings") { over = .general } }
    }

    /// Dots to the very edge on the Mac and iPad; clear of the island and the home bar on a phone.
    private var ignored: Edge.Set { UIDevice.current.userInterfaceIdiom == .phone ? [] : .all }

    /// No OP-Z by itself (an advertising one is linked within a second or two): the pairing list opens, and can be had again from the start screen.
    /// On the Mac, PAIR is on the start screen while there is no OP-Z, and nothing opens by itself: the Mac never searches Bluetooth unasked.
    private func offerPairing() async {
        #if targetEnvironment(macCatalyst)
        return              // PAIR follows whether an OP-Z is there (Live.feedStage)
        #else
        live.offerPairing(false)
        switch live.bluetooth {
        case .off, .unauthorized, .unsupported: return
        case .idle:
            return
        case .searching, .connecting, .linked:
            guard phase == .active else { return }
            try? await Task.sleep(for: .seconds(live.bluetooth == .searching ? 3 : 8))
            guard !Task.isCancelled, live.source == .opz, live.deviceName == nil else { return }
            live.offerPairing(true)
            guard !offered, over == nil, !live.keyTestOpen else { return }
            offered = true
            pairing = true
        }
        #endif
    }
}

/// A screen does not go dark while it is the OP-Z's.
@MainActor enum Awake {
    private static var activity: NSObjectProtocol?
    static func keep(_ on: Bool) {
        UIApplication.shared.isIdleTimerDisabled = on
        #if targetEnvironment(macCatalyst)
        if on, activity == nil { activity = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .userInitiated], reason: "Showing the OP-Z's screen") }
        if !on, let a = activity { ProcessInfo.processInfo.endActivity(a); activity = nil }
        #endif
    }
}

/// The Mac's window: the dots to its top edge.
@MainActor enum MacWindow {
    static func setUp() {
        #if targetEnvironment(macCatalyst)
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.titlebar?.titleVisibility = .hidden
            scene.titlebar?.toolbar = nil
            scene.title = "Galax-z"
        }
        #endif
    }
}
