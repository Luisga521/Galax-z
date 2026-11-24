import OPZModel
import SwiftUI

/// Every controller plugged into this Mac, played into the OP-Z beside its own keys: where each one goes.
struct BridgeScreen: View {
    let live: Live
    private var controllers: Controllers { live.controllers }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(opz).font(Face.mono(12, .bold)).foregroundStyle(live.deviceName == nil || midiOff ? Face.yellow : Face.ink)
                    Text("Plug your keyboards and pads into this Mac and the OP-Z too: what you play on them goes straight to the OP-Z, while its own keys still work. What you learned goes where you learned it; the rest comes here.")
                        .font(Face.mono(11)).opacity(0.6).fixedSize(horizontal: false, vertical: true)
                    if let l = controllers.last { Text(l).font(Face.mono(10)).opacity(0.45) }
                }
                if controllers.devices.isEmpty {
                    Text("No controller is connected. Plug one into this Mac.").font(Face.mono(12)).opacity(0.55).padding(.top, 8)
                }
                ForEach(controllers.devices, id: \.self) { d in row(d) }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            .frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var midiOff: Bool { live.midiIn == false }

    private var opz: String {
        guard let name = live.deviceName else { return "NO OP-Z: PLUG IT IN WITH A USB-C CABLE (OR PAIR IT)" }
        if midiOff { return "\(name.uppercased()): ITS MIDI IN IS OFF. HOLD TEMPO + SCREEN, THEN KEY 2" }
        return "\(name.uppercased()) IS LISTENING"
    }

    private func row(_ device: String) -> some View {
        HStack(spacing: 12) {
            Text(device).font(Face.mono(12, .bold)).lineLimit(1)
            Spacer()
            Picker("To", selection: Binding(get: { controllers.route(device) }, set: { controllers.set($0, for: device) })) {
                Text("OFF").tag(Bridge.Route.off)
                Text("THE SELECTED TRACK").tag(Bridge.Route.selected)
                Text("AS SENT: CHANNEL = TRACK").tag(Bridge.Route.asSent)
                Divider()
                ForEach(0..<16, id: \.self) { t in Text("\(t + 1) \(OPZ.trackNames[t].uppercased())").tag(Bridge.Route.track(t)) }
            }
            .pickerStyle(.menu).tint(Face.yellow).frame(maxWidth: 300)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Face.ink.opacity(controllers.route(device) == .off ? 0.05 : 0.12)))
    }
}
