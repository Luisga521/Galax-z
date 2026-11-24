import Foundation

/// Where Galax-z keeps things on Windows, as on the Mac: its own files out of sight, backups where people look.
public enum Folders {
    /// `%LOCALAPPDATA%\Galax-z` (the Mac's Application Support/Galax-z): settings, TE's OS read off your OP-Z, the log.
    public static var support: URL {
        let base = ProcessInfo.processInfo.environment["LOCALAPPDATA"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Galax-z", isDirectory: true)
    }

    /// `Documents\Galax-z\Backups`: the projects, and what was on the OP-Z before every write.
    public static var backups: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Galax-z", isDirectory: true).appendingPathComponent("Backups", isDirectory: true)
    }

    /// `Documents\Galax-z\Diagnostics`: the link check, saved to send.
    public static var diagnostics: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Galax-z", isDirectory: true).appendingPathComponent("Diagnostics", isDirectory: true)
    }

    /// A folder of its own for one run of the update mode (`Backups\os\20261123T171500Z`).
    public static func osRun(_ date: Date = Date()) throws -> URL {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let u = backups.appendingPathComponent("os", isDirectory: true).appendingPathComponent(f.string(from: date), isDirectory: true)
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
}

/// Lines to `%LOCALAPPDATA%\Galax-z\log.txt`: a window has no console to say things on. Kept under a megabyte.
public enum Log {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handle: FileHandle?

    public static var url: URL { Folders.support.appendingPathComponent("log.txt") }

    public static func say(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        if handle == nil {
            try? FileManager.default.createDirectory(at: Folders.support, withIntermediateDirectories: true)
            if let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int, size > 1_000_000 {
                try? FileManager.default.removeItem(at: url)
            }
            if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
            handle = try? FileHandle(forWritingTo: url)
            _ = try? handle?.seekToEnd()
        }
        let f = ISO8601DateFormatter()
        try? handle?.write(contentsOf: Data("\(f.string(from: Date())) \(line)\r\n".utf8))
    }
}
