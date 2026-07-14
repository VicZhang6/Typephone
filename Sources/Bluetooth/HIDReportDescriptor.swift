import Foundation

/// Standard USB HID Keyboard Report Descriptor (no Report IDs).
///
/// Defines a single Application collection for a keyboard:
/// - Input report (8 bytes): 1 modifier byte, 1 reserved byte, 6 key-code bytes.
/// - Output report (1 byte): 5 LED bits (Num/Caps/Scroll/Compose/Kana) + 3 padding bits.
///
/// This is the classic, universally-compatible descriptor that iOS/iPadOS
/// recognises as an external keyboard. Report IDs are intentionally omitted
/// so the Report Reference descriptors use ID 0 ("the report without an ID").
enum HIDReportDescriptor {
    static let bytes: [UInt8] = [
        0x05, 0x01, // Usage Page (Generic Desktop)
        0x09, 0x06, // Usage (Keyboard)
        0xA1, 0x01, // Collection (Application)

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

        0xC0        // End Collection
    ]

    static var data: Data { Data(bytes) }

    /// Size of a keyboard input report in bytes (modifier + reserved + 6 keys).
    static let inputReportSize = 8

    /// Size of the LED output report in bytes.
    static let outputReportSize = 1
}
