import DotKit
import OPZModel
import OPZPlay
import ChopKit

/// What a finger can take hold of.
enum Grip: Equatable {
    case gain(Int), mute(Int), sound(Int, Int, across: Bool), pattern(Int)
    /// A pad of PLAY: which, and its note.
    case key(Int, Int)
    case choose(Choice), move(Int), load(String?), amount
    /// A chop's pad, a dial, an effect's light, an effect's dial, the chosen chop's pitch, level or pan.
    case chop(Int), chopDial(Int), effect(Int), effectDial(Int), edit(Int)
    /// A value of the open list (-1: between them, to scroll it), and its top, which closes it.
    case pick(Int), unpick
}

/// A choice of PLAY or PERFORM: the left of it is the one before, the right the next. One of values goes through them under a
/// dragged finger; one of many values opens them all from its middle.
enum Choice: Int, CaseIterable {
    case key, scale, tool, hold, progression, vary, groove, order, strum, octave, scope, latch, gallery, shelf, panic, kit, source, record, cut, view, module, keys, reverse, choke, chopOn, lights, remove, scene, showAuto

    /// Values to go through, not a thing done or a switch (a kit is loaded, so it goes one at a time).
    var scrubs: Bool {
        switch self {
        case .key, .scale, .tool, .hold, .progression, .vary, .groove, .order, .strum, .octave, .scope, .shelf, .source, .cut, .view: true
        default: false
        }
    }
    /// So many that they are better seen at once.
    var long: Bool {
        switch self {
        case .key, .scale, .tool, .progression, .groove, .octave, .shelf: true
        default: false
        }
    }
}

struct Held { let grip: Grip; let x, y: Int; var moved = false; var value: Double; let box: DotRect }

/// The OP-Z as the stage knows it, for the moves.
struct Here: MoveSource {
    let s: Stage
    init(_ s: Stage) { self.s = s }
    func sound(_ t: Int, _ p: Int) -> Int { Int((s.grid.sound[t & 15][p] * 127).rounded()) }
    func gain(_ t: Int) -> Int { Int((s.gain(t) * 127).rounded()) }
    func muted(_ t: Int) -> Bool { s.grid.muted[t & 15] }
    func lastNote(_ t: Int) -> Int { s.lastNote[t & 15] }
}

extension Stage {
    /// A track's gain: as it was just moved here, else as the OP-Z says.
    func gain(_ t: Int) -> Double { gains[t] ?? input.panel.levels.map { Double($0[t]) / 255 } ?? 1 }

    /// The value a control sets, 0-127 (for what is learned).
    public func value(of t: Target) -> Int? {
        switch t {
        case .sound(let n, let p): OPZ.params.indices.contains(p) ? Here(self).sound(n ?? track, p) : nil
        case .gain(let n): Here(self).gain(n ?? track)
        case .encoder(let e): encoded(e).flatMap { value(of: .sound(track: nil, param: $0)) }
        case .chopDial(let d): chops.dials.indices.contains(d) ? Int((chops.dials[d] * 127).rounded()) : nil
        default: nil
        }
    }

    /// Set it, here and there.
    public func set(_ t: Target, to v: Int) {
        switch t {
        case .sound(let n, let p): setSound(n ?? track, p, Double(v) / 127)
        case .gain(let n): setGain(n ?? track, Double(v) / 127)
        case .encoder(let e): if let p = encoded(e) { setSound(track, p, Double(v) / 127) }
        case .chopDial(let d): setChopDial(d, Double(v) / 127)
        default: break
        }
    }

    /// A control was pressed (velocity over 0) or let go. True if it was the app's to do.
    public func press(_ t: Target, velocity: Int) -> Bool {
        let down = velocity > 0
        switch t {
        case .mute(let n): if down { mute(n ?? track) }
        case .move(let p): down ? beginMove(p) : endMove(p)
        case .select(let n): if down { select(track: n) }
        case .page(let by): if down { turn(by) }
        case .pattern(let p): if down { say(.pattern(project: input.address?.project ?? 0, p)) }
        case .nextPattern: if down { say(.nextPattern) }
        case .previousPattern: if down { say(.previousPattern) }
        case .play: if down { say(playhead.playing ? .stop : .start) }
        case .chop(let n): down ? strike(n, Double(velocity) / 127, id: 3000 + n) : ask(.stop(id: 3000 + n))
        case .sound, .encoder, .gain, .chopDial, .keys: return false
        }
        return true
    }

    /// What encoder `e` turns: a sound value of the selected track, on its page as the dials show it (nil on a page of the OS's own).
    func encoded(_ e: Int) -> Int? {
        guard (0..<4).contains(e), machinePage == nil, redPage == nil else { return nil }
        let pages = Palette.pages(track, samples: input.sounds[track]?.origin == .samples)
        let on = min((input.machines.flatMap { $0.track == track ? $0.page : nil } ?? input.panel.page) & 3, pages.count - 1)
        return pages[on].params[e]
    }

    /// A key of another keyboard.
    public func keyDown(_ note: Int, velocity: Int) { for e in player.press(1000 + note, note: note, velocity: velocity, at: moment) { out(e) } }
    public func keyUp(_ note: Int) { for e in player.release(1000 + note, at: moment) { out(e) } }

    func strike(_ n: Int, _ velocity: Double, id: Int) { ask(.start(n, velocity: velocity, id: id, semitones: 0)) }
    private func setChopDial(_ d: Int, _ v: Double) {
        guard chops.dials.indices.contains(d) else { return }
        chops.dials[d] = min(1, max(0, v))
        ask(.dial(d, chops.dials[d]))
    }

    /// A note of MODULE: a chop, or in KEYS the chosen one at its pitch. C of the OP-Z's lowest key on: the pads in order.
    public func module(note: Int, velocity: Int) {
        guard chops.module else { return }
        if chops.keys { ask(.start(chops.chosen, velocity: Double(velocity) / 127, id: 5000 + note, semitones: Double(note - 60))) }
        else { strike((((note - 53) % 24) + 24) % 24, Double(velocity) / 127, id: 5000 + note) }
    }
    public func moduleOff(note: Int) { ask(.stop(id: 5000 + note)) }
    /// A dial of MODULE (its CCs 1-8 as the OP-Z numbers its own; not yet seen on a unit).
    public func module(cc: Int, value: Int) { if chops.module, (1...8).contains(cc) { setChopDial(cc - 1, Double(value) / 127) } }
    /// A note of LIGHTS: a move of PERFORM, for as long as it lasts.
    public func light(note: Int, on: Bool) {
        guard lights else { return }
        let p = (((note - 53) % 16) + 16) % 16
        on ? beginMove(p) : endMove(p)
    }

    func say(_ c: OPZCommand) { out(.init(moment, c)) }

    private func setSound(_ t: Int, _ p: Int, _ v: Double) {
        let v = min(1, max(0, v)), n = Int((v * 127).rounded())
        let was = Int((grid.sound[t][p] * 127).rounded())
        grid.sound[t][p] = v
        knobs[t][p].target = v
        if n != was { say(.sound(track: t, param: p, value: n)) }
    }
    private func setGain(_ t: Int, _ v: Double) {
        let v = min(1, max(0, v)), was = Int((gain(t) * 127).rounded()), n = Int((v * 127).rounded())
        gains[t] = v
        if n != was { say(.gain(track: t, value: n)) }
    }
    private func mute(_ t: Int) {
        grid.muted[t].toggle()
        say(.mute(track: t, on: grid.muted[t]))
    }
    func beginMove(_ p: Int) {
        guard bay.slots.indices.contains(p), let m = bay.slots[p] else { return }
        for c in performer.begin(p, m, selected: min(7, track), beat: beat, from: Here(self)) { say(c) }
    }
    func endMove(_ p: Int) { for c in performer.end(p) { say(c) } }

    // MARK: fingers

    /// Whether there is something to hold at a dot.
    public func holds(_ x: Int, _ y: Int) -> Bool { grip(x, y) != nil }
    private func grip(_ x: Int, _ y: Int) -> (DotRect, Grip)? {
        for (r, what) in touches.reversed() where r.contains(x, y) { if case .grip(let g) = what { return (r, g) }; if case .track = what { continue }; return nil }
        return nil
    }

    /// A finger comes down: true if it took hold of something.
    public func grab(_ id: Int, _ x: Int, _ y: Int) -> Bool {
        guard let (box, g) = grip(x, y) else { return false }
        wake()
        var v = 0.0
        switch g {
        case .gain(let t): v = gain(t)
        case .sound(let t, let p, _): v = grid.sound[t][p]
        case .key(let k, let n):
            let near = 1 - min(1, max(0, Double(y - box.y) / Double(max(1, box.h))))           // higher on a pad is softer
            for e in player.press(k, note: n, velocity: min(127, player.settings.velocity - Int(near * 40) + 20), at: moment) { out(e) }
        case .move(let p):
            pad = p
            if gallery { break }
            if latch, performer.active.contains(p) { endMove(p) } else { beginMove(p) }
        case .amount: v = bay.slots[pad]?.amount ?? 0
        case .chop(let n):
            chops.chosen = n
            strike(n, 0.75 + 0.25 * min(1, max(0, Double(y - box.y) / Double(max(1, box.h)))), id: 4000 + id)
        case .chopDial(let d): v = chops.dials[d]
        case .effectDial(let k): v = chops.effects[chops.effect].dials[k]
        case .edit(let k):
            guard chops.list.indices.contains(chops.chosen) else { break }
            let c = chops.list[chops.chosen]
            v = k == 0 ? Double(c.pitch + 24) / 48 : k == 1 ? c.level : c.pan
        case .choose(let c): v = Double(values(c)?.at ?? 0)
        case .pick, .unpick: v = Double(picking?.scroll ?? 0)
        default: break
        }
        grips[id] = Held(grip: g, x: x, y: y, value: v, box: box)
        return true
    }

    public func drag(_ id: Int, _ x: Int, _ y: Int) {
        guard var h = grips[id] else { return }
        wake()
        if abs(x - h.x) + abs(y - h.y) > 3 { h.moved = true }
        grips[id] = h
        guard h.moved else { return }
        switch h.grip {
        case .gain(let t): setGain(t, h.value + Double(h.y - y) / Double(max(30, h.box.h)))
        case .sound(let t, let p, let across): setSound(t, p, h.value + (across ? Double(x - h.x) / Double(max(16, h.box.w)) : Double(h.y - y) / 80))
        case .amount: setAmount(h.value + Double(x - h.x) / Double(max(40, h.box.w)))
        case .chopDial(let d): setChopDial(d, h.value + Double(h.y - y) / 80)
        case .effectDial(let k):
            chops.effects[chops.effect].dials[k] = min(1, max(0, h.value + Double(h.y - y) / 80))
            ask(.effect(chops.effects[chops.effect]))
        case .edit(let k):
            guard chops.list.indices.contains(chops.chosen) else { break }
            let n = min(1, max(0, h.value + Double(h.y - y) / 80))
            if k == 0 { chops.list[chops.chosen].pitch = Int((n * 48).rounded()) - 24 } else if k == 1 { chops.list[chops.chosen].level = n } else { chops.list[chops.chosen].pan = n }
        case .key(let k, _):                                                                   // over to another pad
            guard let (_, g) = grip(x, y), case .key(let k2, let n2) = g, k2 != k else { return }
            for e in player.release(k, at: moment) + player.press(k2, note: n2, at: moment) { out(e) }
            grips[id] = Held(grip: g, x: x, y: y, moved: true, value: 0, box: h.box)
        case .choose(let c):                                                                   // through the values, as far as it goes
            guard c.scrubs, let n = values(c)?.names.count else { break }
            let dx = x - h.x, dy = h.y - y, by = abs(dx) >= abs(dy) ? dx : dy
            choose(c, to: Int(h.value) + by / (n > 24 ? 4 : n > 8 ? 6 : 10), keep: false)
        case .pick, .unpick:
            guard var p = picking else { break }
            p.scroll = min(p.most, max(0, Int(h.value) + h.y - y))
            picking = p
        default: break
        }
    }

    public func release(_ id: Int, _ x: Int, _ y: Int) {
        guard let h = grips.removeValue(forKey: id) else { return }
        wake()
        switch h.grip {
        case .key(let k, _): for e in player.release(k, at: moment) { out(e) }
        case .move(let p): if !latch, !gallery { endMove(p) }
        case .gain(let t): if !h.moved { _ = tapTrack(t) }
        case .mute(let t): if !h.moved { mute(t) }
        case .pattern(let p): if !h.moved { say(.pattern(project: input.address?.project ?? 0, p)) }
        case .choose(let c):                                                                   // let go off it: nothing
            if h.moved { if c.scrubs { kept() } } else if h.box.contains(x, y) { touched(c, x, h.box) }
        case .pick(let i): if !h.moved, let p = picking, i >= 0 { picking = nil; choose(p.choice, to: i) }
        case .unpick: if !h.moved { picking = nil }
        case .load(let m): if !h.moved { endMove(pad); bay.load(m.flatMap(Move.named), at: pad); kept() }
        case .amount: kept()
        case .chop: ask(.stop(id: 4000 + id))
        case .effect(let k):
            if !h.moved {
                // touched: shown. Touched again: on, or off
                if chops.effect == k || x >= h.box.maxX - h.box.h { chops.effects[k].on.toggle(); ask(.effect(chops.effects[k])) }
                chops.effect = k
                ask(.keep)
            }
        case .chopDial, .effectDial: ask(.keep)
        case .edit: ask(.edited(chops.list))
        case .sound: break
        }
    }

    private func tapTrack(_ t: Int) -> Bool { if track == t { page = .track } else { select(track: t) }; return true }
    private func setAmount(_ v: Double) {
        guard var m = bay.slots[pad] else { return }
        m.amount = min(1, max(0.05, v))
        bay.slots[pad] = m
    }

    static let strums = [0, 0.03, 0.06, 0.12, 0.25]

    /// What a choice can be, in order, and which it is now: nil for a thing done or a switch.
    func values(_ c: Choice) -> (names: [String], at: Int)? {
        func of<T: CaseIterable & Equatable>(_ v: T, _ name: (T) -> String) -> ([String], Int) { let a = Array(T.allCases); return (a.map(name), a.firstIndex(of: v)!) }
        let s = player.settings
        switch c {
        case .key: return (Palette.noteNames, s.tonic)
        case .scale: return of(s.scale, \.name)
        case .tool: return of(s.tool, \.name)
        case .hold: return of(s.hold, \.name)
        case .order: return of(s.order, \.name)
        case .progression: return (Progressions.all.map(\.name), Progressions.index(named: s.progression) ?? 0)
        case .vary: return ((0...4).map { "\($0 * 25)" }, Int((s.vary * 4).rounded()))
        case .groove:
            let names = Groove.library.map(\.name)
            return (["OFF"] + names, s.groove.flatMap { names.firstIndex(of: $0) }.map { $0 + 1 } ?? 0)
        case .strum: return (Self.strums.map { $0 == 0 ? "OFF" : "\(Int($0 * 1000)) MS" }, Self.strums.firstIndex(of: s.strum) ?? 0)
        case .octave: return ((-3...3).map { $0 > 0 ? "+\($0)" : "\($0)" }, octave + 3)
        case .scope: return bay.slots[pad].map { of($0.scope, \.name) }
        case .shelf: return (Move.families, shelf % Move.families.count)
        case .source: return of(chops.source, \.name)
        case .cut: return of(chops.cut, \.name)
        case .view: return of(chops.view, \.name)
        default: return nil
        }
    }

    /// Choose the `i`th value, as that many taps would (past the end it comes round; OCTAVE stops).
    func choose(_ c: Choice, to i: Int, keep: Bool = true) {
        guard let (names, at) = values(c) else { return }
        let n = names.count, to = c == .octave ? min(n - 1, max(0, i)) : (i % n + n) % n
        if to != at { choose(c, to - at, keep: keep) }
    }

    func choose(_ c: Choice, _ by: Int, keep: Bool = true) {
        func next<T: CaseIterable & Equatable>(_ v: T) -> T { let a = Array(T.allCases); return a[((a.firstIndex(of: v)! + by) % a.count + a.count) % a.count] }
        func place(_ i: Int, _ n: Int) -> Int { ((i + by) % n + n) % n }
        switch c {
        case .key: player.settings.tonic = place(player.settings.tonic, 12)
        case .scale: player.settings.scale = next(player.settings.scale)
        case .tool: player.settings.tool = next(player.settings.tool)
        case .hold:
            player.settings.hold = next(player.settings.hold)
            if player.settings.hold == .off { for e in player.unhold(at: moment) { out(e) } }
        case .progression:
            let all = Progressions.all
            player.settings.progression = all[place(Progressions.index(named: player.settings.progression) ?? 0, all.count)].name
        case .vary: player.settings.vary = Double(place(Int((player.settings.vary * 4).rounded()), 5)) / 4
        case .groove:
            let names: [String?] = [nil] + Groove.library.map(\.name)
            for e in player.silence(at: moment) { out(e) }                        // the two end their notes their own ways
            player.settings.groove = names[place(names.firstIndex(of: player.settings.groove) ?? 0, names.count)]
        case .order: player.settings.order = next(player.settings.order)
        case .strum:
            let s = Self.strums
            player.settings.strum = s[place(s.firstIndex(of: player.settings.strum) ?? 0, s.count)]
        case .octave: octave = max(-3, min(3, octave + by))
        case .scope: if var m = bay.slots[pad] { endMove(pad); m.scope = next(m.scope); bay.slots[pad] = m }
        case .latch: latch.toggle(); if !latch { for c in performer.endAll() { say(c) } }
        case .gallery: gallery.toggle(); for c in performer.endAll() { say(c) }
        case .shelf: shelf = place(shelf, Move.families.count)
        case .panic: letGo()
        case .kit: ask(.kit(by))
        case .source: chops.source = next(chops.source)
        case .record: ask(chops.recording ? .stopRecording : chops.source == .file ? .open : .record(chops.source))
        case .cut: chops.cut = next(chops.cut); ask(.cut(chops.cut))
        case .view: chops.view = next(chops.view)
        case .module: chops.module.toggle(); ask(.keep)
        case .keys: chops.keys.toggle(); ask(.keep)
        case .reverse, .choke, .chopOn:
            guard chops.list.indices.contains(chops.chosen) else { break }
            if c == .reverse { chops.list[chops.chosen].reverse.toggle() } else if c == .choke { chops.list[chops.chosen].choke.toggle() } else { chops.list[chops.chosen].on.toggle() }
            ask(.edited(chops.list))
        case .lights: lights.toggle(); if !lights { for k in 0..<16 { endMove(k) } }
        case .remove: ask(.removeKit)
        case .scene: show.turn(by, at: time, bar: showBar.rounded(.down))
        case .showAuto: show.auto.toggle()
        }
        if keep { kept() }
    }
}
