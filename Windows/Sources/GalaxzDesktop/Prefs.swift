import Foundation
import OPZFirmware

/// What the Mac keeps in UserDefaults, kept in `%LOCALAPPDATA%\Galax-z\settings.json`: one file, written whole at every
/// change. A write that must survive a crash (a firmware write has begun) is on disk before the call returns.
public final class Prefs: @unchecked Sendable {
    public struct Values: Codable, Equatable, Sendable {
        /// The screen's look (Settings › SCREEN).
        public var fineness = 240, glow = 0.8, afterglow = 0.3
        /// The window covers the monitor (F11).
        public var fullScreen = false
        /// Two tones when the OP-Z is switched on, with the next version that is installed.
        public var bootChime = true
        /// Ask GitHub for new releases when the app opens.
        public var lookForReleases = true
        /// The last thing read off (or written to) the OP-Z, also from an earlier day.
        public var lastInstalled: String?
        /// A write that did not finish: what the OP-Z has is not whole.
        public var interruptedWrite: String?
        /// The build boot animations are flashed onto.
        public var animationBase = "galaxz-v2"
        /// Your own animations.
        public var myAnimations: [LEDAnimation] = []

        public init() {}

        // a file from an older build may lack any of them
        public init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            let v = Values()
            fineness = try c.decodeIfPresent(Int.self, forKey: .fineness) ?? v.fineness
            glow = try c.decodeIfPresent(Double.self, forKey: .glow) ?? v.glow
            afterglow = try c.decodeIfPresent(Double.self, forKey: .afterglow) ?? v.afterglow
            fullScreen = try c.decodeIfPresent(Bool.self, forKey: .fullScreen) ?? v.fullScreen
            bootChime = try c.decodeIfPresent(Bool.self, forKey: .bootChime) ?? v.bootChime
            lookForReleases = try c.decodeIfPresent(Bool.self, forKey: .lookForReleases) ?? v.lookForReleases
            lastInstalled = try c.decodeIfPresent(String.self, forKey: .lastInstalled)
            interruptedWrite = try c.decodeIfPresent(String.self, forKey: .interruptedWrite)
            animationBase = try c.decodeIfPresent(String.self, forKey: .animationBase) ?? v.animationBase
            myAnimations = (try? c.decodeIfPresent([LEDAnimation].self, forKey: .myAnimations)) ?? []
        }
    }

    public let url: URL
    private let lock = NSLock()
    private var values: Values

    public init(folder: URL) {
        url = folder.appendingPathComponent("settings.json")
        values = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Values.self, from: $0) } ?? Values()
    }

    public var all: Values { lock.lock(); defer { lock.unlock() }; return values }

    public subscript<T>(_ key: WritableKeyPath<Values, T>) -> T {
        get { lock.lock(); defer { lock.unlock() }; return values[keyPath: key] }
        set {
            lock.lock()
            values[keyPath: key] = newValue
            let v = values
            lock.unlock()
            save(v)
        }
    }

    private func save(_ v: Values) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? enc.encode(v).write(to: url, options: .atomic)
    }
}
