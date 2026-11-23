#if os(macOS) || targetEnvironment(macCatalyst)
import Darwin
import Foundation

/// The OP-Z's update-mode console on a Mac: a USB CDC serial port, `/dev/cu.usbmodem*`, raw at 115,200 baud.
public final class SerialPort: ConsoleTransport {
    let fd: Int32
    public let path: String

    /// The OP-Z in update mode shows up as one /dev/cu.usbmodem* port.
    public static func candidates() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? [])
            .filter { $0.hasPrefix("cu.usbmodem") }.sorted().map { "/dev/" + $0 }
    }

    public init(path: String) throws {
        self.path = path
        fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else { throw ConsoleError.refused("cannot open \(path): \(String(cString: strerror(errno)))") }
        var t = termios()
        tcgetattr(fd, &t)
        cfmakeraw(&t)
        cfsetspeed(&t, speed_t(B115200))
        t.c_cflag |= tcflag_t(CLOCAL | CREAD)
        tcsetattr(fd, TCSANOW, &t)
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK)
    }

    deinit { close(fd) }

    public func write(_ bytes: [UInt8]) throws {
        var at = 0
        while at < bytes.count {
            let n = bytes[at...].withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }
            if n < 0 {
                if errno == EINTR || errno == EAGAIN { continue }
                throw ConsoleError.refused("write failed: \(String(cString: strerror(errno)))")
            }
            at += n
        }
        tcdrain(fd)
    }

    public func read(timeout: TimeInterval) throws -> [UInt8] {
        var p = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let r = poll(&p, 1, Int32(timeout * 1000))
        if r < 0, errno != EINTR { throw ConsoleError.refused("poll failed: \(String(cString: strerror(errno)))") }
        guard r > 0 else { return [] }
        if p.revents & Int16(POLLHUP | POLLERR) != 0 { throw ConsoleError.refused("the OP-Z went away") }
        var buf = [UInt8](repeating: 0, count: 65_536)
        let n = buf.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, $0.count) }
        return n > 0 ? Array(buf[0..<n]) : []
    }

    public func discardInput() { tcflush(fd, TCIFLUSH) }
}
#endif
