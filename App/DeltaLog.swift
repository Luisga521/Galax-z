import Foundation

/// Raw material for decoding the OP-Z's `$02` live edits: every `$02` payload as it arrives, then the bytes of the
/// bank that changed when the fresh bank came in. Side by side, they show what a `$02` says.
///
/// `Documents/Diagnostics/deltas-<day>.txt` (Files › Galax-z › Diagnostics; on the iPad over USB for decoding).
/// Stops at 4 MB a day.
@MainActor
final class DeltaLog {
    private var handle: FileHandle?
    private var written = 0
    private let start = Date()
    static let limit = 4_000_000

    func record(_ payload: [UInt8]) {
        write("$02 \(payload.count)B " + payload.map { String(format: "%02x", $0) }.joined(separator: " "))
    }

    func bank(_ new: [UInt8], before old: [UInt8]?) {
        guard on else { return }
        guard let old, old.count == new.count else { return write("bank (first)") }
        var runs: [String] = [], i = 0
        while i < new.count {
            guard new[i] != old[i] else { i += 1; continue }
            var j = i
            while j < new.count, new[j] != old[j], j - i < 32 { j += 1 }
            let at = i % 21_392
            runs.append(String(format: "@%06x p%d+%05x ", i, i / 21_392 + 1, at)
                        + old[i..<j].map { String(format: "%02x", $0) }.joined() + ">"
                        + new[i..<j].map { String(format: "%02x", $0) }.joined())
            i = j
        }
        write("bank changed: " + (runs.isEmpty ? "nothing" : runs.prefix(40).joined(separator: "  ")))
    }

    /// Only when asked for (`-log-edits`): they are all decoded now.
    private let on = ProcessInfo.processInfo.arguments.contains("-log-edits")

    private func write(_ line: String) {
        guard on, written < Self.limit else { return }
        if handle == nil {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(path: "Diagnostics")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            let url = dir.appending(path: "deltas-\(f.string(from: Date())).txt")
            if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
            handle = try? FileHandle(forWritingTo: url)
            _ = try? handle?.seekToEnd()
        }
        let text = String(format: "%8.3f ", Date().timeIntervalSince(start)) + line + "\n"
        handle?.write(Data(text.utf8))
        written += text.utf8.count
    }
}
