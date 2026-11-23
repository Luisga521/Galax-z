import OPZModel
import OPZPlay
import SwiftUI

/// Touch what a control should do, move the control: learned.
struct LearnScreen: View {
    let controllers: Controllers
    @State private var track: Int?
    @State private var family = 0

    private let families = ["SOUND", "MIX", "PERFORM", "CHOPS", "PATTERNS", "KEYS"]
    private var targets: [Target] {
        switch family {
        case 0: OPZ.params.indices.map { .sound(track: track, param: $0) }
        case 1: [.gain(track: track), .mute(track: track), .sound(track: track, param: 10), .sound(track: track, param: 6), .sound(track: track, param: 7)]
            + (track == nil ? (0..<8).map { .gain(track: $0) } + (0..<8).map { .mute(track: $0) } : [])
        case 2: (0..<PerformBay.pads).map { .move(pad: $0) }
        case 3: (0..<8).map { .chopDial($0) } + (0..<24).map { .chop($0) }
        case 4: [.play, .previousPattern, .nextPattern] + (0..<16).map { .pattern($0) }
        default: [.keys, .page(by: -1), .page(by: 1)] + (0..<16).map { .select(track: $0) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(controllers.devices.isEmpty ? "No controller is connected. Plug one into this device, or pair it over Bluetooth MIDI." : controllers.devices.joined(separator: " · "))
                        .font(Face.mono(12, .bold))
                    Text(waiting).font(Face.mono(11)).foregroundStyle(controllers.learned.waiting == nil ? Face.ink.opacity(0.55) : Face.yellow)
                    if let l = controllers.last { Text(l).font(Face.mono(10)).opacity(0.45) }
                }
                Picker("Kind", selection: $family) { ForEach(families.indices, id: \.self) { Text(families[$0]).tag($0) } }.pickerStyle(.segmented)
                if family < 2 {
                    Picker("Track", selection: $track) {
                        Text("THE SELECTED TRACK").tag(Int?.none)
                        ForEach(0..<16, id: \.self) { Text("\($0 + 1) \(OPZ.trackNames[$0].uppercased())").tag(Int?.some($0)) }
                    }
                    .tint(Face.yellow)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(targets, id: \.self) { t in button(t) }
                }
                if !controllers.learned.entries.isEmpty {
                    HStack {
                        Text("LEARNED").font(Face.mono(13, .bold)).tracking(2)
                        Spacer()
                        Button("FORGET ALL") { controllers.forgetAll() }.buttonStyle(PillButton())
                    }
                    .padding(.top, 8)
                    ForEach(controllers.learned.entries) { e in row(e) }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            .frame(maxWidth: 1000).frame(maxWidth: .infinity)
        }
        .onDisappear { controllers.learn(nil) }
    }

    private var waiting: String {
        controllers.learned.waiting.map { "Move or press what should be \($0.name). Touch it again to leave it." } ?? "Touch what you want to control, then move a knob or press a pad."
    }

    private func button(_ t: Target) -> some View {
        let on = controllers.learned.waiting == t, has = controllers.learned.controls(of: t)
        return Button { controllers.learn(t) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(t.name).font(Face.mono(11, .bold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(has.first.map { "\($0.device) \($0.name)" } ?? "not learned").font(Face.mono(9)).opacity(has.isEmpty ? 0.35 : 0.8).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(on ? Face.yellow.opacity(0.25) : Face.ink.opacity(has.isEmpty ? 0.05 : 0.12)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(on ? Face.yellow : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func row(_ e: Learned.Entry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(e.target.name).font(Face.mono(12, .bold))
                Text("\(e.control.device) · \(e.control.name)").font(Face.mono(10)).opacity(0.55)
            }
            Spacer()
            if e.target.continuous, e.control.kind == .cc {
                Picker("Way", selection: Binding(get: { e.way }, set: { controllers.set($0, for: e.control) })) {
                    Text("KNOB").tag(Learned.Way.absolute); Text("ENDLESS").tag(Learned.Way.relative)
                }
                .pickerStyle(.segmented).frame(width: 170)
            }
            Button("FORGET") { controllers.forget(e.control) }.buttonStyle(PillButton())
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Face.ink.opacity(0.05)))
    }
}
