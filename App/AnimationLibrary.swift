import OPZFirmware
import SwiftUI
import UIKit

/// The boot animations Galax-z can put on the OP-Z, the library's and your own: each live on a drawing of its keys, an
/// editor for its look, and on the Mac a FLASH that writes Galax-z v2 playing it (only the frames change).
struct AnimationLibrary: View {
    let hub: Hub
    @State private var editing: LEDAnimation?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if Hub.canFlash {
                @Bindable var hub = hub
                Picker("FLASH ANIMATIONS ONTO", selection: $hub.base) {
                    ForEach(hub.bases, id: \.0) { Text($0.1).tag($0.0) }
                }
                .pickerStyle(.menu).font(Face.mono(10, .bold)).tint(Face.yellow).fixedSize().disabled(hub.busy != nil)
            }
            if !hub.store.mine.isEmpty { section("YOUR ANIMATIONS", hub.store.mine) }
            section("BOOT ANIMATIONS", LEDAnimation.library)
        }
        .sheet(item: $editing) { a in
            if let layout = hub.layout { AnimationEditor(store: hub.store, layout: layout, animation: a) }
        }
    }

    private func section(_ title: String, _ list: [LEDAnimation]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(Face.mono(9)).tracking(3).opacity(0.45).padding(.top, 6)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                ForEach(list) { item($0) }
            }
        }
    }

    private func item(_ a: LEDAnimation) -> some View {
        card {
            if let layout = hub.layout {
                LEDPreview(layout: layout, frames: hub.store.frames(a, layout), fps: 24).frame(height: 92)
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(a.name.uppercased()).font(Face.mono(13, .bold)).tracking(2).lineLimit(1)
                        if hub.playing(a) {
                            Text("ON THE OP-Z").font(Face.mono(8, .bold)).tracking(2).foregroundStyle(Face.background)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Face.track(8), in: Capsule())
                        }
                    }
                    Text(a.blurb).font(Face.mono(10)).opacity(0.6).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if !a.isTest {
                    Button("EDIT") { editing = hub.store.isMine(a) ? a : hub.store.copy(of: a) }.buttonStyle(PillButton())
                }
            }
            if Hub.canFlash {
                HoldButton(title: "HOLD TO INSTALL", question: "Write \(hub.titleOf(hub.base)) playing \(a.name) to the OP-Z?") { hub.flash(a) }
                    .disabled(!hub.animationReady)
                Text("WRITES \(hub.titleOf(hub.base).uppercased()) PLAYING IT").font(Face.mono(9)).opacity(hub.isOn(hub.base) ? 0.45 : 1)
                    .foregroundStyle(hub.isOn(hub.base) || hub.installed == nil ? Face.ink : Face.yellow)
            }
        }
    }
}

/// The look of one animation: its pattern, three colours or black and white, and how strong each layer is. Live.
struct AnimationEditor: View {
    let store: AnimationStore
    let layout: LEDLayout
    @State var animation: LEDAnimation
    @Environment(\.dismiss) private var dismiss

    private var named: Bool { !animation.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                TextField("Name", text: $animation.name)
                    .font(Face.mono(18, .bold)).autocorrectionDisabled()
                    .padding(.horizontal, 12).padding(.vertical, 6).overlay(Capsule().stroke(Face.ink.opacity(0.25)))
                if store.isMine(animation) {
                    Button("DELETE") { store.delete(animation); dismiss() }.buttonStyle(PillButton(fill: Face.track(0)))
                }
                Button("CANCEL") { dismiss() }.buttonStyle(PillButton())
                Button("SAVE") {
                    animation.name = animation.name.trimmingCharacters(in: .whitespaces)
                    store.save(animation); dismiss()
                }
                .buttonStyle(PillButton(fill: Face.yellow)).disabled(!named)
            }
            LEDPreview(layout: layout, frames: store.frames(animation, layout)).frame(height: 150)
            Text("PATTERN").font(Face.mono(9)).tracking(3).opacity(0.45)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(LEDPattern.all.filter { !$0.isTest }) { p in
                        Button(p.name.uppercased()) { animation.pattern = p.id }
                            .buttonStyle(PillButton(fill: animation.pattern == p.id ? Face.yellow : nil))
                    }
                }
            }
            HStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("COLOURS").font(Face.mono(9)).tracking(3).opacity(0.45)
                    HStack(spacing: 14) {
                        ForEach(0..<3, id: \.self) { i in
                            ColorPicker("", selection: color(i), supportsOpacity: false).labelsHidden().accessibilityLabel("Colour \(i + 1)")
                        }
                    }
                    .disabled(animation.style.mono).opacity(animation.style.mono ? 0.3 : 1)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("BLACK AND WHITE").font(Face.mono(9)).tracking(3).opacity(0.45)
                    Toggle("Black and white", isOn: $animation.style.mono).labelsHidden().tint(Face.yellow)
                }
                Spacer()
            }
            slider("TOP ROW + ENCODERS", $animation.style.colorOpacity)
            slider("WHITE ROWS", $animation.style.bedOpacity)
            Text("The top 17 keys and the encoders have colour; the two rows below are white only.")
                .font(Face.mono(10)).opacity(0.45)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Face.background.ignoresSafeArea())
        .foregroundStyle(Face.ink)
        .preferredColorScheme(.dark)
    }

    private func slider(_ title: String, _ value: Binding<Double>) -> some View {
        HStack(spacing: 14) {
            Text(title).font(Face.mono(10, .bold)).tracking(1.5).frame(width: 170, alignment: .leading)
            Slider(value: value, in: 0...1, step: 0.05).tint(Face.yellow)
            Text("\(Int((value.wrappedValue * 100).rounded()))%").font(Face.mono(12, .bold)).frame(width: 52, alignment: .trailing)
        }
    }

    private func color(_ i: Int) -> Binding<Color> {
        Binding {
            Color(hex: animation.style.colors[i])
        } set: { c in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
            func byte(_ v: CGFloat) -> UInt32 { UInt32((min(1, max(0, v)) * 255).rounded()) }   // wide gamut is clamped
            animation.style.colors[i] = byte(r) << 16 | byte(g) << 8 | byte(b)
        }
    }
}

/// An animation on a drawing of the OP-Z's keys, at the display's own rate (120 Hz on ProMotion), blending between
/// frames: 240 of them at 60 a second, as the OP-Z's player paces them, then a breath of dark.
struct LEDPreview: View {
    let layout: LEDLayout
    let frames: [[RGBW]]
    /// A card in the library is one of many: slower.
    var fps = 60.0
    static let frameTime = 1.0 / 60, rest = 0.8

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / fps)) { context in
            Canvas { g, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let length = Double(frames.count) * Self.frameTime
                let at = t.truncatingRemainder(dividingBy: length + Self.rest) / Self.frameTime
                let i = min(frames.count - 1, Int(at)), j = min(frames.count - 1, i + 1), k = min(1, at - Double(i))
                let ay = layout.points.values.map(\.aspectY).max() ?? 0.15
                let scale = min(size.width - 16, (size.height - 16) / max(ay, 0.01))
                let ox = (size.width - scale) / 2, oy = (size.height - ay * scale) / 2
                let dot = max(4, scale / 34)
                for (n, p) in layout.points {
                    let c = frames[i][n] * (1 - k) + frames[j][n] * k
                    let rect = CGRect(x: ox + p.x * scale - dot / 2, y: oy + p.aspectY * scale - dot / 2, width: dot, height: dot)
                    g.fill(Path(ellipseIn: rect), with: .color(Face.ink.opacity(0.08)))
                    g.fill(Path(ellipseIn: rect), with: .color(Self.shown(c)))
                }
            }
        }
        .background(Face.background, in: RoundedRectangle(cornerRadius: 10))
    }

    /// An RGBW LED as a screen shows it: its colour at full, as see-through as the LED is dim; white adds to all three.
    static func shown(_ c: RGBW) -> Color {
        func v(_ i: Int) -> Double { min(1, c[i] + c[3]) }
        let top = max(v(0), v(1), v(2))
        return top < 0.001 ? .clear : Color(.sRGB, red: v(0) / top, green: v(1) / top, blue: v(2) / top, opacity: top)
    }
}
