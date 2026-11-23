import OPZModel
import SwiftUI
import UIKit

/// Finds the OP-Z's double-triggering keys: every press timed from its MIDI note. The data the debounce fix needs.
struct KeyTestScreen: View {
    let live: Live
    @State private var copied = false

    var body: some View {
        let test = live.keyTest
        VStack(alignment: .leading, spacing: 20) {
            bar
            Text(hint)
                .font(Face.mono(12)).opacity(0.6)
                .fixedSize(horizontal: false, vertical: true)
            if live.opzPlaying {
                Label("THE OP-Z IS PLAYING: ITS OWN NOTES COUNT AS PRESSES. PRESS STOP.", systemImage: "exclamationmark.triangle")
                    .font(Face.mono(11, .bold)).tracking(1.5).foregroundStyle(Face.yellow)
            }
            stats(test)
            Keyboard(test: test)
                .frame(height: 300)
            PressLog(test: test)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Face.background.ignoresSafeArea())
        .foregroundStyle(Face.ink)
        .preferredColorScheme(.dark)
    }

    private var bar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                DotText("KEY TEST", font: .big, dot: 2)
                Text("DOUBLE TRIGGERS").font(Face.mono(9)).tracking(3).opacity(0.45).padding(.top, 4)
            }
            HStack(spacing: 8) {
                DotMatrix(mode: listening ? .wave : .off, color: listening ? Face.yellow : Face.ink)
                Text(status).font(Face.mono(11, .bold)).tracking(2)
            }
            .padding(.leading, 8).padding(.trailing, 12).padding(.vertical, 5)
            .overlay(Capsule().stroke(Face.ink.opacity(0.18), lineWidth: 1))
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Text("WINDOW").font(Face.mono(9)).tracking(2).opacity(0.5)
                Button("−") { setWindow(live.keyTest.window - 0.005) }.buttonStyle(PillButton())
                Text("\(ms(live.keyTest.window)) MS").font(Face.mono(13, .bold)).frame(minWidth: 62)
                    .contentTransition(.numericText()).animation(.snappy, value: live.keyTest.window)
                Button("+") { setWindow(live.keyTest.window + 0.005) }.buttonStyle(PillButton())
            }
            Button("RESET") { withAnimation(.snappy) { live.keyTest.reset() } }.buttonStyle(PillButton())
            Button(copied ? "COPIED" : "COPY REPORT") {
                UIPasteboard.general.string = live.keyTest.report
                copied = true
                Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
            }
            .buttonStyle(PillButton())
            .disabled(live.keyTest.presses == 0)
            Button("DONE") { live.closeKeyTest() }.buttonStyle(PillButton(fill: Face.yellow))
        }
    }

    private func stats(_ test: KeyTest) -> some View {
        HStack(alignment: .top, spacing: 34) {
            Stat(label: "PRESSES", value: "\(test.presses)")
            Stat(label: "DOUBLES", value: "\(test.doubles)", color: test.doubles > 0 ? Face.track(0) : Face.ink)
            Stat(label: "KEYS THAT BOUNCE", value: "\(test.keysWithDoubles.count)",
                 color: test.keysWithDoubles.isEmpty ? Face.ink : Face.track(0))
            Stat(label: "FASTEST REPEAT", value: test.fastest.map { "\(ms($0)) MS" } ?? "—")
            if let channel = test.channel {
                Stat(label: "LISTENING ON", value: "CH \(channel + 1)")
            }
            if test.ignored > 0 {
                Stat(label: "OTHER CHANNELS", value: "\(test.ignored)", color: Face.ink.opacity(0.5))
            }
        }
    }

    private var listening: Bool { live.source == .demo || live.deviceName != nil }

    private var status: String {
        if live.source == .demo { return "DEMO PRESSES" }
        guard let name = live.deviceName else { return "NO OP-Z" }
        return "LISTENING · \(live.transport == .bluetooth ? "BLUETOOTH" : "USB") · \(name.uppercased())"
    }

    private var hint: String {
        if live.source == .demo {
            return "Demo: pretend presses across the keyboard; three keys bounce now and then, so you can see what a double looks like."
        }
        if live.deviceName == nil { return "Connect your OP-Z first, by cable or Bluetooth." }
        if live.keyTest.presses == 0 {
            return "Press STOP on the OP-Z, then press every key a few times at a steady pace. A key that fires twice inside "
                + "the window is a double trigger. Nothing arriving? Turn MIDI out on: hold TEMPO + SCREEN and press 3."
        }
        return "Keep going: press each key 10–20 times. Keys turn red when they bounce. COPY REPORT keeps the numbers for "
            + "tuning the debounce fix."
    }

    private func setWindow(_ seconds: Double) {
        live.keyTest.window = min(0.08, max(0.01, (seconds * 200).rounded() / 200))
    }

    private func ms(_ s: Double) -> Int { Int((s * 1000).rounded()) }
}

private struct Stat: View {
    let label: String
    let value: String
    var color: Color = Face.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Face.mono(9)).tracking(2).opacity(0.45)
            Text(value).font(Face.mono(28, .medium)).foregroundStyle(color)
                .contentTransition(.numericText()).animation(.snappy, value: value)
        }
    }
}

/// Two octaves from F like the OP-Z's keys: 14 white keys, the 10 black value keys over them.
private struct Keyboard: View {
    let test: KeyTest
    static let whiteOffsets = [0, 2, 4, 6, 7, 9, 11]
    static let blackOffsets = [1, 3, 5, 8, 10]
    static let blackAfterWhite = [0, 1, 2, 4, 5]

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 6
            let w = (geo.size.width - gap * 13) / 14
            ZStack(alignment: .topLeading) {
                ForEach(0..<14, id: \.self) { i in
                    let note = test.firstNote + 12 * (i / 7) + Self.whiteOffsets[i % 7]
                    KeyCell(note: note, key: test.byNote[note], window: test.window, black: false)
                        .frame(width: w, height: geo.size.height)
                        .offset(x: CGFloat(i) * (w + gap))
                }
                ForEach(0..<10, id: \.self) { k in
                    let note = test.firstNote + 12 * (k / 5) + Self.blackOffsets[k % 5]
                    let after = Self.blackAfterWhite[k % 5] + 7 * (k / 5)
                    let bw = w * 0.66
                    KeyCell(note: note, key: test.byNote[note], window: test.window, black: true, value: (k + 1) % 10)
                        .frame(width: bw, height: geo.size.height * 0.55)
                        .offset(x: CGFloat(after + 1) * (w + gap) - gap / 2 - bw / 2)
                }
            }
        }
    }
}

private struct KeyCell: View {
    let note: Int
    let key: KeyTest.Key?
    let window: Double
    let black: Bool
    var value: Int? = nil

    var body: some View {
        let presses = key?.presses ?? 0
        let doubles = key?.doubles(window: window) ?? 0
        let bounce = Face.track(0)
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(black ? Color(hex: 0x050506) : Face.panel)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(bounce.opacity(doubles > 0 ? 0.28 : 0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(doubles > 0 ? bounce : Face.ink.opacity(black ? 0.22 : 0.12), lineWidth: doubles > 0 ? 1.5 : 1)
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 4) {
                    if doubles > 0 {
                        Text("×\(doubles)")
                            .font(Face.mono(11, .bold)).foregroundStyle(Face.background)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(bounce, in: Capsule())
                    }
                    Text(presses > 0 ? "\(presses)" : "·").font(Face.mono(12, .medium)).opacity(presses > 0 ? 0.9 : 0.3)
                    Text(value.map(String.init) ?? KeyTest.name(note)).font(Face.mono(9)).opacity(0.5)
                }
                .padding(.bottom, 10)
            }
            .keyframeAnimator(initialValue: 0.0, trigger: presses) { view, glow in
                view.overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Face.yellow.opacity(glow))
                }
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(0.55, duration: 0.02)
                    CubicKeyframe(0, duration: 0.35)
                }
            }
            .animation(.snappy, value: doubles)
    }
}

/// The latest presses, newest first: the gap since the same key's previous press, and how long that one was held.
private struct PressLog: View {
    let test: KeyTest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LATEST PRESSES").font(Face.mono(9)).tracking(2).opacity(0.45)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 28, alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(test.log.prefix(24)) { press in
                    let double = test.isDouble(press)
                    HStack(spacing: 12) {
                        Text(KeyTest.name(press.note)).frame(width: 40, alignment: .leading).font(Face.mono(12, .bold))
                        Text(press.gap.map { "+\(Int(($0 * 1000).rounded())) MS" } ?? "—").frame(width: 84, alignment: .leading)
                        Text(press.heldBefore.map { "HELD \(Int(($0 * 1000).rounded())) MS" } ?? "").frame(width: 100, alignment: .leading)
                            .opacity(0.5)
                        if double {
                            Text("DOUBLE").font(Face.mono(10, .bold)).foregroundStyle(Face.background)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Face.track(0), in: Capsule())
                        }
                        Spacer(minLength: 0)
                    }
                    .lineLimit(1)
                    .font(Face.mono(11))
                    .foregroundStyle(double ? Face.track(0) : Face.ink)
                }
            }
        }
    }
}
