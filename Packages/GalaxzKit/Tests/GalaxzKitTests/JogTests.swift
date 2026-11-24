import Testing
@testable import OPZModel
@testable import OPZStage

/// SCREEN + a dial: the OP-Z's SCREEN screen sends CC 105-108 on channel 16, 1 a click one way and 127 the other (1.2.45, 0x8011e516).
/// The green one turns the app's pages.
@Suite struct JogTests {
    @Test func theGreenDialTurnsThePages() {
        let s = Stage(), n = Int(Stage.jogClicks)
        func clicks(_ k: Int, _ v: Int) { for _ in 0..<k { #expect(s.screenDial(0, value: v)) } }
        clicks(n - 1, 1)
        #expect(s.page == .track)                                       // not yet a page
        clicks(1, 1)
        #expect(s.page == .grid)
        clicks(2 * n, 1)
        #expect(s.page == .play)
        clicks(4 * n, 127)
        #expect(s.page.rawValue == Stage.Page.allCases.count - 1)        // round, backwards
        clicks(n - 1, 127)
        var i = s.input
        i.panel.screen = false                                          // SCREEN let go: the clicks over are gone
        s.input = i
        clicks(1, 127)
        #expect(s.page.rawValue == Stage.Page.allCases.count - 1)
    }

    @Test func theOthersAreTakenAndLeftAlone() {
        let s = Stage()
        for d in 1..<4 { for _ in 0..<6 { #expect(s.screenDial(d, value: 1)) } }
        #expect(s.page == .track)
        #expect(!s.screenDial(4, value: 1) && !s.screenDial(-1, value: 1))
    }
}
