import Foundation
import SystemConfiguration

/// Resolves the user-visible Mac name used for BLE advertising.
enum DeviceNameProvider {
    static let fallbackName = "Typephone Keyboard"

    static var currentComputerName: String {
        var encoding = CFStringBuiltInEncodings.UTF8.rawValue
        let computerName = SCDynamicStoreCopyComputerName(nil, &encoding) as String?
        return normalized(computerName)
    }

    static func normalized(_ name: String?) -> String {
        guard let name else { return fallbackName }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallbackName : trimmed
    }
}
