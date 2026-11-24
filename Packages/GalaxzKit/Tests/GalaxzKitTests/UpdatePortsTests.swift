import Testing
@testable import OPZFirmware

/// Which COM port Galax-z may write to on Windows: teenage engineering's only, exactly one.
@Suite struct UpdatePortsTests {
    let opz = UpdatePorts.Port(name: "COM7", usb: ["VID_2367&PID_0012"])
    let board = UpdatePorts.Port(name: "COM3", usb: ["VID_2341&PID_0043"])        // a microcontroller board
    let bluetooth = UpdatePorts.Port(name: "COM4", usb: [])                        // a Bluetooth serial link

    @Test func onlyTheOPZ() throws {
        #expect(try UpdatePorts.choose([board, bluetooth, opz]).get() == "COM7")
        #expect(UpdatePorts.candidates([board, bluetooth, opz]) == ["COM7"])
    }

    @Test func nothingElseEverAlone() {
        // the Mac's rule ("the only port there") would take this one; Windows must not
        #expect(throws: ConsoleError.self) { try UpdatePorts.choose([board]).get() }
        #expect(throws: ConsoleError.self) { try UpdatePorts.choose([bluetooth]).get() }
        #expect(throws: ConsoleError.self) { try UpdatePorts.choose([]).get() }
    }

    @Test func twoOPZsAreRefused() {
        let other = UpdatePorts.Port(name: "COM9", usb: ["VID_2367&PID_0012"])
        #expect(throws: ConsoleError.self) { try UpdatePorts.choose([opz, other]).get() }
    }

    @Test func aNameWindowsGaveTwoDevicesIsNotTrusted() {
        // the registry remembers another device under the same COM number: which one is there is not certain
        let mixed = UpdatePorts.Port(name: "COM7", usb: ["VID_2367&PID_0012", "VID_2341&PID_0043"])
        #expect(!mixed.isTE)
        #expect(throws: ConsoleError.self) { try UpdatePorts.choose([mixed]).get() }
        // two of teenage engineering's own ids (an interface of a composite device) are still theirs
        #expect(UpdatePorts.Port(name: "COM7", usb: ["VID_2367&PID_0012", "vid_2367&pid_0012&mi_00"]).isTE)
    }

    @Test func onlyPlainCOMNames() {
        for good in ["COM1", "COM9", "COM10", "COM256"] { #expect(UpdatePorts.isCOMName(good)) }
        for bad in ["", "COM", "COM0", "COM257", "COM01", "com5", "COM5:", "COM5\\..\\X", "\\\\.\\COM5", "COM-1", "COM 5", "LPT1", "NUL"] {
            #expect(!UpdatePorts.isCOMName(bad), "\(bad)")
        }
        let odd = UpdatePorts.Port(name: "COM5\\..\\X", usb: ["VID_2367&PID_0012"])
        #expect(throws: ConsoleError.self) { try UpdatePorts.choose([odd]).get() }
    }

    @Test func refusalsSayWhatIsThere() {
        guard case .failure(let e) = UpdatePorts.choose([board, bluetooth]) else { Issue.record("chosen"); return }
        #expect("\(e)".contains("COM3 (VID_2341&PID_0043)") && "\(e)".contains("COM4 (not USB)"))
    }
}
