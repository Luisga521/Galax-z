#if os(Windows)
import Foundation
import WinSDK

/// The OP-Z's update-mode console on Windows: a USB CDC serial port (Windows' own usbser driver), `COMn`, raw at 115,200
/// baud. The same calls as the Mac's `SerialPort`, so `UpdateConsole` and its refusals are the same code on both.
public final class SerialPort: ConsoleTransport {
    let handle: HANDLE
    public let path: String

    /// The OP-Z in update mode: a COM port of a teenage engineering USB device, and nothing else (`UpdatePorts`).
    public static func candidates() -> [String] { UpdatePorts.candidates(WindowsPorts.present()) }

    public init(path: String) throws {
        guard UpdatePorts.isCOMName(path) else { throw ConsoleError.refused("\(path) is not a COM port") }
        // exclusive (share mode 0): while Galax-z writes, nothing else can open the port, and it cannot open one in use
        let h = #"\\.\\#(path)"#.withCString(encodedAs: UTF16.self) {
            CreateFileW($0, DWORD(GENERIC_READ) | DWORD(GENERIC_WRITE), 0, nil, DWORD(OPEN_EXISTING), 0, nil)
        }
        guard let h, h != INVALID_HANDLE_VALUE else {
            let e = GetLastError()
            throw ConsoleError.refused(e == 5 ? "\(path) is open in another program (TE's updater, another Galax-z, a terminal): close it"
                                              : "cannot open \(path) (Windows error \(e))")
        }
        handle = h
        self.path = path
        var dcb = DCB()
        dcb.DCBlength = DWORD(MemoryLayout<DCB>.size)
        guard GetCommState(h, &dcb) else { CloseHandle(h); throw ConsoleError.refused("\(path): no serial settings (Windows error \(GetLastError()))") }
        dcb.BaudRate = 115_200
        dcb.ByteSize = 8
        dcb.Parity = 0             // none
        dcb.StopBits = 0           // one
        dcb.fBinary = 1
        dcb.fParity = 0
        dcb.fOutxCtsFlow = 0
        dcb.fOutxDsrFlow = 0
        dcb.fDtrControl = 1        // DTR on: a USB CDC device sends nothing to a port that has not raised it
        dcb.fDsrSensitivity = 0
        dcb.fOutX = 0
        dcb.fInX = 0
        dcb.fErrorChar = 0
        dcb.fNull = 0
        dcb.fRtsControl = 1        // RTS on
        dcb.fAbortOnError = 0
        guard SetCommState(h, &dcb) else { CloseHandle(h); throw ConsoleError.refused("\(path): serial settings refused (Windows error \(GetLastError()))") }
        guard setTimeouts(read: 0.2) else { CloseHandle(h); throw ConsoleError.refused("\(path): timeouts refused (Windows error \(GetLastError()))") }
        _ = PurgeComm(h, 0x0008 | 0x0004)          // PURGE_RXCLEAR | PURGE_TXCLEAR
    }

    deinit { CloseHandle(handle) }

    /// A read returns what has arrived, or waits up to `read` seconds for the first byte. A write that the OP-Z does not
    /// take within 5 s fails (and the upload counts as stalled), instead of hanging.
    private func setTimeouts(read: TimeInterval) -> Bool {
        var t = COMMTIMEOUTS()
        t.ReadIntervalTimeout = DWORD.max
        t.ReadTotalTimeoutMultiplier = DWORD.max
        t.ReadTotalTimeoutConstant = DWORD(max(1, min(60_000, Int(read * 1000))))
        t.WriteTotalTimeoutMultiplier = 0
        t.WriteTotalTimeoutConstant = 5000
        return SetCommTimeouts(handle, &t)
    }

    public func write(_ bytes: [UInt8]) throws {
        var at = 0
        while at < bytes.count {
            var n: DWORD = 0
            let ok = bytes[at...].withUnsafeBytes { WriteFile(handle, $0.baseAddress, DWORD($0.count), &n, nil) }
            guard ok else { throw ConsoleError.refused("write failed (Windows error \(GetLastError())): the OP-Z went away") }
            guard n > 0 else { throw ConsoleError.refused("the OP-Z took nothing for 5 s") }
            at += Int(n)
        }
    }

    public func read(timeout: TimeInterval) throws -> [UInt8] {
        guard setTimeouts(read: timeout) else { throw ConsoleError.refused("the OP-Z went away (Windows error \(GetLastError()))") }
        var buf = [UInt8](repeating: 0, count: 65_536)
        var n: DWORD = 0
        let ok = buf.withUnsafeMutableBytes { ReadFile(handle, $0.baseAddress, DWORD($0.count), &n, nil) }
        guard ok else { throw ConsoleError.refused("the OP-Z went away (Windows error \(GetLastError()))") }
        return Array(buf[0..<Int(n)])
    }

    public func discardInput() { _ = PurgeComm(handle, 0x0008) }      // PURGE_RXCLEAR
}

/// The serial ports Windows has now, and whose USB device each is, from the registry (readable without administrator).
public enum WindowsPorts {
    static let readAccess: DWORD = 0x20019          // KEY_READ

    public static func present() -> [UpdatePorts.Port] {
        // the ports there now: HARDWARE\DEVICEMAP\SERIALCOMM, "\Device\USBSER000" = "COM5"
        let now = Set(values(#"HARDWARE\DEVICEMAP\SERIALCOMM"#).map { $0.uppercased() })
        // whose they are: every USB device instance that was given a port name
        var owners: [String: [String]] = [:]
        let root = #"SYSTEM\CurrentControlSet\Enum\USB"#
        for device in subkeys(root) {
            for instance in subkeys(root + "\\" + device) {
                if let port = string(root + "\\" + device + "\\" + instance + "\\Device Parameters", "PortName")?.uppercased(), now.contains(port) {
                    owners[port, default: []].append(device)
                }
            }
        }
        return now.sorted { (Int($0.dropFirst(3)) ?? 0) < (Int($1.dropFirst(3)) ?? 0) }
            .map { UpdatePorts.Port(name: $0, usb: Array(Set(owners[$0] ?? [])).sorted()) }
    }

    static func open(_ path: String) -> HKEY? {
        var key: HKEY? = nil
        let r = path.withCString(encodedAs: UTF16.self) { RegOpenKeyExW(HKEY_LOCAL_MACHINE, $0, 0, readAccess, &key) }
        return r == 0 ? key : nil
    }

    static func subkeys(_ path: String) -> [String] {
        guard let key = open(path) else { return [] }
        defer { RegCloseKey(key) }
        var out: [String] = []
        var i: DWORD = 0
        while i < 10_000 {
            var name = [WCHAR](repeating: 0, count: 512)
            var len = DWORD(name.count)
            let r = RegEnumKeyExW(key, i, &name, &len, nil, nil, nil, nil)
            if r == 259 { break }                       // ERROR_NO_MORE_ITEMS
            if r == 0 { out.append(String(decoding: name[0..<Int(len)], as: UTF16.self)) }
            i += 1
        }
        return out
    }

    /// The text values of a key (their data, not their names).
    static func values(_ path: String) -> [String] {
        guard let key = open(path) else { return [] }
        defer { RegCloseKey(key) }
        var out: [String] = []
        var i: DWORD = 0
        while i < 10_000 {
            var name = [WCHAR](repeating: 0, count: 512), data = [UInt8](repeating: 0, count: 1024)
            var nameLen = DWORD(name.count), dataLen = DWORD(data.count), type: DWORD = 0
            let r = RegEnumValueW(key, i, &name, &nameLen, nil, &type, &data, &dataLen)
            if r == 259 { break }
            if r == 0, type == 1 { out.append(text(data, Int(dataLen))) }      // REG_SZ
            i += 1
        }
        return out
    }

    static func string(_ path: String, _ value: String) -> String? {
        guard let key = open(path) else { return nil }
        defer { RegCloseKey(key) }
        var data = [UInt8](repeating: 0, count: 1024)
        var len = DWORD(data.count), type: DWORD = 0
        let r = value.withCString(encodedAs: UTF16.self) { RegQueryValueExW(key, $0, nil, &type, &data, &len) }
        return r == 0 && type == 1 ? text(data, Int(len)) : nil
    }

    /// UTF-16 bytes, up to their end or the first zero.
    static func text(_ bytes: [UInt8], _ count: Int) -> String {
        let n = min(count, bytes.count) / 2
        let units = (0..<n).map { UInt16(bytes[$0 * 2]) | UInt16(bytes[$0 * 2 + 1]) << 8 }
        return String(decoding: units.prefix { $0 != 0 }, as: UTF16.self)
    }
}
#endif
