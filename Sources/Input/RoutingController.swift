import Combine
import Foundation

enum RoutingMode: String, CaseIterable, Codable, Sendable {
    case off
    case mirror
    case exclusive

    var title: String {
        switch self {
        case .off: "关闭"
        case .mirror: "镜像输入"
        case .exclusive: "独占输入"
        }
    }

    var detail: String {
        switch self {
        case .off: "按键只留在 Mac"
        case .mirror: "Mac 和 iPhone 同时接收"
        case .exclusive: "按键只发送到 iPhone"
        }
    }
}

@MainActor
final class RoutingController: ObservableObject {
    @Published private(set) var mode: RoutingMode = .off
    @Published private(set) var lastError: String?

    private let peripheral: BLEPeripheral
    private let permissions: PermissionManager
    private let capture = KeyboardCapture()
    private var keyboardState = KeyboardState()
    private var pressedModifierKeyCodes: Set<UInt16> = []
    private var capsLockActive = false

    var onEmergencyExit: (() -> Void)?

    init(peripheral: BLEPeripheral, permissions: PermissionManager) {
        self.peripheral = peripheral
        self.permissions = permissions
        capture.onEvent = { [weak self] event in
            self?.handle(event) ?? false
        }
        capture.onTapFailure = { [weak self] message in
            Task { @MainActor in self?.lastError = message }
        }
    }

    var isCapturing: Bool { capture.isRunning }
    var pressedKeys: [String] {
        keyboardState.keys.sorted { $0.rawValue < $1.rawValue }.map { String(format: "0x%02X", $0.rawValue) }
    }

    @discardableResult
    func setMode(_ newMode: RoutingMode) -> Bool {
        releaseAll()

        if newMode == .off {
            capture.stop()
            mode = .off
            return true
        }

        capture.stop()

        guard permissions.canCaptureKeyboard else {
            lastError = "缺少输入监控权限"
            permissions.requestAccess()
            mode = .off
            return false
        }
        if newMode == .exclusive && !permissions.canSuppressKeyboard {
            lastError = "独占模式需要输入监控和辅助功能权限"
            permissions.requestAccess()
            mode = .off
            return false
        }

        capture.suppressEvents = newMode == .exclusive
        guard capture.start() else {
            capture.suppressEvents = false
            mode = .off
            return false
        }
        mode = newMode
        return true
    }

    func connectionDidChange(isConnected: Bool) {
        if !isConnected {
            releaseAll()
            _ = setMode(.off)
        } else if mode != .off {
            _ = peripheral.sendKeyboardReport(keyboardState.report())
        }
    }

    func prepareForSleep() {
        releaseAll()
    }

    func releaseAll() {
        keyboardState.clear()
        pressedModifierKeyCodes.removeAll(keepingCapacity: true)
        capsLockActive = false
        _ = peripheral.sendKeyboardReport(HIDReportBuilder.zero)
    }

    var diagnosticsPayload: [String: Any] {
        [
            "mode": mode.rawValue,
            "modeTitle": mode.title,
            "isCapturing": isCapturing,
            "pressedKeys": pressedKeys,
            "lastError": lastError as Any
        ]
    }

    private func handle(_ event: CapturedKeyboardEvent) -> Bool {
        if isEmergencyShortcut(event) {
            releaseAll()
            mode = .off
            capture.suppressEvents = false
            DispatchQueue.main.async { [weak self] in self?.capture.stop() }
            onEmergencyExit?()
            return true
        }

        guard mode != .off else { return false }

        switch event.kind {
        case .keyDown:
            guard !event.isRepeat else { return false }
            guard let key = event.hidKey else { return false }
            keyboardState.press(key)
            _ = peripheral.sendKeyboardReport(keyboardState.report())
        case .keyUp:
            guard let key = event.hidKey else { return false }
            keyboardState.release(key)
            _ = peripheral.sendKeyboardReport(keyboardState.report())
        case .flagsChanged:
            handleFlagsChanged(event)
        }
        return false
    }

    private func handleFlagsChanged(_ event: CapturedKeyboardEvent) {
        if KeyCodeMapper.isCapsLock(event.keyCode) {
            let isPressed = event.flags.contains(.maskAlphaShift)
            guard isPressed != capsLockActive else { return }
            capsLockActive = isPressed
            keyboardState.press(.capsLock)
            _ = peripheral.sendKeyboardReport(keyboardState.report())
            keyboardState.release(.capsLock)
            _ = peripheral.sendKeyboardReport(keyboardState.report())
            return
        }

        guard let modifier = KeyCodeMapper.modifier(for: event.keyCode) else { return }
        if pressedModifierKeyCodes.contains(event.keyCode) {
            pressedModifierKeyCodes.remove(event.keyCode)
            keyboardState.setModifier(modifier, pressed: false)
        } else {
            pressedModifierKeyCodes.insert(event.keyCode)
            keyboardState.setModifier(modifier, pressed: true)
        }
        _ = peripheral.sendKeyboardReport(keyboardState.report())
    }

    private func isEmergencyShortcut(_ event: CapturedKeyboardEvent) -> Bool {
        guard event.kind == .keyDown, event.keyCode == 53 else { return false }
        let flags = event.flags
        return flags.contains(.maskControl)
            && flags.contains(.maskAlternate)
            && flags.contains(.maskCommand)
    }
}
