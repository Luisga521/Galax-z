import SwiftUI

/// The design tokens: near-black, off-white ink, one yellow, a colour per track group, monospaced type.
enum Face {
    static let background = Color(hex: 0x0C0C0D)
    static let panel = Color(hex: 0x161618)
    static let ink = Color(hex: 0xEDEBE6)
    static let yellow = Color(hex: 0xFFD23F)
    static let green = Color(hex: 0x2FD18B)

    static func track(_ t: Int) -> Color {
        switch t {
        case 0...3: Color(hex: 0xFF5A36)   // drums
        case 4...7: Color(hex: 0x3D7BFF)   // synths
        case 8...9: Color(hex: 0x2FD18B)   // fx
        case 10...11: Color(hex: 0xFFD23F) // tape, master
        default: Color(hex: 0xB8B4AC)      // perform, module, lights, motion
        }
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func noteName(_ n: Int) -> String {
        ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][n % 12] + String(n / 12 - 1)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

/// A 5 × 5 dot loader: a wave while waiting, a steady ring when live, a blinking cross when lost.
struct DotMatrix: View {
    enum Mode { case wave, steady, blink, off }
    var mode: Mode
    var color: Color = Face.ink
    var dot: CGFloat = 3

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: mode == .steady || mode == .off)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { g, size in
                let pitch = size.width / 5
                for y in 0..<5 {
                    for x in 0..<5 {
                        let r = CGRect(x: CGFloat(x) * pitch + (pitch - dot) / 2, y: CGFloat(y) * pitch + (pitch - dot) / 2,
                                       width: dot, height: dot)
                        g.fill(Path(ellipseIn: r), with: .color(color.opacity(alpha(x, y, t))))
                    }
                }
            }
        }
        .frame(width: dot * 9.5, height: dot * 9.5)
    }

    private func alpha(_ x: Int, _ y: Int, _ t: Double) -> Double {
        let cross = x == y || x == 4 - y
        switch mode {
        case .wave: return 0.12 + 0.88 * max(0, sin(t * 5 - Double(x + y) * 0.7))
        case .steady: return abs(x - 2) + abs(y - 2) == 2 ? 1 : x == 2 && y == 2 ? 0.9 : 0.12
        case .blink: return cross && Int(t * 2) % 2 == 0 ? 1 : 0.12
        case .off: return cross ? 0.55 : 0.1
        }
    }
}

struct PillButton: ButtonStyle {
    var fill: Color? = nil
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Face.mono(11, .bold))
            .tracking(2)
            .lineLimit(1).fixedSize()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(fill == nil ? Face.ink : Face.background)
            .background(fill ?? .clear, in: Capsule())
            .overlay(Capsule().stroke(Face.ink.opacity(fill == nil ? 0.3 : 0), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.5), value: configuration.isPressed)
    }
}
