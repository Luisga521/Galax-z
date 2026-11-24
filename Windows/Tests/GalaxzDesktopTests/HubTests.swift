import Foundation
import OPZFirmware
import Testing
@testable import GalaxzDesktop

/// The hub's rules on Windows, with no OP-Z: what may be done when, and that a failed read leaves nothing behind.
@Suite struct HubTests {
    /// An update-mode port that never answers.
    final class Silent: ConsoleTransport {
        var written: [[UInt8]] = []
        func write(_ bytes: [UInt8]) throws { written.append(bytes) }
        func read(timeout: TimeInterval) throws -> [UInt8] { [] }
        func discardInput() {}
    }

    func folder() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("galaxz-hub-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    /// A hub over `ports`, its catalogue loaded.
    func hub(ports: [String] = [], port: Silent = Silent()) throws -> (Hub, MainQueue, Prefs) {
        let f = folder(), main = MainQueue(), prefs = Prefs(folder: f)
        let mode = Hub.UpdateMode(ports: { ports }, choose: {
            ports.count == 1 ? .success(ports[0]) : .failure(.refused("no OP-Z in update mode"))
        }, open: { _ in port })
        let h = Hub(support: f, backups: f.appendingPathComponent("Backups"), prefs: prefs, mode: mode, main: main)
        let end = Date().addingTimeInterval(30)
        while !h.loaded {
            main.drain()
            guard Date() < end else { throw ReleaseError("the hub did not load") }
            Thread.sleep(forTimeInterval: 0.01)
        }
        return (h, main, prefs)
    }

    @Test func versionsNewestFirstTheWayBackLast() throws {
        let (h, _, _) = try hub()
        #expect(h.problem == nil)
        #expect(h.versions.count > 2)
        #expect(h.versions.last?.label == "original")
        let numbers = h.versions.dropLast().compactMap { Catalog.number(of: $0.label) }
        #expect(numbers == numbers.sorted(by: >))
        #expect(h.newest?.label == h.versions.first?.label)
    }

    @Test func theChimeChoosesTheQuietBuilds() throws {
        let (h, _, prefs) = try hub()
        h.chime = false
        #expect(prefs[\.bootChime] == false)
        let quiet = h.versions.filter { $0.label.hasSuffix(Catalog.quiet) }
        h.chime = true
        #expect(h.versions.allSatisfy { !$0.label.hasSuffix(Catalog.quiet) })
        #expect(!quiet.isEmpty)
    }

    @Test func nothingWithoutTheUpdateMode() throws {
        let (h, _, _) = try hub()
        #expect(h.notReady(h.newest!.label) == "NOT IN UPDATE MODE")
        #expect(!h.animationReady)
        #expect(h.step(backedUp: false) == 1)
        #expect(h.step(backedUp: true) == 2)
    }

    @Test func readFirst() throws {
        let (h, _, _) = try hub(ports: ["COM7"])
        #expect(h.step(backedUp: true) == 3)
        #expect(h.notReady(h.newest!.label) == "READ IT FIRST (STEP 3)")
    }

    /// A read that gets no answer: refused, said, and nothing is marked as half written.
    @Test func aSilentPortIsRefused() throws {
        let port = Silent()
        let (h, main, prefs) = try hub(ports: ["COM7"], port: port)
        h.check()
        #expect(h.busy == "check")
        let end = Date().addingTimeInterval(30)
        while h.busy != nil, Date() < end { main.drain(); Thread.sleep(forTimeInterval: 0.01) }
        #expect(h.busy == nil)
        #expect(h.result?.ok == false)
        #expect(h.installed == nil)
        #expect(prefs[\.interruptedWrite] == nil)
        #expect(!h.mustPowerCycle)
        // the console sent only its fixed frames: a ping, nothing that writes
        #expect(!port.written.isEmpty)
        #expect(port.written.allSatisfy { UpdateConsole.ping == $0 })
    }

    @Test func noPortNoJob() throws {
        let (h, main, _) = try hub()
        h.check()
        let end = Date().addingTimeInterval(10)
        while h.busy != nil, Date() < end { main.drain(); Thread.sleep(forTimeInterval: 0.01) }
        #expect(h.result?.ok == false)
        #expect(h.result?.text.contains("update mode") == true)
    }

    @Test func settingsKeepAndOlderFilesRead() throws {
        let f = folder()
        let p = Prefs(folder: f)
        p[\.glow] = 1.2
        p[\.interruptedWrite] = "Galax-z v13"
        let a = LEDAnimation.galaxy
        p[\.myAnimations] = [a]
        let again = Prefs(folder: f)
        #expect(again[\.glow] == 1.2)
        #expect(again[\.interruptedWrite] == "Galax-z v13")
        #expect(again[\.myAnimations] == [a])
        // a file with some keys only
        try Data(#"{"glow": 0.5}"#.utf8).write(to: f.appendingPathComponent("settings.json"))
        let older = Prefs(folder: f)
        #expect(older[\.glow] == 0.5)
        #expect(older[\.fineness] == 240)
        #expect(older[\.bootChime] == true)
    }

    @Test func yourAnimations() throws {
        let (h, _, _) = try hub()
        let mine = h.store.copy(of: .galaxy)
        #expect(!h.store.isMine(mine))
        h.store.save(mine)
        #expect(h.store.isMine(mine))
        var edited = mine
        edited.pattern = "spiral"
        h.store.save(edited)
        #expect(h.store.mine == [edited])
        h.store.delete(edited)
        #expect(h.store.mine.isEmpty)
    }
}
