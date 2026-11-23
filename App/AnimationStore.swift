import Foundation
import Observation
import OPZFirmware

/// Your own animations: edited copies of the library's, kept on this device.
@MainActor @Observable
final class AnimationStore {
    private(set) var mine: [LEDAnimation] = {
        guard let d = UserDefaults.standard.data(forKey: "myAnimations") else { return [] }
        return (try? JSONDecoder().decode([LEDAnimation].self, from: d)) ?? []
    }() {
        didSet { if let d = try? JSONEncoder().encode(mine) { UserDefaults.standard.set(d, forKey: "myAnimations") } }
    }
    @ObservationIgnored private var rendered: [LEDAnimation: [[RGBW]]] = [:]
    @ObservationIgnored private var packed: [LEDAnimation: [UInt8]] = [:]

    func isMine(_ a: LEDAnimation) -> Bool { mine.contains { $0.id == a.id } }

    /// A new animation to edit, starting from `a` (not kept until saved).
    func copy(of a: LEDAnimation) -> LEDAnimation {
        LEDAnimation(id: "my-" + UUID().uuidString.prefix(8).lowercased(), name: "My \(a.name)", pattern: a.pattern, style: a.style)
    }

    func save(_ a: LEDAnimation) {
        if let i = mine.firstIndex(where: { $0.id == a.id }) { mine[i] = a } else { mine.append(a) }
    }

    func delete(_ a: LEDAnimation) { mine.removeAll { $0.id == a.id } }

    /// An animation's frames, rendered once per look.
    func frames(_ a: LEDAnimation, _ layout: LEDLayout) -> [[RGBW]] {
        if let f = rendered[a] { return f }
        if rendered.count > 60 { rendered.removeAll() }      // an edit makes a new look at every slider step
        let f = a.frames(layout)
        rendered[a] = f
        return f
    }

    /// Its frames as the OP-Z holds them.
    func bytes(_ a: LEDAnimation, _ layout: LEDLayout) -> [UInt8] {
        if let b = packed[a] { return b }
        if packed.count > 60 { packed.removeAll() }
        let b = a.bytes(layout)
        packed[a] = b
        return b
    }
}
