import CoreAudioKit
import SwiftUI

/// Apple's Bluetooth MIDI pairing list, for when the OP-Z is not found by itself (the route TO-2 uses).
struct BluetoothPairing: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PAIR AN OP-Z").font(Face.mono(13, .bold)).tracking(3)
                Spacer()
                Button("DONE") { dismiss() }.buttonStyle(PillButton(fill: Face.yellow))
            }
            .padding(16)
            Text("Switch the OP-Z on and tap it in the list: this closes by itself. Or plug in a cable.")
                .font(Face.mono(11)).opacity(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.bottom, 10)
            CentralList()
        }
        .background(Face.background)
        .foregroundStyle(Face.ink)
    }

    private struct CentralList: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> UINavigationController {
            UINavigationController(rootViewController: CABTMIDICentralViewController())
        }

        func updateUIViewController(_ controller: UINavigationController, context: Context) {}
    }
}
