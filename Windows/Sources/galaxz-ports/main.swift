// galaxz-ports: the OP-Z's update mode on Windows, from a terminal. Writes nothing to an OP-Z, ever.
//
//   galaxz-ports          the serial ports Windows has now, and which one Galax-z would talk to. Opens none.
//   galaxz-ports read     what is installed on the OP-Z in update mode, as the Mac's hub reads it (READ): it pings, reads
//                         os.crc32 and os.ldr, keeps a copy in Documents\Galax-z\Backups\os\<time>\, and names the version.
//                         The console takes only its fixed ping and read frames (UpdateConsole); there is no way to write.
#if os(Windows)
import Foundation
import GalaxzDesktop
import OPZFirmware

func fail(_ s: String) -> Never { print("galaxz-ports: \(s)"); exit(1) }

let ports = WindowsPorts.present()
print("Serial ports now:")
if ports.isEmpty { print("  none") }
for p in ports { print("  \(p.described)") }
let choice = UpdatePorts.choose(ports)
switch choice {
case .success(let port): print("Galax-z would use \(port).")
case .failure(let e): print("Galax-z would use none: \(e)")
}

if CommandLine.arguments.dropFirst().first == "read" {
    guard case .success(let port) = choice else { fail("nothing to read") }
    do {
        let catalog = try Catalog.bundled()
        let support = Folders.support, originalURL = support.appendingPathComponent("os-1.2.45.ldr")
        var original = (try? Data(contentsOf: originalURL)).map { [UInt8]($0) }.flatMap { Original.matches($0) ? $0 : nil }
        var images = try original.map { try catalog.images(original: $0) } ?? []
        let folder = try Folders.osRun()
        print("== read \(port) (read-only)")
        let con = UpdateConsole(try SerialPort(path: port), images: images) { print($0) }
        try con.start()
        let (ldr, crc) = try con.readInstalled()
        for (name, data) in [("os.crc32", crc), ("os.ldr", ldr)] {
            if let data { try Data(data).write(to: folder.appendingPathComponent("installed-\(name)"), options: .atomic) }
        }
        print("kept in \(folder.path)")
        if original == nil, let ldr, let recovered = catalog.recoverOriginal(from: ldr), Original.matches(recovered) {
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            try Data(recovered).write(to: originalURL, options: .atomic)
            original = recovered
            images = try catalog.images(original: recovered)
            print("TE's 1.2.45 kept in \(originalURL.path): copy it somewhere safe, it is the way back")
        }
        print("installed: \(images.isEmpty ? (ldr == nil ? "no os.ldr" : "unknown os.ldr") : catalog.name(images, ldr: ldr, crc: crc))")
    } catch {
        fail("\(error)")
    }
}
#else
print("galaxz-ports is for Windows (the Mac's hub does this in the app)")
#endif
