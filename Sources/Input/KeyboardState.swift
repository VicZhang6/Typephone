import Foundation

/// Mutable state for a single HID keyboard report stream.
struct KeyboardState: Sendable {
    private(set) var modifiers: HIDModifier = []
    private(set) var keys: Set<HIDKeyCode> = []

    var isEmpty: Bool { modifiers.isEmpty && keys.isEmpty }

    mutating func press(_ key: HIDKeyCode) {
        keys.insert(key)
    }

    mutating func release(_ key: HIDKeyCode) {
        keys.remove(key)
    }

    mutating func setModifier(_ modifier: HIDModifier, pressed: Bool) {
        if pressed {
            modifiers.insert(modifier)
        } else {
            modifiers.remove(modifier)
        }
    }

    mutating func clear() {
        modifiers = []
        keys.removeAll(keepingCapacity: true)
    }

    func report() -> Data {
        let orderedKeys = keys.sorted { $0.rawValue < $1.rawValue }
        return HIDReportBuilder.keyboardReport(modifiers: modifiers, keys: orderedKeys)
    }
}
