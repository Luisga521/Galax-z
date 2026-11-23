import Foundation
import Observation
import OPZFirmware
import UniformTypeIdentifiers

/// The firmware hub: what is on the OP-Z, every image Galax-z can put there, and the strict writer that does it.
///
/// Flashing needs the OP-Z's update-mode serial port, so it runs on the Mac (Catalyst) only. Images are built from
/// TE's 1.2.45 `os.ldr`, which the hub reads off the unit itself (or rebuilds from any Galax-z build installed on it)
/// and keeps in Application Support; no file of TE's ships with the app (a patch record carries the few bytes it replaces).
@MainActor @Observable
final class Hub {
    static var canFlash: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #elseif DEBUG
        ProcessInfo.processInfo.arguments.contains("-pretend-mac")      // the Mac's hub, to look at on a simulator
        #else
        false
        #endif
    }

    private(set) var catalog: Catalog?
    private(set) var images: [FirmwareImage] = []
    /// TE's 1.2.45, once known: an animation's image is built from it when it is flashed.
    @ObservationIgnored private var original: [UInt8]?
    /// Your own animations.
    let store = AnimationStore()
    /// Where the OP-Z's LEDs sit.
    private(set) var layout: LEDLayout?
    /// The frames the OP-Z plays, read at the last check or flash (nil: not Galax-z v2).
    private var onTheOPZ: [UInt8]?
    private(set) var problem: String?
    private(set) var ports: [String] = []
    private(set) var installed: String?
    private(set) var busy: String?
    private(set) var log: [String] = []
    private(set) var progress: (name: String, done: Int, of: Int)?
    private(set) var result: (ok: Bool, text: String)?
    /// An upload did not finish: nothing may be sent until the OP-Z's port has gone away (switched off).
    private(set) var mustPowerCycle = false

    /// The releases on this device, newest first.
    private(set) var releases: [Release] = []
    private(set) var looking = false
    /// What was written since the app opened (the OP-Z has to be restarted).
    private(set) var justInstalled: String?
    private(set) var writing = false
    @ObservationIgnored private let releaseStore = ReleaseStore(folder: Hub.support.appending(path: "Releases"))
    @ObservationIgnored private var activity: NSObjectProtocol?
    @ObservationIgnored private var lookedAt = Date.distantPast

    init() {
        refreshPorts()
        Task { await load() }
    }

    /// The versions there are and, if TE's original is kept on this device, their images. Off the main thread: it reads files (the first
    /// frame waits for none), and a file may make the Mac ask for leave.
    private func load() async {
        struct Shelf: Sendable { var layout: LEDLayout?, catalog: Catalog?, releases: [Release] = [], original: [UInt8]?, images: [FirmwareImage] = [], problem: String? }
        let store = releaseStore, start = ProcessInfo.processInfo.systemUptime
        let s = await Task.detached(priority: .userInitiated) {
            var s = Shelf()
            do {
                s.layout = try LEDLayout.bundled()
                s.releases = store.all()
                let catalog = try Catalog.bundled().adding(s.releases)
                s.catalog = catalog
                if let o = Self.cachedOriginal() { s.images = try catalog.images(original: o); s.original = o }
            } catch { s.problem = "\(error)" }
            return s
        }.value
        layout = s.layout
        problem = s.problem
        original = s.original
        if catalog == nil {
            (catalog, releases, images) = (s.catalog, s.releases, s.images)
            list()
        } else if let o = original, images.isEmpty {        // a release file opened the app and is in already
            do { try build(o) } catch { problem = "\(error)" }
        }
        loaded = true
        loadSeconds = ProcessInfo.processInfo.systemUptime - start
    }
    /// The versions are in; until then nothing can be read or written.
    private(set) var loaded = false
    @ObservationIgnored private(set) var loadSeconds = 0.0

    var hasOriginal: Bool { !images.isEmpty }

    // MARK: versions

    /// A version as the hub lists it: one of the app's builds, a release, or TE's original.
    struct Version: Identifiable {
        let label, title, summary: String
        let notes: [String]
        let detail: String
        let downloaded: Bool
        let reason: String
        var id: String { label }
    }

    /// Newest first; TE's original last. Made when the catalogue changes: the screen asks for it many times a second.
    private(set) var versions: [Version] = []

    /// Two tones when the OP-Z is switched on, with the next version that is installed.
    var chime = UserDefaults.standard.object(forKey: "bootChime") as? Bool ?? true {
        didSet { UserDefaults.standard.set(chime, forKey: "bootChime"); list() }
    }
    /// The version on the OP-Z has the chime, or has not, against what is wanted.
    var chimeDiffers: Bool {
        guard let k = lastKnown.map({ String($0.split(separator: " ").first ?? "") }), (Catalog.number(of: k) ?? 0) >= 11 else { return false }
        return k.hasSuffix(Catalog.quiet) == chime
    }

    private func list() {
        guard let catalog else { return }
        let names = Set(catalog.builds.map(\.label))
        // of a version with a chime and one without, the one that is wanted
        func wanted(_ l: String) -> Bool { l.hasSuffix(Catalog.quiet) ? !chime : chime || !names.contains(l + Catalog.quiet) }
        let ours = catalog.builds.filter { Catalog.number(of: $0.label) != nil && wanted($0.label) }.sorted { Catalog.number(of: $0.label)! < Catalog.number(of: $1.label)! }.reversed().map { label, b -> Version in
            let r = catalog.promised[label] == nil ? nil : releases.first { $0.label == label }, im = images.first { $0.label == label }
            return Version(label: label, title: r?.title ?? b.title, summary: b.description ?? "", notes: r?.notes ?? b.notes ?? Self.sentences(b.description ?? ""),
                           detail: [r.map { "RELEASED \($0.date) · SIGNED" }, im?.ldr.map { "\($0.count) BYTES · SHA256 \(Hash.sha256($0).prefix(12))" }].compactMap { $0 }.joined(separator: " · "),
                           downloaded: catalog.promised[label] != nil, reason: im?.reason ?? "")
        }
        versions = ours + [Version(label: "original", title: "TE \(Original.firmware)", summary: "What teenage engineering ships. The way back.", notes: [], detail: "",
                                   downloaded: false, reason: "")]
    }

    /// Newer than what the OP-Z is known to have.
    func isNews(_ label: String) -> Bool {
        guard let n = Catalog.number(of: label), let known = lastKnown else { return false }
        return n > (Catalog.number(of: String(known.split(separator: " ").first ?? "")) ?? (known == "original" ? 0 : .max))
    }

    private static func sentences(_ s: String) -> [String] {
        s.split(separator: ".").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var newest: Version? { versions.first { $0.label != "original" } }

    func titleOf(_ label: String) -> String {
        versions.first { label == $0.label || label.hasPrefix($0.label + " ") }?.title ?? label
    }

    /// The last thing read off (or written to) the OP-Z, also from an earlier day.
    private(set) var lastKnown = UserDefaults.standard.string(forKey: "lastInstalled") {
        didSet { UserDefaults.standard.set(lastKnown, forKey: "lastInstalled") }
    }

    /// A write that did not finish, from this run of the app or an earlier one: what the OP-Z has is not whole. Cleared by the next
    /// check or install that does finish.
    private(set) var interrupted = UserDefaults.standard.string(forKey: "interruptedWrite") {
        didSet { UserDefaults.standard.set(interrupted, forKey: "interruptedWrite") }
    }

    /// What was read is not a whole OS this app knows: only TE's original may be written over it (the writer refuses the rest too).
    var notWhole: Bool { installed.map { $0.hasPrefix("unknown") || $0.hasPrefix("no os.ldr") } ?? false }

    /// The build on it (an installed animation's name is not a build's).
    private var installedBuild: String? { installed == nil ? nil : lastKnown }

    func isOn(_ label: String) -> Bool { interrupted == nil && (installedBuild ?? lastKnown) == label }

    /// In the corner of the screen: a version newer than the one the OP-Z is known to have.
    var notice: String? { newest.flatMap { isNews($0.label) ? "NEW: " + $0.title.uppercased().replacingOccurrences(of: "GALAX-Z ", with: "") : nil } }

    /// Where the person is in updating (1–5).
    func step(backedUp: Bool) -> Int {
        if justInstalled != nil { return 5 }
        if !ports.isEmpty { return installed == nil ? 3 : 4 }
        return backedUp ? 2 : 1
    }

    var mustRead: Bool { !hasOriginal }

    func ready(_ label: String) -> Bool { notReady(label) == nil }

    /// Why a version cannot be installed right now.
    func notReady(_ label: String) -> String? {
        if busy != nil || !loaded { return "" }
        if mustPowerCycle { return "SWITCH THE OP-Z OFF FIRST" }
        if ports.isEmpty { return "NOT IN UPDATE MODE" }
        if installed == nil || !hasOriginal { return "READ IT FIRST (STEP 3)" }
        if notWhole, label != "original" { return "INSTALL TE'S ORIGINAL FIRST" }
        if let im = images.first(where: { $0.label == label }), im.ldr == nil { return "NOT FLASHABLE" }
        return nil
    }

    // MARK: releases

    nonisolated static let releaseType = UTType(exportedAs: "org.galax-z.release", conformingTo: .json)

    /// A release file, opened or dropped: checked, kept, listed.
    func open(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let r = try releaseStore.add(Data(contentsOf: url))
            taken()
            result = (true, "\(r.title) added")
        } catch { result = (false, "\(url.lastPathComponent): \(error)") }
    }

    private func taken() {
        releases = releaseStore.all()
        do {
            catalog = try Catalog.bundled().adding(releases)
            list()
            if let original { try build(original) }
        } catch { problem = "\(error)" }
    }

    /// Ask for the list of releases, and fetch any newer than what is here. By itself at most once an hour.
    func lookForReleases(asked: Bool = false) async {
        let on = UserDefaults.standard.object(forKey: "lookForReleases") as? Bool ?? true
        guard asked || on, !looking, asked || Date().timeIntervalSince(lookedAt) > 3600 else { return }
        looking = true
        defer { looking = false }
        lookedAt = Date()
        let feedURL = UserDefaults.standard.string(forKey: "releaseFeed").flatMap(URL.init(string:)) ?? ReleaseFeed.defaultURL
        do {
            let feed = try JSONDecoder().decode(ReleaseFeed.self, from: await Self.fetch(feedURL, limit: 1_000_000))
            let have = Set(catalog?.builds.map(\.label) ?? []).union(releases.map(\.label))
            var got = 0, failed: Error?
            for e in feed.releases.sorted(by: { $0.number > $1.number }).prefix(8) where !have.contains(e.label) {
                guard let u = ReleaseFeed.url(of: e, feed: feedURL) else { continue }
                do {                    // one bad file does not keep the others away
                    try releaseStore.add(await Self.fetch(u, limit: 16_000_000))
                    got += 1
                } catch { failed = error }
            }
            if got > 0 { taken() }
            if asked { result = failed.map { (false, "A release was refused: \($0)") } ?? (true, got > 0 ? "\(got) new" : "nothing newer") }
        } catch {
            if asked { result = (false, "No list of releases could be read: \(error.localizedDescription)") }
        }
    }

    private static func fetch(_ url: URL, limit: Int) async throws -> Data {
        guard url.scheme == "https" || url.isFileURL else { throw ReleaseError("not a secure address") }
        var q = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        q.httpShouldHandleCookies = false
        let (d, response) = try await URLSession(configuration: .ephemeral).data(for: q)
        if let h = response as? HTTPURLResponse, h.statusCode != 200 {
            throw ReleaseError(h.statusCode == 404 ? "there is none at the address yet" : "the server said \(h.statusCode)")
        }
        guard d.count <= limit else { throw ReleaseError("too big") }
        return d
    }

    private func build(_ original: [UInt8]) throws {
        guard let catalog else { return }
        self.original = original
        images = try catalog.images(original: original)
        list()
    }

    /// Whether the OP-Z plays exactly this animation (by its frames, so an edited one is not mistaken for the old).
    func playing(_ a: LEDAnimation) -> Bool {
        guard let onTheOPZ, let layout else { return false }
        return onTheOPZ == store.bytes(a, layout)
    }

    func refreshPorts() {
        #if targetEnvironment(macCatalyst)
        #if DEBUG
        let now = SelfTest.port.map { FileManager.default.fileExists(atPath: $0) ? [$0] : [] } ?? SerialPort.candidates()
        #else
        let now = SerialPort.candidates()
        #endif
        guard now != ports else { return }
        ports = now
        if now.isEmpty, busy == nil {       // it went away: what it has next is not known; what went wrong still is
            installed = nil
            if result?.ok == true, justInstalled == nil { result = nil }
        }
        #endif
    }

    // MARK: jobs

    func check() { run("check") }

    func flash(_ label: String) {
        guard let im = images.first(where: { $0.label == label }), notReady(label) == nil else { return }
        run("flash \(label)", im)
    }

    /// The builds an animation can be flashed onto; a check or a flash sets `base` to what the OP-Z has.
    var bases: [(String, String)] { catalog?.playerBuilds.map { ($0.label, $0.build.title) } ?? [] }
    var base = UserDefaults.standard.string(forKey: "animationBase") ?? "galaxz-v2" { didSet { UserDefaults.standard.set(base, forKey: "animationBase") } }

    /// An animation can be installed right now.
    var animationReady: Bool { !notWhole && busy == nil && !mustPowerCycle && !ports.isEmpty && installed != nil && hasOriginal }

    /// That build, playing this animation.
    func flash(_ a: LEDAnimation) {
        guard let catalog, let layout, let original, animationReady else { return }
        do { run("flash \(a.name)", try catalog.bootImage(original: original, a, layout: layout, on: base)) }
        catch { result = (false, "\(error)") }
    }

    private func run(_ job: String, _ image: FirmwareImage? = nil) {
        #if targetEnvironment(macCatalyst)
        guard busy == nil, loaded, !mustPowerCycle, let catalog else { return }
        refreshPorts()
        // the Mac stays awake, and the app is not quit from under it
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled,
                                                                                          .automaticTerminationDisabled], reason: "Talking to the OP-Z's update mode")
        busy = job; log = []; progress = nil; result = nil; justInstalled = nil; writing = image != nil
        // what may be written: the catalog's images and the one asked for
        let images = self.images.filter { $0.label != image?.label } + (image.map { [$0] } ?? [])
        let ports = self.ports
        let say: @Sendable (String) -> Void = { line in Task { @MainActor in self.log.append(line) } }
        Task.detached {
            let folder = Backups.osRun()
            var outcome: (Bool, String) = (true, "done")
            var found: String?
            var recovered: [UInt8]?
            var frames: [UInt8]?
            var build: String?
            var began = false              // something has been (or may have been) written
            do {
                guard ports.count == 1 else {
                    throw ConsoleError.refused(ports.isEmpty ? "no OP-Z in update mode: hold SCREEN while switching it on, then plug it in"
                                                             : "more than one /dev/cu.usbmodem port: unplug the others")
                }
                let port = try SerialPort(path: ports[0])
                say("port \(ports[0])")
                let con = UpdateConsole(port, images: images, log: say)
                if let image {
                    say("== flash \(image.title)")
                    _ = try con.flash(image, all: images, saveBackup: {
                        try Self.save($0, to: folder)
                        // from here on it is being written: kept on disk, so that even a crash of this Mac leaves the warning
                        UserDefaults.standard.set(image.title, forKey: "interruptedWrite")
                        began = true
                    },
                                      name: { catalog.name(images, ldr: $0, crc: $1) }) { name, done, of in
                        Task { @MainActor in self.progress = (name, done, of) }
                    }
                    found = image.label
                    frames = image.ldr.flatMap(catalog.frames(playedBy:))
                    build = image.ldr.flatMap(catalog.underPlayer)?.label
                } else {
                    try con.start()
                    let (ldr, crc) = try con.readInstalled()
                    try Self.save([("os.crc32", crc), ("os.ldr", ldr)].compactMap { n, d in d.map { (name: n, data: $0) } }, to: folder)
                    if images.isEmpty, let ldr {
                        recovered = catalog.recoverOriginal(from: ldr)
                    }
                    found = images.isEmpty ? (recovered != nil ? "a known image (original recovered)" : "unknown os.ldr")
                                           : catalog.name(images, ldr: ldr, crc: crc)
                    frames = ldr.flatMap(catalog.frames(playedBy:))
                    build = ldr.flatMap(catalog.underPlayer)?.label
                    say("installed: \(found!)")
                }
            } catch {
                outcome = (false, "\(error)")
                say("STOPPED: \(error)")
                if case ConsoleError.stalled = error { await MainActor.run { self.waitForPowerCycle() } }
            }
            let final = outcome, playing = frames, base = build, wrote = began
            await MainActor.run {
                if let recovered { self.adopt(original: recovered) }
                if final.0, let found {
                    self.installed = found
                    // a version by its own name; an animation's image by the build under it; what is not known by none
                    let named = found.split(separator: " ").first.map(String.init) ?? ""
                    self.lastKnown = self.versions.contains { $0.label == named } ? named : base
                    self.onTheOPZ = playing
                    self.interrupted = found.hasPrefix("unknown") || found.hasPrefix("no os.ldr") ? self.interrupted : nil
                    if let image { self.justInstalled = image.label }
                } else if wrote, let image {
                    self.interrupted = image.title
                    // it may have part of the new one and part of the old: nothing is known to be on it
                    self.installed = nil
                    self.lastKnown = nil
                    self.onTheOPZ = nil
                }
                self.writing = false
                if let a = self.activity { ProcessInfo.processInfo.endActivity(a); self.activity = nil }
                if let base { self.base = base }
                self.result = final
                self.busy = nil
                try? self.log.joined(separator: "\n").write(to: folder.appending(path: "log.txt"), atomically: true, encoding: .utf8)
            }
        }
        #endif
    }

    private func waitForPowerCycle() { mustPowerCycle = true }

    /// The person says it was switched off (the port going away only says that the cable came out: the OP-Z has a battery).
    func switchedOff() {
        refreshPorts()
        if ports.isEmpty { mustPowerCycle = false }
    }

    private func adopt(original: [UInt8]) {
        guard catalog != nil, Original.matches(original) else { return }
        try? FileManager.default.createDirectory(at: Self.support, withIntermediateDirectories: true)
        try? Data(original).write(to: Self.originalURL)
        do { try build(original); log.append("TE's 1.2.45 kept in \(Self.originalURL.path)") }
        catch { problem = "\(error)" }
    }

    // MARK: files

    nonisolated static var support: URL {
        #if DEBUG
        if let s = SelfTest.scratch { return s.appending(path: "support") }
        #endif
        return Self.realSupport
    }
    nonisolated private static var realSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "Galax-z")
    }
    nonisolated static var originalURL: URL { support.appending(path: "os-1.2.45.ldr") }

    nonisolated static func cachedOriginal() -> [UInt8]? {
        var places = [originalURL]
        #if targetEnvironment(macCatalyst)   // the repository's dumps, where run-mac.sh says they are
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-dumps"), i + 1 < args.count {
            places += ((try? FileManager.default.contentsOfDirectory(at: URL(filePath: args[i + 1]), includingPropertiesForKeys: nil)) ?? [])
                .map { $0.appending(path: "os.ldr") }
        }
        #endif
        for url in places {
            if let d = try? Data(contentsOf: url), Original.matches([UInt8](d)) { return [UInt8](d) }
        }
        return nil
    }

    nonisolated static func save(_ files: [(name: String, data: [UInt8])], to folder: URL) throws {
        for f in files { try Data(f.data).write(to: folder.appending(path: "installed-\(f.name)"), options: .atomic) }
    }

    /// The newest backup of the projects and sound settings on this device, if it is less than a day old.
    private(set) var recentContentBackup: Date?

    /// Look for it (when the hub opens, and after a backup).
    func lookForBackup() async {
        let checked = await Task.detached { Backups.latest()?.1.checked }.value
        recentContentBackup = checked.flatMap { Date().timeIntervalSince($0) < 24 * 3600 ? $0 : nil }
    }
}
