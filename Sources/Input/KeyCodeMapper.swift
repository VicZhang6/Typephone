import CoreGraphics

/// Converts the hardware-independent macOS virtual key codes into USB HID
/// keyboard usages. The map deliberately uses usages instead of characters so
/// the receiving iPhone's active keyboard layout/input method remains in charge.
enum KeyCodeMapper {
    private static let keyMap: [UInt16: HIDKeyCode] = [
        0: .a, 1: .s, 2: .d, 3: .f, 4: .h, 5: .g, 6: .z, 7: .x, 8: .c, 9: .v,
        11: .b, 12: .q, 13: .w, 14: .e, 15: .r, 16: .y, 17: .t,
        18: .one, 19: .two, 20: .three, 21: .four, 22: .six, 23: .five,
        24: .equal, 25: .nine, 26: .seven, 27: .minus, 28: .eight, 29: .zero,
        30: .rightBracket, 31: .o, 32: .u, 33: .leftBracket, 34: .i, 35: .p,
        36: .enter, 37: .l, 38: .j, 39: .quote, 40: .k, 41: .semicolon,
        42: .backslash, 43: .comma, 44: .slash, 45: .n, 46: .m, 47: .period,
        48: .tab, 49: .space, 50: .grave, 51: .backspace, 53: .escape,
        65: .keypadDecimal, 67: .keypadMultiply, 69: .keypadAdd, 71: .numLock,
        75: .keypadDivide, 76: .keypadEnter, 78: .keypadSubtract, 81: .keypadEqual,
        82: .keypadZero, 83: .keypadOne, 84: .keypadTwo, 85: .keypadThree,
        86: .keypadFour, 87: .keypadFive, 88: .keypadSix, 89: .keypadSeven,
        91: .keypadEight, 92: .keypadNine,
        96: .f5, 97: .f6, 98: .f7, 99: .f3, 100: .f8, 101: .f9,
        103: .f11, 105: .f13, 106: .f16, 107: .f14, 109: .f10, 111: .f12,
        113: .f15, 114: .insert, 115: .home, 116: .pageUp, 117: .deleteForward,
        118: .f4, 119: .end, 120: .f2, 121: .pageDown, 122: .f1,
        123: .leftArrow, 124: .rightArrow, 125: .downArrow, 126: .upArrow
    ]

    private static let modifierMap: [UInt16: HIDModifier] = [
        54: .rightGUI,
        55: .leftGUI,
        56: .leftShift,
        58: .leftAlt,
        59: .leftControl,
        60: .rightShift,
        61: .rightAlt,
        62: .rightControl
    ]

    static func hidKey(for keyCode: UInt16) -> HIDKeyCode? {
        keyMap[keyCode]
    }

    static func hidKey(for event: CGEvent) -> HIDKeyCode? {
        hidKey(for: UInt16(event.getIntegerValueField(.keyboardEventKeycode)))
    }

    static func modifier(for keyCode: UInt16) -> HIDModifier? {
        modifierMap[keyCode]
    }

    static func isModifier(_ keyCode: UInt16) -> Bool {
        modifierMap[keyCode] != nil
    }

    static func isCapsLock(_ keyCode: UInt16) -> Bool {
        keyCode == 57
    }
}
