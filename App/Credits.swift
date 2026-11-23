import SwiftUI

/// Whose work this stands on, and the licences: the repository's own THIRD_PARTY.md and LICENSE, which have to go wherever the app goes.
struct CreditsCard: View {
    @State private var open = false

    var body: some View {
        card {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(Live.byline.isEmpty ? "CREDITS AND LICENCES" : "GALAX-Z · \(Live.byline.uppercased())").font(Face.mono(13, .bold)).tracking(2)
                    Text("Built on OP-FREE by Lourens Smit and the op-z-engines contributors (MIT). The piano is made from the Salamander Grand by Alexander Holm (CC BY 3.0).")
                        .font(Face.mono(11)).opacity(0.55).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button(open ? "CLOSE" : "READ") { open.toggle() }.buttonStyle(PillButton())
            }
            if open {
                Text(Self.text).font(Face.mono(10)).opacity(0.7).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    static let text = [("THIRD_PARTY", "md"), ("LICENSE", "")].compactMap { name, ext in
        Bundle.main.url(forResource: name, withExtension: ext).flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }.joined(separator: "\n\n")
}
