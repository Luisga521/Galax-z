import OPZLink
import OPZStage
import SwiftUI

@main
struct GalaxzApp: App {
    /// On the command line: `-demo` starts with the demo OP-Z (simulator screenshots, no unit attached), `-keytest` opens the
    /// key test, `-hub` the hub, `-page grid` (or any page) that page.
    @State private var live: Live
    @State private var hub: Hub

    init() {
        #if DEBUG
        MIDITransport.onlyVirtual = SelfTest.value("-selftest") != nil         // before anything is looked for
        #endif
        let live = Self.makeLive(), hub = Hub()
        _live = State(initialValue: live)
        _hub = State(initialValue: hub)
        #if DEBUG
        SelfTest.start(live, hub)
        #endif
    }

    private static func makeLive() -> Live {
        let args = ProcessInfo.processInfo.arguments
        let live = Live(demo: args.contains("-demo"))
        if args.contains("-keytest") { live.openKeyTest() }
        if let i = args.firstIndex(of: "-page"), i + 1 < args.count,
           let p = Stage.Page.allCases.first(where: { $0.name.lowercased() == args[i + 1] }) { live.stage.page = p }
        return live
    }

    var body: some Scene {
        WindowGroup {
            Root(live: live, hub: hub)
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
        .windowResizability(.contentMinSize)       // with a defaultSize, or by itself, the Mac locks the window to the size it opens at
    }
}
