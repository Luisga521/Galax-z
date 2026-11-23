import Foundation

/// Who may sign a release: the public keys, pinned in the app (`swift run galaxz-release keygen` makes a pair and prints its).
public enum ReleaseKeys {
    public static let trusted: [Data] = hex.compactMap { h in
        (try? Patcher.bytes(h)).map { Data($0) }
    }

    static let hex = [
        "42dcff5b933081683f0ce515da17bbf5fe4eb070d2c1fe6f8233bcd589cc5764",
    ]

    public static func name(_ raw: Data) -> String { raw.prefix(4).map { String(format: "%02x", $0) }.joined() }
}
