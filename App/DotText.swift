import DotKit
import SwiftUI

/// The matrix's type in the app's panels: the same glyphs, a round dot each.
struct DotText: View {
    let text: String
    var font: DotFont = .small
    /// Points a dot.
    var dot: CGFloat = 2
    var color: Color = Face.ink
    var unlit = 0.0

    init(_ text: String, font: DotFont = .small, dot: CGFloat = 2, color: Color = Face.ink, unlit: Double = 0) {
        (self.text, self.font, self.dot, self.color, self.unlit) = (text.uppercased(), font, dot, color, unlit)
    }

    var body: some View {
        let w = font.width(text)
        Canvas { g, size in
            var lit = Path(), off = Path()
            if unlit > 0 {
                for y in 0..<font.height { for x in 0..<w { off.addEllipse(in: cell(x, y)) } }
                g.fill(off, with: .color(color.opacity(unlit)))
            }
            let c = DotCanvas(width: max(1, w), height: font.height)
            c.text(text, 0, 0, .white, font: font)
            for y in 0..<font.height { for x in 0..<w where c[x, y].r > 100 { lit.addEllipse(in: cell(x, y)) } }
            g.fill(lit, with: .color(color))
        }
        .frame(width: CGFloat(w) * dot, height: CGFloat(font.height) * dot)
        .accessibilityElement()
        .accessibilityLabel(text.capitalized)
    }

    private func cell(_ x: Int, _ y: Int) -> CGRect {
        CGRect(x: CGFloat(x) * dot + dot * 0.08, y: CGFloat(y) * dot + dot * 0.08, width: dot * 0.84, height: dot * 0.84)
    }
}

/// A button that asks to be held: for what writes to the OP-Z. Letting go, leaving it, its page going away, the app losing the
/// front or the button being switched off all call it off. VoiceOver and the keyboard get a question instead.
struct HoldButton: View {
    let title: String
    let question: String
    var color: Color = Face.yellow
    var seconds = 1.4
    let action: () -> Void
    @Environment(\.isEnabled) private var enabled
    @Environment(\.scenePhase) private var phase
    /// Goes back to false by itself whenever the press ends, however it ends.
    @GestureState private var pressed = false
    @State private var held = false
    @State private var asking = false
    @State private var wait: Task<Void, Never>?

    var body: some View {
        DotText(held ? "KEEP HOLDING" : title, font: .small, dot: 1.7, color: held ? Face.background : color)
            .frame(minWidth: 170)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background {
                GeometryReader { g in
                    RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12))
                    RoundedRectangle(cornerRadius: 10).fill(color).frame(width: held ? g.size.width : 0)
                        .animation(held ? .linear(duration: seconds) : .snappy(duration: 0.2), value: held)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(enabled ? 0.9 : 0.3), lineWidth: 1.2))
            .opacity(enabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .gesture(DragGesture(minimumDistance: 0).updating($pressed) { v, on, _ in
                on = abs(v.translation.width) < 60 && abs(v.translation.height) < 40
            })
            .onChange(of: pressed) { _, on in on ? press() : callOff() }
            .onChange(of: enabled) { _, on in if !on { callOff() } }
            .onChange(of: phase) { _, p in if p != .active { callOff() } }
            .onDisappear { callOff() }
            .accessibilityElement()
            .accessibilityLabel(title.capitalized)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if enabled { asking = true } }
            .confirmationDialog(question, isPresented: $asking, titleVisibility: .visible) {
                Button(title.capitalized) { if enabled { action() } }
                Button("Cancel", role: .cancel) {}
            }
    }

    private func press() {
        guard enabled, wait == nil else { return }
        held = true
        wait = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, held, pressed, enabled else { return }
            callOff()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            action()
        }
    }

    private func callOff() {
        wait?.cancel()
        wait = nil
        held = false
    }
}
