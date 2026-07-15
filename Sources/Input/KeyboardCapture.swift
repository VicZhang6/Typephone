@preconcurrency import CoreGraphics
import Foundation

enum CapturedKeyboardEventKind: Sendable {
    case keyDown
    case keyUp
    case flagsChanged
}

struct CapturedKeyboardEvent: Sendable {
    let kind: CapturedKeyboardEventKind
    let keyCode: UInt16
    let hidKey: HIDKeyCode?
    let flagsRawValue: UInt64
    let isRepeat: Bool
    let isPressed: Bool

    var flags: CGEventFlags { CGEventFlags(rawValue: flagsRawValue) }
}

/// Thin CGEventTap wrapper. It runs on the main run loop so report ordering is
/// deterministic relative to the CoreBluetooth manager's main queue.
final class KeyboardCapture {
    var suppressEvents = false
    /// Return `true` to suppress this individual event regardless of the
    /// capture-wide routing mode (used by the emergency exit shortcut).
    var onEvent: ((CapturedKeyboardEvent) -> Bool)?
    var onTapFailure: ((String) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { eventTap != nil }

    static func currentlyPressedKeyCodes() -> Set<UInt16> {
        var pressed: Set<UInt16> = []
        for keyCode in UInt16(0)...UInt16(127) {
            if CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(keyCode)) {
                pressed.insert(keyCode)
            }
        }
        return pressed
    }

    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)
            | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: suppressEvents ? .defaultTap : .listenOnly,
            eventsOfInterest: mask,
            callback: Self.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            onTapFailure?("无法创建 CGEventTap，请在系统设置中授予输入监控和辅助功能权限。")
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private static let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let capture = Unmanaged<KeyboardCapture>.fromOpaque(userInfo).takeUnretainedValue()
        return capture.handle(proxy: proxy, type: type, event: event)
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            onTapFailure?("系统暂时停用了键盘监听，正在尝试重新启用。")
            return Unmanaged.passUnretained(event)
        }

        let kind: CapturedKeyboardEventKind
        switch type {
        case .keyDown: kind = .keyDown
        case .keyUp: kind = .keyUp
        case .flagsChanged: kind = .flagsChanged
        default: return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let isPressed: Bool = switch kind {
        case .keyDown: true
        case .keyUp: false
        case .flagsChanged:
            CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(keyCode))
        }
        let captured = CapturedKeyboardEvent(
            kind: kind,
            keyCode: keyCode,
            hidKey: KeyCodeMapper.hidKey(for: event),
            flagsRawValue: event.flags.rawValue,
            isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
            isPressed: isPressed
        )
        let suppressThisEvent = onEvent?(captured) ?? false

        // `suppressEvents` selects a writable event tap. RoutingController makes
        // the per-event decision so releases for keys held before exclusive mode
        // can still reach the Mac.
        return suppressThisEvent ? nil : Unmanaged.passUnretained(event)
    }
}
