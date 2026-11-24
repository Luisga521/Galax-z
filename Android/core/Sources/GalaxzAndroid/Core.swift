import DotKit
import Foundation
import OPZLink
import OPZModel
import OPZPlay
import OPZStage
#if canImport(Android)
import Android
#endif
#if os(Windows)
import WinSDK
#endif

/// Seconds of the monotonic clock: the one Android's `System.nanoTime` and its MIDI time stamps count in (on Windows, the
/// performance counter, which Galax-z's MIDI sender waits on too).
func monotonic() -> Double {
    #if os(Windows)
    var count = LARGE_INTEGER(), frequency = LARGE_INTEGER()
    QueryPerformanceCounter(&count)
    QueryPerformanceFrequency(&frequency)
    return Double(count.QuadPart) / Double(frequency.QuadPart)
    #else
    var t = timespec()
    clock_gettime(CLOCK_MONOTONIC, &t)
    return Double(t.tv_sec) + Double(t.tv_nsec) / 1e9
    #endif
}

/// The connection to the OP-Z (or the demo one) and the screen: `App/Live.swift` for Android, without tasks or actors.
/// The Kotlin app calls in from its threads; `JNI.swift` holds one lock around every call, so this runs as on one thread.
final class Core {
    enum Source: Equatable { case opz, demo }
    enum Status: Equatable { case noOPZ, hello, loading(Int), live, lost }

    let stage = Stage()
    let canvas = DotCanvas(width: 1, height: 1)
    private(set) var source = Source.opz
    private(set) var status = Status.noOPZ
    let folder: URL

    /// The OP-Z Android has opened: its name, and whether over Bluetooth.
    private(set) var device: (name: String, bluetooth: Bool)?
    /// What to do while there is no OP-Z (the Kotlin side knows: no cable, Bluetooth off, ...).
    var linkLine = "PLUG IN YOUR OP-Z WITH A USB-C CABLE" { didSet { if linkLine != oldValue { feedStage() } } }
    var linkHint = "" { didSet { if linkHint != oldValue { feedStage() } } }
    /// Where the OP-Z is heard, if that can be chosen now.
    var out: String? { didSet { if out != oldValue { feedStage() } } }

    private(set) var client = StateSyncClient()
    private var files: FileClient?
    private(set) var settings: OPZSettings?
    private var stageSettings: OPZSettings?
    private var settingsAsked = false
    private var bank: Bank?
    private var revisions = (bank: 0, edit: 0, panel: 0)
    private var address: PatternAddress?
    private var tempo: Int?
    private var midiAsk = 0.0
    private var lastTick = 0.0
    private var loadReport = LoadReport.Collector()
    private var lastLoad: LoadReport?
    private var demo: Demo?
    private var reader = MIDIBytes()

    /// What has been heard from the OP-Z on this connection (Settings › LINK CHECK).
    private(set) var check = LinkCheck()
    private(set) var checkStart = 0.0
    /// The double-trigger test: every key press timed from its MIDI note while the test screen is open.
    var keyTest = KeyTest()
    private(set) var keyTestOpen = false
    private var nextDemoPress = 0.0
    /// The OP-Z said MIDI start (its own notes would count as presses).
    private(set) var opzPlaying = false
    /// The backup of the ten projects and the sound settings (read-only), and where it goes.
    enum Backup: Equatable { case idle, running(Int), saved(Date, new: Bool), failed(String) }
    private(set) var backup = Backup.idle
    var backups: URL?
    var autoBackup = false
    private var backupClient: FileClient?
    private(set) var rawSettings: [String: [UInt8]] = [:]
    private var backedUp = false, backupAsked = false

    /// For the Kotlin side to send: SysEx at once, short messages at their time (seconds, monotonic; 0 = now).
    private(set) var outgoing: [(at: Double, bytes: [UInt8])] = []
    /// Something to draw since the screen last asked.
    var changed = true

    var now: Double { monotonic() }

    /// The chops: MODULE's instrument.
    let sampler: Sampler
    /// Other keyboards, knobs and pads.
    let controllers: Controllers

    init(folder: URL, demo startInDemo: Bool) {
        self.folder = folder
        sampler = Sampler(folder: folder)
        controllers = Controllers(folder: folder)
        autoBackup = (try? Data(contentsOf: folder.appendingPathComponent("autoBackup.json"))) == Data("1".utf8)
        stage.clock = { monotonic() }
        takeFromStage()
        sampler.changed = { [weak self] in self?.changed = true }
        sampler.start(stage, settings: folder)
        controllers.stage = stage
        controllers.changed = { [weak self] in self?.changed = true }
        if startInDemo { useDemo(true) } else { feedStage() }
    }

    // MARK: in

    /// Android opened an OP-Z, or lost it (nil).
    func connected(_ name: String?, bluetooth: Bool) {
        let new = name.map { ($0, bluetooth) }
        guard new?.0 != device?.name || new?.1 != device?.bluetooth else { return }
        device = new
        guard source == .opz else { return }
        stage.letGo()
        restart()
        if device != nil { hello() }
        refresh()
    }

    /// Bytes from the OP-Z, as Android's MIDI service hands them over.
    func midi(_ bytes: UnsafeBufferPointer<UInt8>, at time: Double) {
        guard source == .opz else { return }
        reader.feed(bytes, time: time, frame: { received($0) }, key: { key($0) })
    }

    /// Now and then (the Kotlin side calls every 20 ms or so): what is due to the OP-Z, the demo's answers.
    func tick() {
        let now = self.now
        if let demo { for f in demo.due(now: now, bank: bank) { received(f) } }
        sampler.tick(now)
        guard now - lastTick >= 0.06 else { return }
        lastTick = now
        send(client.tick(now: now) + (files?.tick(now: now) ?? []) + (backupClient?.tick(now: now) ?? []))
        if keyTestOpen, source == .demo, now >= nextDemoPress { demoPress(now) }
        refresh()
    }

    func useDemo(_ on: Bool) {
        guard on != (source == .demo) else { return }
        restart()
        stage.letGo()
        if on {
            demo = Demo(now: now)
            source = .demo
            hello()
        } else {
            demo = nil
            source = .opz
            if device != nil { hello() }
        }
        refresh()
    }

    /// Ask the OP-Z for the whole project and its sounds again.
    func reload() {
        send(client.requestBank("asked for by the user", now: now))
        files = nil
        settingsAsked = false
        refresh()
    }

    func takeOutgoing() -> [(at: Double, bytes: [UInt8])] {
        defer { outgoing.removeAll(keepingCapacity: true) }
        return outgoing
    }

    /// What did not fit this time goes first next time.
    func putBack(_ left: [(at: Double, bytes: [UInt8])]) { outgoing.insert(contentsOf: left, at: 0) }

    // MARK: the OP-Z's side

    private func received(_ frame: [UInt8]) {
        let now = self.now
        check.heard(frame, at: now)
        send(client.receive(frame, now: now) + (files?.receive(frame, now: now) ?? []) + (backupClient?.receive(frame, now: now) ?? []))
        refresh()
    }

    /// Whose notes come on a channel: as the OP-Z's own settings have it.
    private func track(_ channel: Int) -> Int? {
        guard let m = client.midi else { return channel }
        return m.track(channel: channel, selected: client.panel.track ?? stage.track)
    }

    private func key(_ event: KeyEvent) {
        check.heard(event)
        switch event {
        case .playing(let on, let t):
            opzPlaying = on
            stage.midi(playing: on, at: t)
        case .clock:
            stage.midiClock()
            guard stage.playhead.playing else { return }
        case .noteOn(let n, let channel, let v, let t):
            if keyTestOpen { keyTest.noteOn(n, channel: channel, at: t); return }
            guard let ch = track(channel) else { return }
            if ch == 13 { stage.module(note: n, velocity: v) }
            if ch == 14 { stage.light(note: n, on: true) }
            let (taken, report) = loadReport.note(n, velocity: v, at: t)
            if let report { lastLoad = report; feedStage() }
            if !taken { check.late(monotonic() - t); stage.noteOn(channel: ch, note: n, velocity: v, at: t) }
        case .cc(let n, let v, let channel):
            guard let ch = track(channel) else { return }
            if ch == 13 { stage.module(cc: n, value: v) }
        case .noteOff(let n, let channel, let t):
            if keyTestOpen { keyTest.noteOff(n, channel: channel, at: t); return }
            guard let ch = track(channel) else { return }
            if ch == 13 { stage.moduleOff(note: n) }
            if ch == 14 { stage.light(note: n, on: false) }
            stage.noteOff(channel: ch, note: n)
        }
        changed = true
    }

    private func restart() {
        client = StateSyncClient()
        bank = nil
        stage.midi(playing: false)
        revisions = (0, 0, 0)
        address = nil
        tempo = nil
        reader = MIDIBytes()
        files = nil
        settings = nil
        settingsAsked = false
        midiAsk = 0
        outgoing.removeAll()
        check = LinkCheck()
        checkStart = now
        opzPlaying = false
        backupClient = nil
        rawSettings = [:]
        backedUp = false
        if case .running = backup { backup = .idle }
    }

    private func hello() { send(client.tick(now: now, forceHello: true)) }

    private func send(_ frames: [[UInt8]]) {
        for f in frames {
            if let demo { demo.send(f, now: now) } else if device != nil { outgoing.append((0, f)) }
        }
    }

    /// The MIDI settings: till they come, then now and then, for they can be changed on the OP-Z. It only reads.
    private func askMIDI() {
        midiAsk = now + (client.midi == nil ? 3 : 20)
        send([SysEx.frame(0x0F)])
    }

    // MARK: what the screen shows

    /// What is played, moved and chosen on the screen: out to the OP-Z, and kept. Nothing goes by itself.
    private func takeFromStage() {
        let j = JSONDecoder()
        if let s = read("player").flatMap({ try? j.decode(Player.Settings.self, from: $0) }) { stage.player.settings = s }
        if let b = read("performBay").flatMap({ try? j.decode(PerformBay.self, from: $0) }) { stage.bay = b }
        stage.lights = read("lightsLane").map { $0 == Data("1".utf8) } ?? false
        stage.out = { [weak self] e in self?.play(e) }
        stage.kept = { [weak self] in
            guard let self else { return }
            let e = JSONEncoder()
            self.write("player", try? e.encode(self.stage.player.settings))
            self.write("performBay", try? e.encode(self.stage.bay))
            self.write("lightsLane", Data((self.stage.lights ? "1" : "0").utf8))
        }
    }

    private func read(_ key: String) -> Data? { try? Data(contentsOf: folder.appendingPathComponent("\(key).json")) }
    private func write(_ key: String, _ data: Data?) {
        guard let data else { return }
        try? data.write(to: folder.appendingPathComponent("\(key).json"), options: .atomic)
    }

    private func play(_ e: Player.Event) {
        if source == .opz { outgoing.append((e.at, client.midi?.placed(e.command) ?? e.command.bytes)) }
        else if case .noteOn(let t, let n, let v) = e.command { stage.noteOn(channel: t, note: n, velocity: v) }   // the demo only shows it
        else if case .noteOff(let t, let n) = e.command { stage.noteOff(channel: t, note: n) }
        changed = true
    }

    /// Copy what changed out of the client.
    private func refresh() {
        if client.bankRevision != revisions.bank || client.editRevision != revisions.edit || (client.bank == nil) != (bank == nil) {
            bank = client.bank
        }
        address = client.playAddress ?? client.bankAddress
        let t = client.global?.tempo
        if t != tempo { tempo = t; sampler.set(tempo: t) }
        status = currentStatus()
        refreshSounds()
        refreshBackup()
        let r = (bank: client.bankRevision, edit: client.editRevision, panel: client.panelRevision)
        if r != revisions || stageStale() { revisions = r; feedStage() }
    }

    private func stageStale() -> Bool {
        let i = stage.input
        return i.link != link || i.address != address || i.tempo != tempo || (i.bank == nil) != (bank == nil) || i.linkName != linkName
            || i.linkLine != linkLine || stageSettings != settings || i.swing != client.global?.swing || i.machines != client.machines
    }

    /// Read plugs.json and slotConfiguration.json once the project is in (one transfer at a time on a slow link).
    private func refreshSounds() {
        if bank != nil, !settingsAsked, client.partsIncoming == nil {
            let f = FileClient()
            files = f
            settingsAsked = true
            send(f.start(now: now))
        }
        if source == .opz, device != nil, bank != nil, client.partsIncoming == nil, files == nil, now > midiAsk { askMIDI() }
        guard let f = files else { return }
        switch f.phase {
        case .done:
            if let p = f.files[FileClient.plugs], let s = f.files[FileClient.slotConfiguration],
               let read = OPZSettings(plugsJSON: p, slotsJSON: s) {
                settings = read
                check.gotSounds()
                rawSettings = ["settings/plugs.json": p, "settings/slotConfiguration.json": s]
            }
            files = nil
        case .failed: files = nil
        default: break
        }
    }

    // MARK: key test

    func openKeyTest() { keyTestOpen = true; nextDemoPress = now }
    func closeKeyTest() { keyTestOpen = false }

    /// Demo mode: steady presses across the keyboard, where three keys sometimes bounce 6–24 ms after a press.
    private func demoPress(_ now: Double) {
        nextDemoPress = now + Double.random(in: 0.18...0.42)
        let k = Int.random(in: 0..<KeyTest.keys), note = KeyTest.defaultFirstNote + k
        keyTest.noteOn(note, channel: 4, at: now)
        if [3, 10, 17].contains(k), Int.random(in: 0..<3) == 0 {
            keyTest.noteOff(note, channel: 4, at: now + 0.003)
            keyTest.noteOn(note, channel: 4, at: now + Double.random(in: 0.006...0.024))
        }
        keyTest.noteOff(note, channel: 4, at: now + 0.07)
        changed = true
    }

    // MARK: backups

    /// Back up again now (Settings), even if this connection was already backed up.
    func backUpNow() {
        guard source == .opz, backupClient == nil, device != nil else { return }
        backedUp = false
        backupAsked = true
        if settings == nil { reload() }
        refresh()
    }

    /// The projects (download ids 3–12 = project 1–10), after the sounds: one transfer at a time. Reads only.
    private func refreshBackup() {
        if let f = backupClient {
            switch f.phase {
            case .done:
                var files = rawSettings
                for n in 1...10 {
                    guard let d = f.files[UInt32(n + 2)] else { return failBackup("project \(n) missing") }
                    files[String(format: "projects/project%02d.opz", n)] = d
                }
                backupClient = nil
                backedUp = true
                guard let backups else { return failBackup("no folder for backups") }
                do {
                    let (_, new) = try Backups.save(files, device: device?.name, root: backups)
                    backup = .saved(Date(), new: new)
                } catch { backup = .failed("\(error)") }
            case .failed(let why): failBackup(why)
            default:
                let n = f.files.count
                if backup != .running(n) { backup = .running(n) }
            }
            return
        }
        guard source == .opz, !backedUp, settings != nil, files == nil, client.partsIncoming == nil, rawSettings.count == 2,
              (autoBackup && device?.bluetooth == false) || backupAsked
        else { return }
        backupAsked = false
        let f = FileClient(fileIDs: (1...10).map { UInt32($0 + 2) })
        backupClient = f
        backup = .running(0)
        send(f.start(now: now))
    }

    private func failBackup(_ why: String) {
        backupClient = nil
        backedUp = true      // no retry loop; BACK UP NOW tries again
        backup = .failed(why)
    }

    private func currentStatus() -> Status {
        if source == .opz && device == nil { return .noOPZ }
        if let n = client.partsIncoming { return .loading(n) }
        if client.isLive(at: now) { return bank == nil ? .hello : .live }
        return bank == nil ? .hello : .lost
    }

    private var link: StageInput.Link {
        switch status {
        case .noOPZ: .searching
        case .hello: .hello
        case .loading(let n): bank != nil ? .live : .loading(n)
        case .live: .live
        case .lost: .lost
        }
    }

    private var linkName: String { source == .demo ? "DEMO" : device?.bluetooth == true ? "BLUETOOTH" : "USB" }

    private func feedStage() {
        var i = stage.input
        i.link = link
        i.linkName = linkName
        i.linkLine = linkLine
        i.linkHint = linkHint
        i.bank = bank
        i.revision = client.bankRevision &* 1_000_003 &+ client.editRevision
        i.address = address
        i.tempo = tempo
        i.swing = client.global?.swing
        i.panel = client.panel
        i.machines = client.machines
        i.midi = client.midi
        i.red = client.red
        i.load = lastLoad
        i.out = out
        if i.revision != stage.input.revision || i.address != stage.input.address || stageSettings != settings {
            stageSettings = settings
            for t in 0..<16 {
                let sound = bank.flatMap { Sound(plug: Int($0.track(address?.pattern ?? 0, t).plug), settings: settings) }
                i.sounds[t] = sound
                i.slots[t] = sound.flatMap { settings?.slot(of: $0.plug, track: t) }
            }
        }
        stage.input = i
        changed = true
    }
}
