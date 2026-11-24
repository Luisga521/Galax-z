/// Which serial port is the OP-Z's update mode, on a system where serial ports have no telling names (Windows: COM1, COM2…).
///
/// A Mac names the port after the device's USB location (`/dev/cu.usbmodem…`) and only USB modems get that name. Windows
/// gives a COM number to anything serial: a modem, a Bluetooth link, a microcontroller board. Taking "the only one there"
/// could send an upload to something that is not an OP-Z. So Galax-z talks only to a COM port whose USB device is
/// teenage engineering's (vendor 0x2367), and only when exactly one such port is there.
public enum UpdatePorts {
    /// A serial port there now, and the USB device ids Windows lists for that port name ("VID_2367&PID_000C&MI_00").
    /// More than one id: Windows remembers another device under the same name; empty: not a USB device.
    public struct Port: Equatable, Sendable {
        public let name: String
        public let usb: [String]
        public init(name: String, usb: [String]) { (self.name, self.usb) = (name, usb) }

        /// Every id Windows has for this name is teenage engineering's: no doubt which device it is.
        public var isTE: Bool { !usb.isEmpty && usb.allSatisfy { $0.uppercased().hasPrefix("VID_\(UpdatePorts.vendor)&") } }

        public var described: String {
            usb.isEmpty ? "\(name) (not USB)" : "\(name) (\(usb.map { $0.uppercased() }.joined(separator: ", ")))\(isTE ? ", teenage engineering" : "")"
        }
    }

    /// teenage engineering's USB vendor id, as Windows writes it.
    public static let vendor = "2367"

    /// The ports Galax-z may talk to.
    public static func candidates(_ ports: [Port]) -> [String] { ports.filter(\.isTE).map(\.name) }

    /// "COM1" to "COM256", nothing else (it becomes part of a device path).
    public static func isCOMName(_ s: String) -> Bool {
        guard s.hasPrefix("COM"), let n = Int(s.dropFirst(3)), String(n) == s.dropFirst(3) else { return false }
        return (1...256).contains(n)
    }

    /// The one port to use, or why there is none.
    public static func choose(_ ports: [Port]) -> Result<String, ConsoleError> {
        let te = candidates(ports).filter(isCOMName)
        if te.count == 1 { return .success(te[0]) }
        if te.count > 1 {
            return .failure(.refused("more than one teenage engineering serial port (\(te.joined(separator: ", "))): unplug all but the OP-Z"))
        }
        let seen = ports.isEmpty ? "no serial ports at all" : "only " + ports.map(\.described).joined(separator: "; ")
        return .failure(.refused("no OP-Z in update mode: hold SCREEN while switching it on, then plug it in (Windows shows \(seen))"))
    }
}
