import Foundation
import CoreBluetooth
import Combine

/// Observable status of the BLE HID peripheral.
enum BLEStatus: Equatable {
    case unknown
    case bluetoothUnavailable
    case ready
    case advertising
    case connected(name: String?)
    case error(String)
}

/// `CBPeripheralManager` wrapper that advertises a complete HOGP keyboard.
///
/// Publishes the complete BLE HOGP profile, manages advertising and
/// subscriptions, and pushes ordered 8-byte reports to a subscribed Central.
@MainActor
final class BLEPeripheral: NSObject, ObservableObject, @preconcurrency CBPeripheralManagerDelegate {

    /// Advertised device name shown in iOS Bluetooth settings.
    static let deviceName = "Typephone Keyboard"

    @Published private(set) var status: BLEStatus = .unknown
    @Published private(set) var isSubscribed = false
    @Published private(set) var isAdvertising = false
    @Published private(set) var lastReportHex: String = ""
    @Published private(set) var lastLEDReport: HIDLedReport = []
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var lastError: String?
    @Published private(set) var connectedCentralID: String?
    @Published private(set) var batteryLevel: UInt8 = 100

    private let manager: CBPeripheralManager
    private var hidService: CBMutableService?
    private var deviceInfoService: CBMutableService?
    private var batteryService: CBMutableService?
    private var characteristics: [HIDProfile.CharacteristicID: CBMutableCharacteristic] = [:]
    private var characteristicValues: [HIDProfile.CharacteristicID: Data] = [
        .protocolMode: Data([0x01]),
        .inputReport: HIDReportBuilder.zero,
        .outputReport: Data([0x00]),
        .bootKeyboardInput: HIDReportBuilder.zero,
        .bootKeyboardOutput: Data([0x00]),
        .batteryLevel: Data([100])
    ]
    private var wantsAdvertising = false

    /// Central currently subscribed to input reports (single-host product scope).
    private var subscriber: CBCentral?
    /// Reports are kept in order until both subscribed input characteristics
    /// accept them. This prevents a fast key stream from dropping key-up
    /// reports when CoreBluetooth's notification buffer is full.
    private var reportQueue = HIDReportQueue()
    private var subscribedCharacteristics: Set<HIDProfile.CharacteristicID> = []
    private var pendingServiceUUIDs: Set<String> = []
    private var addedServiceUUIDs: Set<String> = []

    init(queue: DispatchQueue? = .main) {
        self.manager = CBPeripheralManager(delegate: nil, queue: queue, options: [
            CBPeripheralManagerOptionShowPowerAlertKey: true
        ])
        super.init()
        self.manager.delegate = self
    }

    // MARK: - Public API

    func startAdvertising() {
        wantsAdvertising = true
        guard manager.state == .poweredOn else {
            status = .bluetoothUnavailable
            return
        }
        publishServicesIfNeeded()
        guard pendingServiceUUIDs.isEmpty else {
            status = .ready
            return
        }
        beginAdvertising()
    }

    private func beginAdvertising() {
        guard manager.state == .poweredOn else { return }
        let advertisement: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [HIDProfile.hidServiceUUID],
            CBAdvertisementDataLocalNameKey: Self.deviceName
        ]
        manager.startAdvertising(advertisement)
        // Keep an active HID subscription as "connected". Restarting
        // advertising (wake / service re-add) must not look unpaired.
        if isSubscribed {
            if case .connected = status { return }
            status = .connected(name: connectedCentralID)
            return
        }
        status = .advertising
    }

    func stopAdvertising() {
        wantsAdvertising = false
        manager.stopAdvertising()
        isAdvertising = false
        // Never demote an active subscription when the user only stops discovery.
        if isSubscribed { return }
        if case .advertising = status { status = .ready }
    }

    /// Send a keyboard input report to the subscribed Central.
    /// Returns `false` if no Central is subscribed (nothing to send to).
    @discardableResult
    func sendKeyboardReport(_ report: Data) -> Bool {
        guard subscriber != nil,
              manager.state == .poweredOn,
              !subscribedCharacteristics.isEmpty else { return false }
        characteristicValues[.inputReport] = report
        characteristicValues[.bootKeyboardInput] = report
        lastReportHex = report.map { String(format: "%02X", $0) }.joined(separator: " ")
        var destinations: HIDReportDestination = []
        if subscribedCharacteristics.contains(.inputReport) { destinations.insert(.reportInput) }
        if subscribedCharacteristics.contains(.bootKeyboardInput) { destinations.insert(.bootInput) }
        reportQueue.enqueue(report, destinations: destinations)
        drainReportQueue()
        return true
    }

    /// Convenience: tap a single key (down then up) with a fixed hold time.
    func tapKey(_ key: HIDKeyCode, modifiers: HIDModifier = [], holdMs: Int = 80) {
        let down = HIDReportBuilder.keyboardReport(modifiers: modifiers, keys: [key])
        sendKeyboardReport(down)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(holdMs)) { [weak self] in
            self?.sendKeyboardReport(HIDReportBuilder.zero)
        }
    }

    // MARK: - Service publishing

    private func publishServicesIfNeeded() {
        guard hidService == nil else { return }
        let (hid, hidChars) = HIDProfile.makeHIDService()
        let (dis, disChars) = HIDProfile.makeDeviceInformationService()
        let (battery, batteryChars) = HIDProfile.makeBatteryService()
        hid.includedServices = [battery]
        characteristics = hidChars
            .merging(disChars) { a, _ in a }
            .merging(batteryChars) { a, _ in a }
        hidService = hid
        deviceInfoService = dis
        batteryService = battery
        pendingServiceUUIDs = [battery.uuid.uuidString]
        // Add adopted services in a deterministic order. This also gives
        // CoreBluetooth a chance to validate each service before HID is
        // advertised.
        manager.add(battery)
    }
    // MARK: - CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        bluetoothState = peripheral.state
        handleStateChange(peripheral.state)
    }

    private func handleStateChange(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            publishServicesIfNeeded()
            if wantsAdvertising {
                if pendingServiceUUIDs.isEmpty { beginAdvertising() } else { status = .ready }
            } else {
                status = .ready
            }
        case .poweredOff:
            resetPublishedServices()
            status = .bluetoothUnavailable
            isSubscribed = false
            subscriber = nil
            connectedCentralID = nil
        case .resetting:
            resetPublishedServices()
            status = .bluetoothUnavailable
            isSubscribed = false
            subscriber = nil
            connectedCentralID = nil
        case .unauthorized, .unsupported:
            status = .bluetoothUnavailable
        case .unknown:
            status = .unknown
        @unknown default:
            status = .unknown
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                            didAdd service: CBService, error: Error?) {
        if let error {
            lastError = error.localizedDescription
            status = .error("Failed to add service \(service.uuid.uuidString): \(error.localizedDescription)")
            return
        }

        pendingServiceUUIDs.remove(service.uuid.uuidString)
        addedServiceUUIDs.insert(service.uuid.uuidString)
        switch service.uuid {
        case HIDProfile.batteryServiceUUID:
            if let deviceInfoService {
                pendingServiceUUIDs.insert(deviceInfoService.uuid.uuidString)
                peripheral.add(deviceInfoService)
            }
        case HIDProfile.deviceInfoServiceUUID:
            if let hidService {
                pendingServiceUUIDs.insert(hidService.uuid.uuidString)
                peripheral.add(hidService)
            }
        case HIDProfile.hidServiceUUID:
            if wantsAdvertising { beginAdvertising() }
        default:
            break
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            lastError = error.localizedDescription
            isAdvertising = false
            status = .error("Advertising failed: \(error.localizedDescription)")
        }
        else {
            isAdvertising = true
            // Preserve connected / subscribed state if a late advertising
            // callback arrives after the iPhone already subscribed to HID.
            if isSubscribed {
                if case .connected = status { return }
                status = .connected(name: connectedCentralID)
                return
            }
            if case .connected = status { return }
            status = .advertising
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                            didSubscribeTo characteristic: CBCharacteristic) {
        guard let id = characteristicID(for: characteristic),
              id == .inputReport || id == .bootKeyboardInput || id == .batteryLevel else { return }
        if let subscriber, subscriber.identifier != central.identifier {
            // Phase 1 intentionally supports one central. Keep the first
            // bonded phone as the active route instead of interleaving reports.
            return
        }
        subscriber = central
        connectedCentralID = central.identifier.uuidString
        subscribedCharacteristics.insert(id)
        isSubscribed = subscribedCharacteristics.contains(.inputReport)
            || subscribedCharacteristics.contains(.bootKeyboardInput)
        if isSubscribed {
            status = .connected(name: central.identifier.uuidString)
            _ = sendKeyboardReport(HIDReportBuilder.zero)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                            didUnsubscribeFrom characteristic: CBCharacteristic) {
        if let id = characteristicID(for: characteristic) {
            subscribedCharacteristics.remove(id)
        }
        isSubscribed = subscribedCharacteristics.contains(.inputReport)
            || subscribedCharacteristics.contains(.bootKeyboardInput)
        if !isSubscribed {
            subscriber = nil
            connectedCentralID = nil
            reportQueue.removeAll(keepingCapacity: true)
            status = wantsAdvertising ? .advertising : .ready
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                            didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            let char = request.characteristic
            guard let id = characteristicID(for: char) else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
                continue
            }
            if id == .bootKeyboardOutput || id == .outputReport {
                if let data = request.value, data.count >= 1 {
                    let leds = HIDLedReport(rawValue: data[0])
                    lastLEDReport = leds
                    characteristicValues[.outputReport] = data
                    characteristicValues[.bootKeyboardOutput] = data
                }
            }
            if id == .hidControlPoint { /* exit-suspend: no-op */ }
            if id == .protocolMode {
                if let data = request.value, data.count >= 1 {
                    characteristicValues[.protocolMode] = data
                }
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                            didReceiveReadRequestFor request: CBATTRequest) {
        guard let id = characteristicID(for: request.characteristic) else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }

        let value = characteristicValues[id] ?? request.characteristic.value ?? Data()
        guard request.offset <= value.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = value.subdata(in: request.offset..<value.count)
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        drainReportQueue()
    }

    var queueDepth: Int { reportQueue.count }
    var isHIDServiceAdded: Bool { addedServiceUUIDs.contains(HIDProfile.hidServiceUUID.uuidString) }
    var addedServices: [String] { addedServiceUUIDs.sorted() }

    var bluetoothStateName: String {
        switch bluetoothState {
        case .unknown: "unknown"
        case .resetting: "resetting"
        case .unsupported: "unsupported"
        case .unauthorized: "unauthorized"
        case .poweredOff: "poweredOff"
        case .poweredOn: "poweredOn"
        @unknown default: "unknown"
        }
    }

    var subscribedCharacteristicNames: [String] {
        subscribedCharacteristics.map(\.rawValue).sorted()
    }

    func prepareForSleep() {
        _ = sendKeyboardReport(HIDReportBuilder.zero)
        manager.stopAdvertising()
        isAdvertising = false
    }

    func resumeAfterWake() {
        if wantsAdvertising { startAdvertising() }
    }

    private func drainReportQueue() {
        guard let subscriber,
              manager.state == .poweredOn,
              !reportQueue.isEmpty else { return }

        let reportInput = characteristics[.inputReport]
        let bootInput = characteristics[.bootKeyboardInput]
        let manager = self.manager
        reportQueue.drain { data, destination in
            switch destination {
            case .reportInput:
                guard let input = reportInput else { return true }
                return manager.updateValue(data, for: input, onSubscribedCentrals: [subscriber])
            case .bootInput:
                guard let boot = bootInput else { return true }
                return manager.updateValue(data, for: boot, onSubscribedCentrals: [subscriber])
            default:
                return true
            }
        }
    }

    private func resetPublishedServices() {
        manager.removeAllServices()
        hidService = nil
        deviceInfoService = nil
        batteryService = nil
        characteristics.removeAll(keepingCapacity: true)
        characteristicValues[.inputReport] = HIDReportBuilder.zero
        characteristicValues[.bootKeyboardInput] = HIDReportBuilder.zero
        characteristicValues[.batteryLevel] = Data([batteryLevel])
        pendingServiceUUIDs.removeAll(keepingCapacity: true)
        addedServiceUUIDs.removeAll(keepingCapacity: true)
        reportQueue.removeAll(keepingCapacity: true)
        subscribedCharacteristics.removeAll(keepingCapacity: true)
        isAdvertising = false
    }

    func updateBatteryLevel(_ level: UInt8) {
        batteryLevel = min(level, 100)
        let value = Data([batteryLevel])
        characteristicValues[.batteryLevel] = value
        if let characteristic = characteristics[.batteryLevel],
           let subscriber,
           subscribedCharacteristics.contains(.batteryLevel) {
            _ = manager.updateValue(value, for: characteristic, onSubscribedCentrals: [subscriber])
        }
    }

    private func characteristicID(for characteristic: CBCharacteristic) -> HIDProfile.CharacteristicID? {
        characteristics.first { _, candidate in candidate === characteristic }?.key
    }
}
