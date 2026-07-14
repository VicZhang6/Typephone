import AppKit
import ApplicationServices
import CoreGraphics
import Combine

@MainActor
final class PermissionManager: ObservableObject {
    @Published private(set) var listenAccess = false
    @Published private(set) var postAccess = false
    @Published private(set) var accessibilityAccess = false

    var canCaptureKeyboard: Bool { listenAccess }
    var canSuppressKeyboard: Bool { listenAccess && postAccess && accessibilityAccess }

    init() {
        refresh()
    }

    @discardableResult
    func refresh() -> Bool {
        listenAccess = CGPreflightListenEventAccess()
        postAccess = CGPreflightPostEventAccess()
        accessibilityAccess = AXIsProcessTrusted()
        return canCaptureKeyboard
    }

    func requestAccess() {
        _ = CGRequestListenEventAccess()
        _ = CGRequestPostEventAccess()
        // The documented key is stable and using the literal avoids Swift 6
        // treating ApplicationServices' imported global CFString as mutable
        // shared state.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func openInputMonitoringSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
        NSWorkspace.shared.open(url)
    }
}
