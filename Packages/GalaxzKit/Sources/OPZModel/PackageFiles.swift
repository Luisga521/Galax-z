import Foundation

/// Where the package's own files (op-free's engine list, the demo song) are read from.
public enum PackageFiles {
    /// A folder holding them, for a platform where SwiftPM's resource bundles do not travel with the app (Android: the
    /// app copies them out of its APK and says where). Nil: the bundle SwiftPM made.
    nonisolated(unsafe) public static var folder: URL?

    public static func url(_ name: String, _ ext: String, bundle: () -> Bundle) -> URL? {
        if let folder { return folder.appendingPathComponent("\(name).\(ext)") }
        #if os(Android)
        return nil      // SwiftPM's accessor stops the app when its bundle is not beside it
        #else
        return bundle().url(forResource: name, withExtension: ext)
        #endif
    }
}
