import Foundation

/// HID report descriptor for keyboard and Consumer Control input.
///
/// Defines two Application collections:
/// - Input report (8 bytes): 1 modifier byte, 1 reserved byte, 6 key-code bytes.
/// - Output report (1 byte): 5 LED bits (Num/Caps/Scroll/Compose/Kana) + 3 padding bits.
/// - Consumer input report (2 bytes): one Consumer usage, used for Eject.
///
/// Report IDs identify the GATT Report characteristics. The characteristic
/// values themselves contain only the report payload; the Report Reference
/// descriptor carries the ID for HOGP.
enum HIDReportDescriptor {
    static let bytes: [UInt8] = [
        0x05, 0x01, // Usage Page (Generic Desktop)
        0x09, 0x06, // Usage (Keyboard)
        0xA1, 0x01, // Collection (Application)
        0x85, 0x01, //   Report ID (1: keyboard)

        // --- Modifier byte (8 bits, one per modifier key) ---
        0x05, 0x07, //   Usage Page (Keyboard/Keypad)
        0x19, 0xE0, //   Usage Minimum (Keyboard Left Control)
        0x29, 0xE7, //   Usage Maximum (Keyboard Right GUI)
        0x15, 0x00, //   Logical Minimum (0)
        0x25, 0x01, //   Logical Maximum (1)
        0x75, 0x01, //   Report Size (1)
        0x95, 0x08, //   Report Count (8)
        0x81, 0x02, //   Input (Data,Var,Abs) -> modifier byte

        // --- Reserved byte ---
        0x95, 0x01, //   Report Count (1)
        0x75, 0x08, //   Report Size (8)
        0x81, 0x01, //   Input (Const) -> reserved byte

        // --- LED output report (1 byte: 5 LEDs + 3 padding bits) ---
        0x95, 0x05, //   Report Count (5)
        0x75, 0x01, //   Report Size (1)
        0x05, 0x08, //   Usage Page (LEDs)
        0x19, 0x01, //   Usage Minimum (Num Lock)
        0x29, 0x05, //   Usage Maximum (Kana)
        0x91, 0x02, //   Output (Data,Var,Abs) -> 5 LED bits
        0x95, 0x01, //   Report Count (1)
        0x75, 0x03, //   Report Size (3)
        0x91, 0x01, //   Output (Const) -> 3 padding bits

        // --- Key array (6 bytes) ---
        0x95, 0x06, //   Report Count (6)
        0x75, 0x08, //   Report Size (8)
        0x15, 0x00, //   Logical Minimum (0)
        0x25, 0x65, //   Logical Maximum (101)
        0x05, 0x07, //   Usage Page (Keyboard/Keypad)
        0x19, 0x00, //   Usage Minimum (0)
        0x29, 0x65, //   Usage Maximum (101)
        0x81, 0x00, //   Input (Data,Array) -> up to 6 simultaneous keys

        0xC0,       // End Collection

        // --- Consumer Control: Eject toggles the iOS software keyboard ---
        0x05, 0x0C,       // Usage Page (Consumer)
        0x09, 0x01,       // Usage (Consumer Control)
        0xA1, 0x01,       // Collection (Application)
        0x85, 0x02,       //   Report ID (2: consumer control)
        0x15, 0x00,       //   Logical Minimum (0 = no control)
        0x26, 0xFF, 0x03, //   Logical Maximum (0x03FF)
        0x19, 0x00,       //   Usage Minimum (0)
        0x2A, 0xFF, 0x03, //   Usage Maximum (0x03FF)
        0x75, 0x10,       //   Report Size (16 bits)
        0x95, 0x01,       //   Report Count (1)
        0x81, 0x00,       //   Input (Data,Array,Abs)
        0xC0              // End Collection
    ]

    static var data: Data { Data(bytes) }

    /// Size of a keyboard input report in bytes (modifier + reserved + 6 keys).
    static let inputReportSize = 8

    /// Size of the LED output report in bytes.
    static let outputReportSize = 1

    /// Size of a Consumer Control input report payload (without Report ID).
    static let consumerInputReportSize = 2
}
