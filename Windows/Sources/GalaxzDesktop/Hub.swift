import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import OPZFirmware

/// The firmware hub on Windows: `App/Hub.swift` without SwiftUI. What is on the OP-Z, every image Galax-z can put there, and
/// the strict writer that does it (`UpdateConsole`, the Mac's code, unchanged). Images are built from TE's 1.2.45 `os.ldr`,
/// which the hub reads off the unit itself and keeps in `%LOCALAPPDATA%\Galax-z`; no file of TE's ships with the app.
///
/// Used from the window's thread only. A read or a write runs on a thread of its own and comes back through `main`.
public final class Hub {
    /// How the update mode is reached: Windows' COM ports (`WindowsPorts`, `UpdatePorts`), or a fake one in a test.
    public struct UpdateMode {
        /// The ports Galax-z may talk to, there now.
        public var ports: () -> [String]
        /// The one port to use, or why there is none.
        public var choose: () -> Result<String, ConsoleError>
        public var open: (String) throws -> ConsoleTransport
        public init(ports: @escaping () -> [String], choose: @escaping () -> Result<String, ConsoleError>,
                    open: @escaping (String) throws -> ConsoleTransport) {
            (self.ports, self.choose, self.open) = (ports, choose, open)
        }
    }

    /// A version as the hub lists it: one of the app's builds, a release, or TE's original.
    public struct Version: Identifiable, Equatable {
        public let label, title, summary: String
        public let notes: [String]
        public let detail: String
        public let downloaded: Bool
        public let reason: String
        public var id: String { label }
    }

    public private(set) var catalog: Catalog?
    public private(set) var images: [FirmwareImage] = []
    /// TE's 1.2.45, once known: an animation's image is built from it when it is flashed.
    private var original: [UInt8]?
    /// Your own animations.
    public let store: AnimationStore
    /// Where the OP-Z's LEDs sit.
    public private(set) var layout: LEDLayout?
    /// The frames the OP-Z plays, read at the last check or flash (nil: not Galax-z v2).
    private var onTheOPZ: [UInt8]?
    public private(set) var problem: String?
    public private(set) var ports: [String] = []
    public private(set) var installed: String?
    public private(set) var busy: String?
    public private(set) var log: [String] = []
    public private(set) var progress: (name: String, done: Int, of: Int)?
    public private(set) var result: (ok: Bool, text: String)?
    /// An upload did not finish: nothing may be sent until the OP-Z's port has gone away (switched off).
    public private(set) var mustPowerCycle = false
    /// The releases on this computer, newest first.
    public private(set) var releases: [Release] = []
    public private(set) var looking = false
    /// What was written since the app opened (the OP-Z has to be restarted).
    public private(set) var justInstalled: String?
    public private(set) var writing = false
    /// The versions are in; until then nothing can be read or written.
    public private(set) var loaded = false
    /// Newest first; TE's original last.
    public private(set) var versions: [Version] = []

    public let support: URL, backups: URL
    private let prefs: Prefs
    private let mode: UpdateMode
    private let main: MainQueue
    private let releaseStore: ReleaseStore
    private var lookedAt = Date.distantPast
    /// Told when a write begins and ends: the computer must not sleep, nor the app close, meanwhile.
    public var keepAwake: (Bool) -> Void = { _ in }

    public init(support: URL, backups: URL, prefs: Prefs, mode: UpdateMode, main: MainQueue) {
        (self.support, self.backups, self.prefs, self.mode, self.main) = (support, backups, prefs, mode, main)
        store = AnimationStore(prefs: prefs)
        releaseStore = ReleaseStore(folder: support.appendingPathComponent("Releases"))
        refreshPorts()
        load()
    }

    /// The versions there are and, if TE's original is kept on this computer, their images. Off the window's thread.
    private func load() {
        let store = releaseStore, originalURL = self.originalURL
        Thread.detachNewThread { [main] in
            var layout: LEDLayout?, catalog: Catalog?, releases: [Release] = [], original: [UInt8]?, images: [FirmwareImage] = [], problem: String?
            do {
                layout = try LEDLayout.bundled()
                releases = store.all()
                let c = try Catalog.bundled().adding(releases)
                catalog = c
                if let o = Hub.cachedOriginal(originalURL) { images = try c.images(original: o); original = o }
            } catch { problem = "\(error)" }
            main.post { [weak self] in
                guard let self else { return }
                self.layout = layout
                self.problem = problem
                self.original = original
                (self.catalog, self.releases, self.images) = (catalog, releases, images)
                self.list()
                self.loaded = true
            }
        }
    }

    public var hasOriginal: Bool { !images.isEmpty }

    // MARK: versions

    public var chime: Bool {
        get { prefs[\.bootChime] }
        set { prefs[\.bootChime] = newValue; list() }
    }
    /// The version on the OP-Z has the chime, or has not, against what is wanted.
    public var chimeDiffers: Bool {
        guard let k = lastKnown.map({ String($0.split(separator: " ").first ?? "") }), (Catalog.number(of: k) ?? 0) >= 11 else { return false }
        return k.hasSuffix(Catalog.quiet) == chime
    }

    private func list() {
        guard let catalog else { return }
        let names = Set(catalog.builds.map(\.label))
        // of a version with a chime and one without, the one that is wanted
        func wanted(_ l: String) -> Bool { l.hasSuffix(Catalog.quiet) ? !chime : chime || !names.contains(l + Catalog.quiet) }
        let ours = catalog.builds.filter { Catalog.number(of: $0.label) != nil && wanted($0.label) }
            .sorted { Catalog.number(of: $0.label)! < Catalog.number(of: $1.label)! }.reversed().map { label, b -> Version in
                let r = catalog.promised[label] == nil ? nil : releases.first { $0.label == label }, im = images.first { $0.label == label }
                return Version(label: label, title: r?.title ?? b.title, summary: b.description ?? "", notes: r?.notes ?? b.notes ?? Self.sentences(b.description ?? ""),
                               detail: [r.map { "RELEASED \($0.date) · SIGNED" }, im?.ldr.map { "\($0.count) BYTES · SHA256 \(Hash.sha256($0).prefix(12))" }]
                                   .compactMap { $0 }.joined(separator: " · "),
                               downloaded: catalog.promised[label] != nil, reason: im?.reason ?? "")
            }
        versions = ours + [Version(label: "original", title: "TE \(Original.firmware)", summary: "What teenage engineering ships. The way back.", notes: [], detail: "",
                                   downloaded: false, reason: "")]
    }

    /// Newer than what the OP-Z is known to have.
    public func isNews(_ label: String) -> Bool {
        guard let n = Catalog.number(of: label), let known = lastKnown else { return false }
        return n > (Catalog.number(of: String(known.split(separator: " ").first ?? "")) ?? (known == "original" ? 0 : .max))
    }

    private static func sentences(_ s: String) -> [String] {
        s.split(separator: ".").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    public var newest: Version? { versions.first { $0.label != "original" } }

    public func titleOf(_ label: String) -> String {
        versions.first { label == $0.label || label.hasPrefix($0.label + " ") }?.title ?? label
    }

    /// The last thing read off (or written to) the OP-Z, also from an earlier day.
    public private(set) var lastKnown: String? {
        get { prefs[\.lastInstalled] }
        set { prefs[\.lastInstalled] = newValue }
    }

    /// A write that did not finish, from this run of the app or an earlier one: what the OP-Z has is not whole. Cleared by the next
    /// check or install that does finish.
    public private(set) var interrupted: String? {
        get { prefs[\.interruptedWrite] }
        set { prefs[\.interruptedWrite] = newValue }
    }

    /// What was read is not a whole OS this app knows: only TE's original may be written over it (the writer refuses the rest too).
    public var notWhole: Bool { installed.map { $0.hasPrefix("unknown") || $0.hasPrefix("no os.ldr") } ?? false }

    /// The build on it (an installed animation's name is not a build's).
    private var installedBuild: String? { installed == nil ? nil : lastKnown }

    public func isOn(_ label: String) -> Bool { interrupted == nil && (installedBuild ?? lastKnown) == label }

    /// A version newer than the one the OP-Z is known to have.
    public var notice: String? { newest.flatMap { isNews($0.label) ? "NEW: " + $0.title.uppercased().replacingOccurrences(of: "GALAX-Z ", with: "") : nil } }

    /// Where the person is in updating (1–5).
    public func step(backedUp: Bool) -> Int {
        if justInstalled != nil { return 5 }
        if !ports.isEmpty { return installed == nil ? 3 : 4 }
        return backedUp ? 2 : 1
    }

    public var mustRead: Bool { !hasOriginal }

    public func ready(_ label: String) -> Bool { notReady(label) == nil }

    /// Why a version cannot be installed right now.
    public func notReady(_ label: String) -> String? {
        if busy != nil || !loaded { return "" }
        if mustPowerCycle { return "SWITCH THE OP-Z OFF FIRST" }
        if ports.isEmpty { return "NOT IN UPDATE MODE" }
        if installed == nil || !hasOriginal { return "READ IT FIRST (STEP 3)" }
        if notWhole, label != "original" { return "INSTALL TE'S ORIGINAL FIRST" }
        if let im = images.first(where: { $0.label == label }), im.ldr == nil { return "NOT FLASHABLE" }
        return nil
    }

    // MARK: releases

    /// A release file, opened: checked, kept, listed.
    public func open(_ url: URL) {
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
    public func lookForReleases(asked: Bool = false) {
        guard asked || prefs[\.lookForReleases], !looking, asked || Date().timeIntervalSince(lookedAt) > 3600 else { return }
        looking = true
        lookedAt = Date()
        let have = Set(catalog?.builds.map(\.label) ?? []).union(releases.map(\.label)), store = releaseStore
        Thread.detachNewThread { [main] in
            var got = 0, failed: Error?, noList: Error?
            do {
                let feed = try JSONDecoder().decode(ReleaseFeed.self, from: Hub.fetch(ReleaseFeed.defaultURL, limit: 1_000_000))
                for e in feed.releases.sorted(by: { $0.number > $1.number }).prefix(8) where !have.contains(e.label) {
                    guard let u = ReleaseFeed.url(of: e, feed: ReleaseFeed.defaultURL) else { continue }
                    do {                    // one bad file does not keep the others away
                        try store.add(Hub.fetch(u, limit: 16_000_000))
                        got += 1
                    } catch { failed = error }
                }
            } catch { noList = error }
            main.post { [weak self] in
                guard let self else { return }
                self.looking = false
                if got > 0 { self.taken() }
                guard asked else { return }
                if let noList { self.result = (false, "No list of releases could be read: \(noList)") }
                else { self.result = failed.map { (false, "A release was refused: \($0)") } ?? (true, got > 0 ? "\(got) new" : "nothing newer") }
            }
        }
    }

    /// One file over HTTPS, waited for (on a thread of the hub's own).
    static func fetch(_ url: URL, limit: Int) throws -> Data {
        guard url.scheme == "https" || url.isFileURL else { throw ReleaseError("not a secure address") }
        var q = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        q.httpShouldHandleCookies = false
        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var out: Result<Data, Error> = .failure(ReleaseError("no answer"))
        let session = URLSession(configuration: .ephemeral)
        session.dataTask(with: q) { d, response, error in
            if let error { out = .failure(error) }
            else if let h = response as? HTTPURLResponse, h.statusCode != 200 {
                out = .failure(ReleaseError(h.statusCode == 404 ? "there is none at the address yet" : "the server said \(h.statusCode)"))
            } else if let d { out = d.count <= limit ? .success(d) : .failure(ReleaseError("too big")) }
            done.signal()
        }.resume()
        done.wait()
        session.finishTasksAndInvalidate()
        return try out.get()
    }

    private func build(_ original: [UInt8]) throws {
        guard let catalog else { return }
        self.original = original
        images = try catalog.images(original: original)
        list()
    }

    /// Whether the OP-Z plays exactly this animation (by its frames, so an edited one is not mistaken for the old).
    public func playing(_ a: LEDAnimation) -> Bool {
        guard let onTheOPZ, let layout else { return false }
        return onTheOPZ == store.bytes(a, layout)
    }

    public func refreshPorts() {
        let now = mode.ports()
        guard now != ports else { return }
        ports = now
        if now.isEmpty, busy == nil {       // it went away: what it has next is not known; what went wrong still is
            installed = nil
            if result?.ok == true, justInstalled == nil { result = nil }
        }
    }

    // MARK: jobs

    public func check() { run("check") }

    public func flash(_ label: String) {
        guard let im = images.first(where: { $0.label == label }), notReady(label) == nil else { return }
        run("flash \(label)", im)
    }

    /// The builds an animation can be flashed onto; a check or a flash sets `base` to what the OP-Z has.
    public var bases: [(String, String)] { catalog?.playerBuilds.map { ($0.label, $0.build.title) } ?? [] }
    public var base: String {
        get { prefs[\.animationBase] }
        set { prefs[\.animationBase] = newValue }
    }

    /// An animation can be installed right now.
    public var animationReady: Bool { !notWhole && busy == nil && !mustPowerCycle && !ports.isEmpty && installed != nil && hasOriginal }

    /// That build, playing this animation.
    public func flash(_ a: LEDAnimation) {
        guard let catalog, let layout, let original, animationReady else { return }
        do { run("flash \(a.name)", try catalog.bootImage(original: original, a, layout: layout, on: base)) }
        catch { result = (false, "\(error)") }
    }

    private func run(_ job: String, _ image: FirmwareImage? = nil) {
        guard busy == nil, loaded, !mustPowerCycle, let catalog else { return }
        refreshPorts()
        keepAwake(true)
        busy = job; log = []; progress = nil; result = nil; justInstalled = nil; writing = image != nil
        // what may be written: the catalog's images and the one asked for
        let images = self.images.filter { $0.label != image?.label } + (image.map { [$0] } ?? [])
        let choice = mode.choose(), open = mode.open, prefs = self.prefs, backups = self.backups, main = self.main
        let say: @Sendable (String) -> Void = { line in main.post { [weak self] in self?.log.append(line) } }
        Thread.detachNewThread {
            var outcome: (Bool, String) = (true, "done")
            var found: String?, recovered: [UInt8]?, frames: [UInt8]?, build: String?
            var began = false              // something has been (or may have been) written
            var folder: URL?
            do {
                let port = try choice.get()
                let f = try Hub.osRun(backups)
                folder = f
                say("port \(port)")
                let con = UpdateConsole(try open(port), images: images, log: say)
                if let image {
                    say("== flash \(image.title)")
                    _ = try con.flash(image, all: images, saveBackup: {
                        try Hub.save($0, to: f)
                        // from here on it is being written: kept on disk, so that even a crash of this computer leaves the warning
                        prefs[\.interruptedWrite] = image.title
                        began = true
                    }, name: { catalog.name(images, ldr: $0, crc: $1) }) { name, done, of in
                        main.post { [weak self] in self?.progress = (name, done, of) }
                    }
                    found = image.label
                    frames = image.ldr.flatMap(catalog.frames(playedBy:))
                    build = image.ldr.flatMap(catalog.underPlayer)?.label
                } else {
                    try con.start()
                    let (ldr, crc) = try con.readInstalled()
                    try Hub.save([("os.crc32", crc), ("os.ldr", ldr)].compactMap { n, d in d.map { (name: n, data: $0) } }, to: f)
                    if images.isEmpty, let ldr { recovered = catalog.recoverOriginal(from: ldr) }
                    found = images.isEmpty ? (recovered != nil ? "a known image (original recovered)" : "unknown os.ldr")
                                           : catalog.name(images, ldr: ldr, crc: crc)
                    frames = ldr.flatMap(catalog.frames(playedBy:))
                    build = ldr.flatMap(catalog.underPlayer)?.label
                    say("installed: \(found!)")
                }
            } catch {
                outcome = (false, "\(error)")
                say("STOPPED: \(error)")
                if case ConsoleError.stalled = error { main.post { [weak self] in self?.mustPowerCycle = true } }
            }
            let final = outcome, playing = frames, base = build, wrote = began, recoveredOriginal = recovered, found2 = found, runFolder = folder
            main.post { [weak self] in
                guard let self else { return }
                if let recoveredOriginal { self.adopt(original: recoveredOriginal) }
                if final.0, let found = found2 {
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
                self.keepAwake(false)
                if let base { self.base = base }
                self.result = final
                self.busy = nil
                if let runFolder {
                    try? Data(self.log.joined(separator: "\r\n").utf8).write(to: runFolder.appendingPathComponent("log.txt"), options: .atomic)
                }
            }
        }
    }

    /// The person says it was switched off (the port going away only says that the cable came out: the OP-Z has a battery).
    public func switchedOff() {
        refreshPorts()
        if ports.isEmpty { mustPowerCycle = false }
    }

    private func adopt(original: [UInt8]) {
        guard catalog != nil, Original.matches(original) else { return }
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? Data(original).write(to: originalURL, options: .atomic)
        do { try build(original); log.append("TE's 1.2.45 kept in \(originalURL.path)") }
        catch { problem = "\(error)" }
    }

    // MARK: files

    public var originalURL: URL { support.appendingPathComponent("os-1.2.45.ldr") }

    static func cachedOriginal(_ url: URL) -> [UInt8]? {
        guard let d = try? Data(contentsOf: url), Original.matches([UInt8](d)) else { return nil }
        return [UInt8](d)
    }

    /// A folder of its own for one run of the update mode: `Backups\os\flash-<time>` (the Mac's name for it).
    static func osRun(_ backups: URL, _ now: Date = Date()) throws -> URL {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        let url = backups.appendingPathComponent("os").appendingPathComponent("flash-\(f.string(from: now))")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func save(_ files: [(name: String, data: [UInt8])], to folder: URL) throws {
        for f in files { try Data(f.data).write(to: folder.appendingPathComponent("installed-\(f.name)"), options: .atomic) }
    }
}

/// Your own animations: edited copies of the library's, kept in `settings.json`.
public final class AnimationStore {
    private let prefs: Prefs
    private var rendered: [LEDAnimation: [[RGBW]]] = [:]
    private var packed: [LEDAnimation: [UInt8]] = [:]

    init(prefs: Prefs) { self.prefs = prefs }

    public var mine: [LEDAnimation] { prefs[\.myAnimations] }

    public func isMine(_ a: LEDAnimation) -> Bool { mine.contains { $0.id == a.id } }

    /// A new animation to edit, starting from `a` (not kept until saved).
    public func copy(of a: LEDAnimation) -> LEDAnimation {
        LEDAnimation(id: "my-" + UUID().uuidString.prefix(8).lowercased(), name: "My \(a.name)", pattern: a.pattern, style: a.style)
    }

    public func save(_ a: LEDAnimation) {
        var all = mine
        if let i = all.firstIndex(where: { $0.id == a.id }) { all[i] = a } else { all.append(a) }
        prefs[\.myAnimations] = all
    }

    public func delete(_ a: LEDAnimation) { prefs[\.myAnimations] = mine.filter { $0.id != a.id } }

    /// An animation's frames, rendered once per look.
    public func frames(_ a: LEDAnimation, _ layout: LEDLayout) -> [[RGBW]] {
        if let f = rendered[a] { return f }
        if rendered.count > 60 { rendered.removeAll() }      // an edit makes a new look at every slider step
        let f = a.frames(layout)
        rendered[a] = f
        return f
    }

    /// Its frames as the OP-Z holds them.
    public func bytes(_ a: LEDAnimation, _ layout: LEDLayout) -> [UInt8] {
        if let b = packed[a] { return b }
        if packed.count > 60 { packed.removeAll() }
        let b = a.bytes(layout)
        packed[a] = b
        return b
    }
}
