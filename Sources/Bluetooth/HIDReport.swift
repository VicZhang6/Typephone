import Foundation

/// USB HID Keyboard modifier bits (Usage Page 0x07, Usages 0xE0–0xE7).
public struct HIDModifier: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let leftControl  = HIDModifier(rawValue: 0x01)
    public static let leftShift    = HIDModifier(rawValue: 0x02)
    public static let leftAlt      = HIDModifier(rawValue: 0x04) // Option
    public static let leftGUI     = HIDModifier(rawValue: 0x08) // Command
    public static let rightControl = HIDModifier(rawValue: 0x10)
    public static let rightShift   = HIDModifier(rawValue: 0x20)
    public static let rightAlt     = HIDModifier(rawValue: 0x40)
    public static let rightGUI    = HIDModifier(rawValue: 0x80)
}

/// USB HID Keyboard/Keypad Usage IDs used by the Mac key-code mapper.
public enum HIDKeyCode: UInt8, CaseIterable, Hashable, Sendable {
    case a = 0x04
    case b = 0x05
    case c = 0x06
    case d = 0x07
    case e = 0x08
    case f = 0x09
    case g = 0x0A
    case h = 0x0B
    case i = 0x0C
    case j = 0x0D
    case k = 0x0E
    case l = 0x0F
    case m = 0x10
    case n = 0x11
    case o = 0x12
    case p = 0x13
    case q = 0x14
    case r = 0x15
    case s = 0x16
    case t = 0x17
    case u = 0x18
    case v = 0x19
    case w = 0x1A
    case x = 0x1B
    case y = 0x1C
    case z = 0x1D

    case one = 0x1E
    case two = 0x1F
    case three = 0x20
    case four = 0x21
    case five = 0x22
    case six = 0x23
    case seven = 0x24
    case eight = 0x25
    case nine = 0x26
    case zero = 0x27

    case enter = 0x28
    case escape = 0x29
    case backspace = 0x2A
    case tab = 0x2B
    case space = 0x2C
    case minus = 0x2D
    case equal = 0x2E
    case leftBracket = 0x2F
    case rightBracket = 0x30
    case backslash = 0x31
    case semicolon = 0x33
    case quote = 0x34
    case grave = 0x35
    case comma = 0x36
    case period = 0x37
    case slash = 0x38
    case capsLock = 0x39

    case f1 = 0x3A
    case f2 = 0x3B
    case f3 = 0x3C
    case f4 = 0x3D
    case f5 = 0x3E
    case f6 = 0x3F
    case f7 = 0x40
    case f8 = 0x41
    case f9 = 0x42
    case f10 = 0x43
    case f11 = 0x44
    case f12 = 0x45
    case printScreen = 0x46
    case scrollLock = 0x47
    case pause = 0x48
    case insert = 0x49
    case home = 0x4A
    case pageUp = 0x4B
    case deleteForward = 0x4C
    case end = 0x4D
    case pageDown = 0x4E
    case rightArrow = 0x4F
    case leftArrow = 0x50
    case downArrow = 0x51
    case upArrow = 0x52
    case numLock = 0x53
    case keypadDivide = 0x54
    case keypadMultiply = 0x55
    case keypadSubtract = 0x56
    case keypadAdd = 0x57
    case keypadEnter = 0x58
    case keypadOne = 0x59
    case keypadTwo = 0x5A
    case keypadThree = 0x5B
    case keypadFour = 0x5C
    case keypadFive = 0x5D
    case keypadSix = 0x5E
    case keypadSeven = 0x5F
    case keypadEight = 0x60
    case keypadNine = 0x61
    case keypadZero = 0x62
    case keypadDecimal = 0x63
    case application = 0x65
    case power = 0x66
    case keypadEqual = 0x67
    case f13 = 0x68
    case f14 = 0x69
    case f15 = 0x6A
    case f16 = 0x6B
    case f17 = 0x6C
    case f18 = 0x6D
    case f19 = 0x6E
    case f20 = 0x6F
}

/// LED report bits written by the host (Caps Lock, Num Lock, ...).
public struct HIDLedReport: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let numLock    = HIDLedReport(rawValue: 0x01)
    public static let capsLock   = HIDLedReport(rawValue: 0x02)
    public static let scrollLock = HIDLedReport(rawValue: 0x04)
    public static let compose    = HIDLedReport(rawValue: 0x08)
    public static let kana       = HIDLedReport(rawValue: 0x10)
}

/// Builds the 8-byte Boot/Report-protocol keyboard input report.
///
/// Layout: `[modifiers, reserved, key1, key2, key3, key4, key5, key6]`
public enum HIDReportBuilder {
    /// An all-zero report meaning "no keys pressed".
    public static var zero: Data {
        Data(repeating: 0, count: HIDReportDescriptor.inputReportSize)
    }

    /// Build a report for the given modifiers and up to 6 key codes.
    public static func keyboardReport(modifiers: HIDModifier = [],
                                       keys: [HIDKeyCode] = []) -> Data {
        var report = Data(repeating: 0, count: HIDReportDescriptor.inputReportSize)
        report[0] = modifiers.rawValue
        // Report supports at most 6 simultaneous keys; ignore overflow defensively.
        for (index, key) in keys.prefix(6).enumerated() {
            report[2 + index] = key.rawValue
        }
        return report
    }
}
