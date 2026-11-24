import Foundation
import Observation
import OPZLink
import OPZModel
import OPZPlay
import OPZStage
import QuartzCore

/// The connection to the OP-Z (or the demo one) and what the screens show: a StateSync replica of the open project.
@MainActor @Observable
final class Live {
    enum Status: Equatable { case noOPZ, hello, loading(Int), live, lost }
    enum Source: Equatable { case opz, demo }

    private(set) var source: Source = .opz
    private(set) var status: Status = .noOPZ
    private(set) var deviceName: String?
    private(set) var transport: MIDITransport.Transport?
    /// Looking for the OP-Z over Bluetooth while no cable is in.
    private(set) var bluetooth: BluetoothLink.State = .idle
    /// The project as it is now; the screens get it through `stage`, not by observation (it changes with every edit).
    @ObservationIgnored private(set) var bank: Bank?
    @ObservationIgnored private var revisions = (bank: 0, edit: 0, panel: 0)
    var hasProject = false
    /// Banks read since the connection (one, unless an edit could not be followed).
    var bankReads: Int { client.bankRevision }
    /// What the matrix shows, and what to call when it changed.
    @ObservationIgnored let stage: Stage = {
        let s = Stage()
        s.clock = { CACurrentMediaTime() }
        return s
    }()
    @ObservationIgnored var stageChanged: () -> Void = {}
    /// Where the OP-Z is heard.
    let audio = AudioOut()
    /// What the hub has to say in the corner of the screen.
    var notice: String? { didSet { feedStage() } }
    @ObservationIgnored private var loadReport = LoadReport.Collector()
    @ObservationIgnored private var lastLoad: LoadReport?
    /// The active project and pattern.
    private(set) var address: PatternAddress?
    private(set) var tempo: Int?
    /// What has been heard from the OP-Z on this connection (Settings › LINK CHECK).
    @ObservationIgnored private(set) var check = LinkCheck()
    @ObservationIgnored private var checkStart = 0.0
    /// The OP-Z's sounds and slots (plugs.json, slotConfiguration.json), read once the project is in.
    private(set) var settings: OPZSettings?
    private(set) var readingSounds = false
    /// The automatic backup of the ten projects and the sound settings (read-only), once per connection.
    enum Backup: Equatable { case idle, running(Int), saved(Date, new: Bool), failed(String) }
    private(set) var backup: Backup = .idle
    /// Back up by itself at every USB connection: off unless chosen in Settings.
    var autoBackup = UserDefaults.standard.bool(forKey: "autoBackup") {
        didSet { UserDefaults.standard.set(autoBackup, forKey: "autoBackup"); if autoBackup { refresh() } }
    }
    /// The double-trigger test: every key press timed from its MIDI note while the test screen is open.
    var keyTest = KeyTest()
    private(set) var keyTestOpen = false
    /// The OP-Z said MIDI start (its own notes would count as presses).
    private(set) var opzPlaying = false

    @ObservationIgnored private var client = StateSyncClient()
    @ObservationIgnored private var files: FileClient?
    @ObservationIgnored private var settingsAsked = false
    @ObservationIgnored private var backupClient: FileClient?
    @ObservationIgnored private var rawSettings: [String: [UInt8]] = [:]
    @ObservationIgnored private var backedUp = false
    /// BACK UP NOW: also over Bluetooth, where the automatic one does not run (3.4 MB of SysEx takes minutes there and
    /// holds up every pattern refresh behind it).
    @ObservationIgnored private var backupAsked = false
    @ObservationIgnored private var midiAsk = 0.0
    @ObservationIgnored private var midiWait: Task<Void, Never>?
    @ObservationIgnored private let deltas = DeltaLog()
    @ObservationIgnored private var demoPresses: Task<Void, Never>?
    @ObservationIgnored private let midi = MIDITransport()
    @ObservationIgnored private let ble = BluetoothLink()
    @ObservationIgnored private var connection: MIDITransport.Connection?
    @ObservationIgnored private var demo: DemoPort?

    private var now: Double { ProcessInfo.processInfo.systemUptime }

    init(demo startInDemo: Bool = false) {
        takeFromStage()
        client.log = { print("statesync:", $0) }
        client.onDelta = { [weak self] payload in self?.deltas.record(payload) }
        midi.onSetupChanged = { [weak self] in self?.scan() }
        audio.changed = { [weak self] in self?.feedStage() }
        ble.onChange = { [weak self] in
            guard let self else { return }
            if self.bluetooth != self.ble.state { self.bluetooth = self.ble.state }
            if case .linked = self.ble.state { self.waitForMIDI() }
        }
        listen(midi.frames, as: .opz)
        let keys = midi.keys
        Task { [weak self] in
            for await event in keys {
                guard let self, self.source == .opz else { continue }
                self.key(event)
            }
        }
        if startInDemo { useDemo(true) } else { scan() }
        Task { [weak self] in
            while true {
                try? await Task.sleep(for: .milliseconds(60))
                guard let self else { return }
                self.send(self.client.tick(now: self.now) + (self.files?.tick(now: self.now) ?? [])
                          + (self.backupClient?.tick(now: self.now) ?? []))
                self.refresh()
            }
        }
    }

    func useDemo(_ on: Bool) {
        guard on != (source == .demo) else { return }
        restart()
        if on {
            ble.stop()
            audio.cable(false)
            let port = DemoPort()
            demo = port
            source = .demo
            listen(port.frames, as: .demo)
            hello()
            port.play()
            port.machines()
            port.dials()
        } else {
            demo?.stop()
            demo = nil
            source = .opz
            connection = nil // so the scan finds the OP-Z as new and says hello
            scan()
        }
        refresh()
    }

    /// Ask the OP-Z for the whole project and its sounds again (until live edits are decoded, this shows edits and
    /// sound changes made on the OP-Z).
    func reload() {
        send(client.requestBank("asked for by the user", now: now))
        readSounds()
        refresh()
    }

    // key test --------------------------------------------------------------------------------------------------------

    func openKeyTest() {
        keyTestOpen = true
        if source == .demo { startDemoPresses() }
    }

    func closeKeyTest() {
        keyTestOpen = false
        demoPresses?.cancel()
        demoPresses = nil
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
            if opzPlaying != on { opzPlaying = on }
            stage.midi(playing: on, at: t)
            stageChanged()
        case .clock:
            stage.midiClock()
            if stage.playhead.playing { stageChanged() }
        case .noteOn(let n, let channel, let v, let t):
            if keyTestOpen { return keyTest.noteOn(n, channel: channel, at: t) }
            guard let ch = track(channel) else { return }
            if ch == 13 { stage.module(note: n, velocity: v) }
            if ch == 14 { stage.light(note: n, on: true) }
            let (taken, report) = loadReport.note(n, velocity: v, at: t)
            if let report { lastLoad = report; feedStage() }
            if !taken { check.late(CACurrentMediaTime() - t); stage.noteOn(channel: ch, note: n, velocity: v, at: t); stageChanged() }
        case .cc(let n, let v, let channel):
            if channel == 15, (105...108).contains(n), stage.screenDial(n - 105, value: v) { stageChanged(); return }     // SCREEN + a dial
            guard let ch = track(channel) else { return }
            if ch == 13 { stage.module(cc: n, value: v); stageChanged() }
        case .noteOff(let n, let channel, let t):
            guard let ch = track(channel) else { return }
            if ch == 13 { stage.moduleOff(note: n) }
            if ch == 14 { stage.light(note: n, on: false) }
            if keyTestOpen { keyTest.noteOff(n, channel: channel, at: t) } else { stage.noteOff(channel: ch, note: n); stageChanged() }
        }
    }

    /// Demo mode: steady presses across the keyboard, where three keys sometimes bounce 6–24 ms after a press.
    private func startDemoPresses() {
        demoPresses?.cancel()
        demoPresses = Task { [weak self] in
            let bouncy: Set<Int> = [3, 10, 17]
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int.random(in: 180...420)))
                guard let self, !Task.isCancelled else { return }
                let k = Int.random(in: 0..<KeyTest.keys)
                let note = KeyTest.defaultFirstNote + k
                let t = self.now
                self.key(.noteOn(note: note, channel: 4, velocity: 100, time: t))
                if bouncy.contains(k), Int.random(in: 0..<3) == 0 {
                    let bounce = Double.random(in: 0.006...0.024)
                    self.key(.noteOff(note: note, channel: 4, time: t + 0.003))
                    self.key(.noteOn(note: note, channel: 4, velocity: 100, time: t + bounce))
                }
                self.key(.noteOff(note: note, channel: 4, time: t + 0.07))
            }
        }
    }

    /// The sound on a track in the active pattern, named.
    func sound(_ track: Int) -> Sound? {
        guard let bank else { return nil }
        return Sound(plug: Int(bank.track(address?.pattern ?? 0, track).plug), settings: settings)
    }

    /// The slot key (1…10) a track's sound sits on.
    func slot(_ track: Int) -> Int? {
        guard let sound = sound(track) else { return nil }
        return settings?.slot(of: sound.plug, track: track)
    }

    private func restart() {
        client = StateSyncClient()
        client.log = { print("statesync:", $0) }
        client.onDelta = { [weak self] payload in self?.deltas.record(payload) }
        bank = nil
        stage.midi(playing: false)
        revisions = (0, 0, 0)
        hasProject = false
        address = nil
        tempo = nil
        startCheck()
        forgetSounds()
    }

    func frameShown(_ seconds: Double) { check.shown(seconds) }

    private func startCheck() {
        check = LinkCheck()
        checkStart = now
    }

    /// The link check as a file to share: `Documents/Diagnostics/link-<time>.txt`.
    func saveCheck() throws -> URL {
        let dir = Backups.root.deletingLastPathComponent().appending(path: "Diagnostics")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        let url = dir.appending(path: "link-\(f.string(from: Date())).txt")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let text = check.text(device: deviceName ?? (source == .demo ? "demo" : "no OP-Z"), over: source == .demo ? "demo" : transport == .bluetooth ? "Bluetooth" : "USB",
                              seconds: now - checkStart, banksRead: client.bankRevision, refetches: client.refetches,
                              also: ["Galax-z \(version)", ProcessInfo.processInfo.operatingSystemVersionString, "showing \(stage.page.name) track \(stage.track + 1)"], tracks: (client.midi?.lines ?? ["MIDI settings: not answered"]) + stage.report)
        try Data(text.utf8).write(to: url, options: .atomic)
        return url
    }

    /// Read plugs.json and slotConfiguration.json over the file service (beside the StateSync session).
    private func readSounds() {
        guard files == nil else { return }
        let f = FileClient()
        f.log = { print("files:", $0) }
        files = f
        settingsAsked = true
        readingSounds = true
        send(f.start(now: now))
    }

    /// The MIDI settings: till they come, then now and then, for they can be changed on the OP-Z. It only reads.
    private func askMIDI() {
        midiAsk = now + (client.midi == nil ? 3 : 20)
        midi.send(SysEx.frame(0x0F))
    }

    private func forgetSounds() {
        midiAsk = 0
        files = nil
        settings = nil
        settingsAsked = false
        readingSounds = false
        backupClient = nil
        rawSettings = [:]
        backedUp = false
        if case .running = backup { backup = .idle }
    }

    /// Back up again now (Settings), even if this connection was already backed up.
    func backUpNow() {
        guard source == .opz, backupClient == nil else { return }
        backedUp = false
        backupAsked = true
        if settings == nil { reload() }
        refresh()
    }

    /// The projects (download ids 3–12 = project 1–10, op-free patterns.md, proven on this unit), after the sounds:
    /// one transfer at a time. Reads only; the files land in Backups with the sound settings.
    private func refreshBackup() {
        if let f = backupClient {
            switch f.phase {
            case .done:
                var files = rawSettings
                for n in 1...10 {
                    guard let d = f.files[UInt32(n + 2)] else { return fail("project \(n) missing") }
                    files[String(format: "projects/project%02d.opz", n)] = d
                }
                backupClient = nil
                backedUp = true
                let device = deviceName
                do {
                    let (_, new) = try Backups.save(files, device: device)
                    backup = .saved(Date(), new: new)
                } catch { backup = .failed("\(error)") }
            case .failed(let why): fail(why)
            default:
                let n = f.files.count
                if backup != .running(n) { backup = .running(n) }
            }
            return
        }
        guard source == .opz, !backedUp, settings != nil, files == nil, client.partsIncoming == nil, rawSettings.count == 2,
              (autoBackup && transport == .usb) || backupAsked
        else { return }
        backupAsked = false
        let f = FileClient(fileIDs: (1...10).map { UInt32($0 + 2) })
        f.log = { print("backup:", $0) }
        backupClient = f
        backup = .running(0)
        send(f.start(now: now))
    }

    private func fail(_ why: String) {
        backupClient = nil
        backedUp = true      // no retry loop; Settings › BACK UP NOW tries again
        backup = .failed(why)
    }

    /// MIDI devices came or went: take the OP-Z (a cable first), start a session on a new one, and look over
    /// Bluetooth while there is none.
    private func scan() {
        guard source == .opz else { return }
        midi.connectToOPZ()
        let found = midi.connection
        if found != connection {
            connection = found
            stage.letGo()
            client.reset()
            stage.midi(playing: false)
            forgetSounds()
            if found != nil { startCheck(); hello() }
        }
        deviceName = found?.name
        transport = found?.transport
        controllers.bridge?.set(opz: midi.destinationEndpoint, channels: client.midi?.channels)
        audio.cable(found?.transport == .usb)
        #if targetEnvironment(macCatalyst)
        // On the Mac, cable only: the Mac is where the hub runs, and searching Bluetooth there would take the OP-Z
        // from the iPad (a Bluetooth OP-Z takes one link; two Galax-z on one OP-Z break both).
        #else
        if found == nil { ble.start() } else { ble.stop() }
        #endif
        refresh()
    }

    /// Bluetooth is linked, but CoreMIDI may show the OP-Z late, or without a setup-changed note: look again four
    /// times a second for 10 s, and ask the Bluetooth driver again after 3 s.
    private func waitForMIDI() {
        midiWait?.cancel()
        midiWait = Task { [weak self] in
            for i in 1...40 {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                if self.connection != nil || self.source != .opz { return }
                if i == 12 { print("midi: still no OP-Z, asking the Bluetooth driver again"); self.ble.reactivate() }
                self.scan()
            }
            print("midi: linked over Bluetooth but no OP-Z among the MIDI sources:", MIDITransport.sourceNames())
        }
    }

    private func hello() { send(client.tick(now: now, forceHello: true)) }

    /// One reader per port for its whole life; frames from the port not in use are dropped.
    private func listen(_ frames: AsyncStream<[UInt8]>, as from: Source) {
        Task { [weak self] in
            for await frame in frames {
                guard let self else { return }
                guard from == self.source else { continue }
                self.check.heard(frame, at: self.now)
                self.send(self.client.receive(frame, now: self.now) + (self.files?.receive(frame, now: self.now) ?? [])
                          + (self.backupClient?.receive(frame, now: self.now) ?? []))
                self.refresh()
            }
        }
    }

    /// What is played, moved and chosen on the screen: out to the OP-Z, and kept. Nothing goes by itself.
    private func takeFromStage() {
        let d = UserDefaults.standard, j = JSONDecoder()
        if let s = d.data(forKey: "player").flatMap({ try? j.decode(Player.Settings.self, from: $0) }) { stage.player.settings = s }
        if let b = d.data(forKey: "performBay").flatMap({ try? j.decode(PerformBay.self, from: $0) }) { stage.bay = b }
        stage.out = { [weak self] e in self?.play(e) }
        stage.kept = { [weak self] in
            guard let self else { return }
            let e = JSONEncoder()
            d.set(try? e.encode(self.stage.player.settings), forKey: "player")
            d.set(try? e.encode(self.stage.bay), forKey: "performBay")
            d.set(self.stage.lights, forKey: "lightsLane")
        }
        sampler.start(stage)
        sampler.changed = { [weak self] in self?.stageChanged() }
        stage.lights = d.bool(forKey: "lightsLane")
        controllers.stage = stage
        controllers.changed = { [weak self] in self?.stageChanged() }
        stage.selected = { [weak self] t in self?.controllers.bridge?.set(track: t) }
        controllers.bridge?.set(track: stage.track)
    }

    private func play(_ e: Player.Event) {
        if source == .opz { midi.send(short: client.midi?.placed(e.command) ?? e.command.bytes, at: e.at) }
        else if case .noteOn(let t, let n, let v) = e.command { stage.noteOn(channel: t, note: n, velocity: v) }       // the demo only shows it
        else if case .noteOff(let t, let n) = e.command { stage.noteOff(channel: t, note: n) }
        stageChanged()
    }
    /// The chops: MODULE's instrument.
    let sampler = Sampler()
    /// Other keyboards, knobs and pads.
    let controllers = Controllers()
    /// The OP-Z's MIDI in is on (hold TEMPO + SCREEN, key 2); nil until its settings are read.
    private(set) var midiIn: Bool?

    private func send(_ frames: [[UInt8]]) {
        for f in frames {
            if source == .demo { demo?.send(f) } else { midi.send(f) }
        }
    }

    /// Copy what changed out of the client (Observation fires on every set, so only set what differs).
    private func refresh() {
        if client.bankRevision != revisions.bank || client.editRevision != revisions.edit || (client.bank == nil) != (bank == nil) {
            if client.bankRevision != revisions.bank, let new = client.bank { deltas.bank(new.bytes, before: bank?.bytes) }
            bank = client.bank
        }
        if hasProject != (bank != nil) { hasProject = bank != nil }
        let a = client.playAddress ?? client.bankAddress
        if a != address { address = a }
        let t = client.global?.tempo
        if t != tempo { tempo = t; sampler.set(tempo: t) }
        let s = currentStatus()
        if s != status { status = s }
        refreshSounds()
        refreshBackup()
        let r = (bank: client.bankRevision, edit: client.editRevision, panel: client.panelRevision)
        if r != revisions || stageStale() { revisions = r; feedStage() }
    }

    /// Something besides the project moved: the link, the address, the tempo, the sounds.
    private func stageStale() -> Bool {
        let i = stage.input
        return i.link != link || i.address != address || i.tempo != tempo || (i.bank == nil) != (bank == nil) || i.linkName != linkName
            || i.linkLine != linkLine || stageSettings != settings || i.swing != client.global?.swing
    }
    @ObservationIgnored private var stageSettings: OPZSettings?

    private var link: StageInput.Link {
        switch status {
        case .noOPZ: .searching
        case .hello: .hello
        case .loading(let n): hasProject ? .live : .loading(n)
        case .live: .live
        case .lost: .lost
        }
    }

    private var linkName: String { source == .demo ? "DEMO" : transport == .bluetooth ? "BLUETOOTH" : "USB" }

    /// What to do while there is no OP-Z.
    private var linkLine: String {
        #if targetEnvironment(macCatalyst)
        return "PLUG IN YOUR OP-Z WITH A USB-C CABLE"
        #else
        switch bluetooth {
        case .connecting(let name): return "LINKING \(name.uppercased())"
        case .linked(let name): return "\(name.uppercased()) FOUND, OPENING MIDI"
        case .off: return "BLUETOOTH IS OFF · OR PLUG IN A CABLE"
        case .unauthorized: return "ALLOW BLUETOOTH FOR GALAX-Z IN SETTINGS"
        case .unsupported: return "PLUG IN YOUR OP-Z"
        case .searching, .idle: return "LOOKING FOR YOUR OP-Z"
        }
        #endif
    }

    /// Who made this build (GALAXZ_BYLINE), shown in Settings › Credits; empty in a build nobody named.
    static let byline = (Bundle.main.object(forInfoDictionaryKey: "GalaxzByline") as? String ?? "").trimmingCharacters(in: .whitespaces)

    /// Everything the screens show, as it is now.
    private func feedStage() {
        var i = stage.input
        i.link = link
        i.linkName = linkName
        i.linkLine = linkLine
        #if targetEnvironment(macCatalyst)
        stage.showsPairing = deviceName == nil && source == .opz
        i.linkHint = stage.showsPairing ? "OR PAIR IT OVER BLUETOOTH" : ""
        #else
        i.linkHint = stage.showsPairing ? "SWITCH IT ON, CLOSE TE'S OP-Z APP, OR PLUG IN A CABLE" : ""
        #endif
        i.bank = bank
        i.revision = client.bankRevision &* 1_000_003 &+ client.editRevision
        i.address = address
        i.tempo = tempo
        i.swing = client.global?.swing
        i.panel = client.panel
        i.machines = client.machines
        i.midi = client.midi
        controllers.bridge?.set(opz: source == .opz ? midi.destinationEndpoint : 0, channels: client.midi?.channels)
        if client.midi?.incoming != midiIn { midiIn = client.midi?.incoming }
        i.red = client.red
        i.load = lastLoad
        i.notice = notice
        i.out = audio.line
        if i.revision != stage.input.revision || i.address != stage.input.address || stageSettings != settings {
            stageSettings = settings
            for t in 0..<16 { i.sounds[t] = sound(t); i.slots[t] = slot(t) }
        }
        stage.input = i
        stageChanged()
    }

    /// Bluetooth has found nothing for a while: offer Apple's pairing list on the screen.
    func offerPairing(_ on: Bool) {
        guard stage.showsPairing != on else { return }
        stage.showsPairing = on
        feedStage()
    }

    /// Start reading the sounds once the project is in (the bank first: one transfer at a time on a slow link);
    /// take them when the file client is done.
    private func refreshSounds() {
        if bank != nil, !settingsAsked, client.partsIncoming == nil { readSounds() }
        if source == .opz, bank != nil, client.partsIncoming == nil, files == nil, now > midiAsk { askMIDI() }
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
            readingSounds = false
        case .failed:
            files = nil // RELOAD tries again
            readingSounds = false
        default:
            break
        }
    }

    private func currentStatus() -> Status {
        if source == .opz && deviceName == nil { return .noOPZ }
        if let n = client.partsIncoming { return .loading(n) }
        if client.isLive(at: now) { return bank == nil ? .hello : .live }
        return bank == nil ? .hello : .lost
    }
}
