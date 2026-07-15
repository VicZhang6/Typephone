import Foundation
import CoreBluetooth

/// Builds the complete HOGP (HID over GATT Profile) service tree that iOS
/// expects before it will treat a BLE peripheral as an external keyboard.
///
/// Services:
/// - HID Service (0x1812)
///     • Protocol Mode       (0x2A4E)  read + writeWithoutResponse
///     • Keyboard input      (0x2A4D)  read + notify          [+ Report Reference = (1, Input)]
///     • Consumer input      (0x2A4D)  read + notify          [+ Report Reference = (2, Input)]
///     • Keyboard output/LED (0x2A4D)  read + write           [+ Report Reference = (1, Output)]
///     • Report Map          (0x2A4B)  read
///     • HID Information     (0x2A4A)  read
///     • HID Control Point   (0x2A4C)  writeWithoutResponse
///     • Boot Keyboard Input  (0x2A22) read + notify
///     • Boot Keyboard Output (0x2A32) read + write
/// - Device Information Service (0x180A)
///     • Manufacturer Name    (0x2A4F)  read
///     • PnP ID               (0x2A50)  read
///
/// Input/Output/Control characteristics require encryption so that iOS enforces
/// bonding before delivering keystrokes.
enum HIDProfile {

    // MARK: Service UUIDs
    // CBPeripheralManager on macOS rejects short-form SIG service UUIDs.
    // Use the expanded Bluetooth base UUID for every adopted service/attribute.
    nonisolated(unsafe) static let hidServiceUUID        = CBUUID(string: "00001812-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let deviceInfoServiceUUID = CBUUID(string: "0000180A-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let batteryServiceUUID    = CBUUID(string: "0000180F-0000-1000-8000-00805F9B34FB")

    // MARK: HID characteristic UUIDs
    nonisolated(unsafe) static let protocolModeUUID      = CBUUID(string: "00002A4E-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let reportUUID           = CBUUID(string: "00002A4D-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let reportMapUUID        = CBUUID(string: "00002A4B-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let hidInformationUUID   = CBUUID(string: "00002A4A-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let hidControlPointUUID  = CBUUID(string: "00002A4C-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let bootKeyboardInputUUID  = CBUUID(string: "00002A22-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let bootKeyboardOutputUUID = CBUUID(string: "00002A32-0000-1000-8000-00805F9B34FB")

    // MARK: Descriptor UUIDs
    nonisolated(unsafe) static let reportReferenceUUID  = CBUUID(string: "00002908-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let cccUUID             = CBUUID(string: "00002902-0000-1000-8000-00805F9B34FB")

    // MARK: Device Information UUIDs
    // Manufacturer Name String is 0x2A29. 0x2A4F is a different GATT
    // characteristic and makes some iOS hosts reject the Device Information
    // service during HID discovery.
    nonisolated(unsafe) static let manufacturerNameUUID = CBUUID(string: "00002A29-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let modelNumberUUID      = CBUUID(string: "00002A24-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let pnpIDUUID             = CBUUID(string: "00002A50-0000-1000-8000-00805F9B34FB")
    nonisolated(unsafe) static let batteryLevelUUID      = CBUUID(string: "00002A19-0000-1000-8000-00805F9B34FB")

    // Report Reference descriptor values: (reportID, reportType)
    // reportType: 1 = Input, 2 = Output, 3 = Feature.
    static let keyboardInputReportReference  = Data([0x01, 0x01])
    static let keyboardOutputReportReference = Data([0x01, 0x02])
    static let consumerInputReportReference  = Data([0x02, 0x01])

    // HID Information value: bcdHID = 1.11 (0x0111), country code = 0 (NotLocalized),
    // flags = 0x03 (Remote Wake capable + Normally Connectable).
    static let hidInformationValue = Data([0x11, 0x01, 0x00, 0x03])

    // Development PnP identity: Bluetooth SIG source, test vendor 0xFFFF.
    // Do not impersonate Apple's USB vendor ID.
    static let pnpIDValue = Data([0x01, 0xFF, 0xFF, 0x01, 0x00, 0x00, 0x01])

    enum CharacteristicID: String {
        case protocolMode
        case inputReport
        case consumerInputReport
        case outputReport
        case reportMap
        case hidInformation
        case hidControlPoint
        case bootKeyboardInput
        case bootKeyboardOutput
        case manufacturerName
        case modelNumber
        case pnpID
        case batteryLevel
    }


    // MARK: Build

    /// Build the HID Service. Returned characteristics are mutable so the
    /// peripheral manager can update their values at runtime.
    static func makeHIDService() -> (CBMutableService, [CharacteristicID: CBMutableCharacteristic]) {
        var chars: [CharacteristicID: CBMutableCharacteristic] = [:]

        // Protocol Mode — default Report Mode (1).
        let protocolMode = CBMutableCharacteristic(
            type: protocolModeUUID,
            properties: [.read, .writeWithoutResponse],
            value: nil,
            permissions: [.readable, .writeable, .readEncryptionRequired, .writeEncryptionRequired]
        )
        chars[.protocolMode] = protocolMode

        // Report Map — the keyboard descriptor.
        let reportMap = CBMutableCharacteristic(
            type: reportMapUUID,
            properties: [.read],
            value: HIDReportDescriptor.data,
            permissions: [.readable]
        )
        chars[.reportMap] = reportMap

        // HID Information.
        let hidInformation = CBMutableCharacteristic(
            type: hidInformationUUID,
            properties: [.read],
            value: hidInformationValue,
            permissions: [.readable]
        )
        chars[.hidInformation] = hidInformation

        // HID Control Point — host writes 0x01 to exit suspend.
        let hidControlPoint = CBMutableCharacteristic(
            type: hidControlPointUUID,
            properties: [.writeWithoutResponse],
            value: nil,
            permissions: [.writeable, .writeEncryptionRequired]
        )
        chars[.hidControlPoint] = hidControlPoint

        // Keyboard input report (Report protocol) — notify, encrypted.
        let inputReportRef = CBMutableDescriptor(
            type: reportReferenceUUID,
            value: NSData(data: keyboardInputReportReference)
        )
        let inputReport = CBMutableCharacteristic(
            type: reportUUID,
            properties: [.read, .notify, .notifyEncryptionRequired],
            value: nil,
            permissions: [.readable, .readEncryptionRequired]
        )
        inputReport.descriptors = [inputReportRef]
        chars[.inputReport] = inputReport

        // Consumer Control input — Eject toggles the iOS software keyboard.
        let consumerInputReportRef = CBMutableDescriptor(
            type: reportReferenceUUID,
            value: NSData(data: consumerInputReportReference)
        )
        let consumerInputReport = CBMutableCharacteristic(
            type: reportUUID,
            properties: [.read, .notify, .notifyEncryptionRequired],
            value: nil,
            permissions: [.readable, .readEncryptionRequired]
        )
        consumerInputReport.descriptors = [consumerInputReportRef]
        chars[.consumerInputReport] = consumerInputReport

        // Keyboard output report (Report protocol, LEDs) — write, encrypted.
        let outputReportRef = CBMutableDescriptor(
            type: reportReferenceUUID,
            value: NSData(data: keyboardOutputReportReference)
        )
        let outputReport = CBMutableCharacteristic(
            type: reportUUID,
            properties: [.read, .write, .writeWithoutResponse],
            value: nil,
            permissions: [.readable, .writeable, .readEncryptionRequired, .writeEncryptionRequired]
        )
        outputReport.descriptors = [outputReportRef]
        chars[.outputReport] = outputReport

        // Boot Keyboard Input — same 8-byte report, no Report Reference needed.
        let bootInput = CBMutableCharacteristic(
            type: bootKeyboardInputUUID,
            properties: [.read, .notify, .notifyEncryptionRequired],
            value: nil,
            permissions: [.readable, .readEncryptionRequired]
        )
        chars[.bootKeyboardInput] = bootInput

        // Boot Keyboard Output — LED state, 1 byte.
        let bootOutput = CBMutableCharacteristic(
            type: bootKeyboardOutputUUID,
            properties: [.read, .write, .writeWithoutResponse],
            value: nil,
            permissions: [.readable, .writeable, .readEncryptionRequired, .writeEncryptionRequired]
        )
        chars[.bootKeyboardOutput] = bootOutput

        let service = CBMutableService(type: hidServiceUUID, primary: true)
        service.characteristics = [
            protocolMode, reportMap, hidInformation, hidControlPoint,
            inputReport, consumerInputReport, outputReport, bootInput, bootOutput
        ]
        return (service, chars)
    }

    static func makeDeviceInformationService() -> (CBMutableService, [CharacteristicID: CBMutableCharacteristic]) {
        var chars: [CharacteristicID: CBMutableCharacteristic] = [:]

        let manufacturer = CBMutableCharacteristic(
            type: manufacturerNameUUID,
            properties: [.read],
            value: Data("Typephone".utf8),
            permissions: [.readable]
        )
        chars[.manufacturerName] = manufacturer

        let modelNumber = CBMutableCharacteristic(
            type: modelNumberUUID,
            properties: [.read],
            value: Data("Typephone-0.1".utf8),
            permissions: [.readable]
        )
        chars[.modelNumber] = modelNumber

        let pnpID = CBMutableCharacteristic(
            type: pnpIDUUID,
            properties: [.read],
            value: pnpIDValue,
            permissions: [.readable]
        )
        chars[.pnpID] = pnpID

        let service = CBMutableService(type: deviceInfoServiceUUID, primary: true)
        service.characteristics = [manufacturer, modelNumber, pnpID]
        return (service, chars)
    }

    static func makeBatteryService() -> (CBMutableService, [CharacteristicID: CBMutableCharacteristic]) {
        let level = CBMutableCharacteristic(
            type: batteryLevelUUID,
            properties: [.read, .notifyEncryptionRequired],
            value: nil,
            permissions: [.readEncryptionRequired]
        )
        let service = CBMutableService(type: batteryServiceUUID, primary: true)
        service.characteristics = [level]
        return (service, [.batteryLevel: level])
    }
}
