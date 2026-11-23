#if canImport(CoreBluetooth)
import CoreBluetooth
import CoreMIDI

/// Finds an OP-Z over Bluetooth and links it with no pairing screen, Apple's "MIDI Bluetooth" route (iOS 16+): scan
/// for the BLE MIDI service, connect, check the MIDI I/O characteristic, then `MIDIBluetoothDriverActivateAllConnections`
/// hands the link to CoreMIDI, where the OP-Z appears as a MIDI device like a cable one.
@MainActor
public final class BluetoothLink: NSObject {
    public enum State: Equatable, Sendable {
        case idle, off, unauthorized, unsupported, searching
        case connecting(String)
        case linked(String)
    }

    public private(set) var state: State = .idle {
        didSet { if state != oldValue { onChange?() } }
    }
    public var onChange: (() -> Void)?

    static let midiService = CBUUID(string: "03B80E5A-EDE8-4B33-A751-6CE34EC4C700")
    static let midiCharacteristic = CBUUID(string: "7772E5DB-3868-4112-A1A9-F2669D106BF3")

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var wanted = false

    /// Look for an OP-Z (iOS asks for Bluetooth permission the first time).
    public func start() {
        wanted = true
        if central == nil {
            central = CBCentralManager(delegate: self, queue: nil) // delegate calls on the main queue
        } else {
            scan()
        }
    }

    /// Stop looking (an OP-Z is connected some other way). A linked OP-Z stays linked.
    public func stop() {
        wanted = false
        central?.stopScan()
        if state == .searching { state = .idle }
    }

    /// Ask CoreMIDI's Bluetooth driver again to take the link (it does not always show the device the first time).
    public func reactivate() {
        if case .linked = state { MIDIBluetoothDriverActivateAllConnections() }
    }

    private func scan() {
        guard wanted, let central, central.state == .poweredOn, peripheral == nil else { return }
        // An OP-Z already connected (by the system or an earlier run) no longer advertises: take it from that list.
        if let p = central.retrieveConnectedPeripherals(withServices: [Self.midiService]).first(where: { Self.isOPZ($0.name) }) {
            return link(p)
        }
        central.scanForPeripherals(withServices: [Self.midiService])
        state = .searching
    }

    private static func isOPZ(_ name: String?) -> Bool { (name ?? "").lowercased().contains("op-z") }

    private func link(_ p: CBPeripheral) {
        central?.stopScan()
        peripheral = p
        p.delegate = self
        state = .connecting(p.name ?? "OP-Z")
        if p.state == .connected { p.discoverServices([Self.midiService]) } else { central?.connect(p) }
    }

    private func lost() {
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        peripheral = nil
        state = .idle
        scan()
    }
}

extension BluetoothLink: @preconcurrency CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            state = .idle
            scan()
        case .poweredOff: state = .off
        case .unauthorized: state = .unauthorized
        case .unsupported: state = .unsupported
        default: break
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover p: CBPeripheral,
                               advertisementData: [String: Any], rssi: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? p.name
        guard peripheral == nil, Self.isOPZ(name) else { return }
        link(p)
    }

    public func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        p.discoverServices([Self.midiService])
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        lost()
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        lost()
    }
}

extension BluetoothLink: @preconcurrency CBPeripheralDelegate {
    public func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = p.services?.first(where: { $0.uuid == Self.midiService }) else { return lost() }
        p.discoverCharacteristics([Self.midiCharacteristic], for: service)
    }

    public func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard service.characteristics?.contains(where: { $0.uuid == Self.midiCharacteristic }) == true else {
            return lost()
        }
        MIDIBluetoothDriverActivateAllConnections() // CoreMIDI now does the MIDI I/O on this link
        state = .linked(p.name ?? "OP-Z")
    }
}
#endif
