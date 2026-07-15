import AppKit
import Combine
import Foundation
import SwiftUI

/// Top-level product state shared by the native menu and Electron control API.
@MainActor
final class AppState: ObservableObject {
    let peripheral: BLEPeripheral
    let connection: ConnectionController
    let permissions: PermissionManager
    let routing: RoutingController
    let diagnostics: DiagnosticsRecorder

    private let sleepWakeMonitor: SleepWakeMonitor
    private var cancellables = Set<AnyCancellable>()

    init() {
        let peripheral = BLEPeripheral()
        let permissions = PermissionManager()
        self.peripheral = peripheral
        self.permissions = permissions
        self.connection = ConnectionController(peripheral: peripheral)
        self.routing = RoutingController(peripheral: peripheral, permissions: permissions)
        self.diagnostics = DiagnosticsRecorder()
        self.sleepWakeMonitor = SleepWakeMonitor()

        bind()
    }

    var statusText: String {
        if routing.mode != .off, peripheral.isSubscribed {
            return routing.mode == .exclusive ? "正在独占输入到 iPhone" : "正在镜像输入到 iPhone"
        }
        // Prefer subscription over BLEStatus — advertising restarts must not
        // report "等待配对" while HID input is already subscribed.
        if peripheral.isSubscribed {
            return "已连接 iPhone"
        }
        return switch peripheral.status {
        case .unknown: "未启动"
        case .bluetoothUnavailable: "蓝牙不可用"
        case .ready: "就绪"
        case .advertising: "等待配对"
        case .connected: "已连接 iPhone"
        case .error(let msg): "异常：\(msg)"
        }
    }

    var statusDot: String {
        if peripheral.isSubscribed { return "●" }
        return switch peripheral.status {
        case .connected: "●"
        case .advertising: "◐"
        case .error: "⚠︎"
        default: "○"
        }
    }

    var canSendA: Bool { peripheral.isSubscribed }

    /// JSON-safe state for the Electron renderer and diagnostics export.
    var statusPayload: [String: Any] {
        // Always surface an active HID subscription as connected so the UI
        // cannot show "等待配对" when the phone is already subscribed.
        let status: String
        if peripheral.isSubscribed {
            status = "connected"
        } else {
            switch peripheral.status {
            case .unknown: status = "unknown"
            case .bluetoothUnavailable: status = "bluetoothUnavailable"
            case .ready: status = "ready"
            case .advertising: status = "advertising"
            case .connected: status = "connected"
            case .error: status = "error"
            }
        }

        return [
            "type": "status",
            "status": status,
            "statusText": statusText,
            "bluetoothState": peripheral.bluetoothStateName,
            "isAdvertising": peripheral.isAdvertising,
            "hidServiceAdded": peripheral.isHIDServiceAdded,
            "addedServices": peripheral.addedServices,
            "isSubscribed": peripheral.isSubscribed,
            "connectedCentralID": peripheral.connectedCentralID ?? NSNull(),
            "subscribedCharacteristics": peripheral.subscribedCharacteristicNames,
            "canSendA": canSendA,
            "lastReportHex": peripheral.lastReportHex,
            "capsLock": peripheral.lastLEDReport.contains(.capsLock),
            "batteryLevel": peripheral.batteryLevel,
            "queueDepth": peripheral.queueDepth,
            "nativeError": peripheral.lastError ?? NSNull(),
            "routingMode": routing.mode.rawValue,
            "routingModeTitle": routing.mode.title,
            "isCapturing": routing.isCapturing,
            "pressedKeys": routing.pressedKeys,
            "routingError": routing.lastError ?? NSNull(),
            "listenAccess": permissions.listenAccess,
            "postAccess": permissions.postAccess,
            "accessibilityAccess": permissions.accessibilityAccess,
            "canCaptureKeyboard": permissions.canCaptureKeyboard,
            "canSuppressKeyboard": permissions.canSuppressKeyboard,
            "emergencyShortcut": "⌃⌥⌘Esc",
            "diagnosticEventCount": diagnostics.eventCount
        ]
    }

    func start() {
        diagnostics.record("Typephone 启动")
        connection.start()
    }

    func shutdown() {
        _ = routing.setMode(.off)
        connection.stop()
        sleepWakeMonitor.stop()
        diagnostics.record("Typephone 退出")
    }

    func toggleAdvertising() {
        if peripheral.isAdvertising || peripheral.status == .advertising {
            connection.stop()
        } else {
            connection.start()
        }
    }

    func sendLetterA() {
        peripheral.tapKey(.a)
        diagnostics.record("发送测试按键 A")
    }

    func restart() {
        routing.releaseAll()
        connection.restart()
        diagnostics.record("重新等待配对")
    }

    @discardableResult
    func setRoutingMode(_ mode: RoutingMode) -> Bool {
        guard peripheral.isSubscribed || mode == .off else {
            diagnostics.record("未连接 iPhone，拒绝启用 \(mode.rawValue) 模式", level: "warning")
            return false
        }
        let changed = routing.setMode(mode)
        diagnostics.record(changed ? "路由模式切换为 \(mode.rawValue)" : "路由模式切换失败：\(mode.rawValue)", level: changed ? "info" : "warning")
        return changed
    }

    func requestPermissions() {
        permissions.requestAccess()
        diagnostics.record("请求输入监控与辅助功能权限")
    }

    func openAccessibilitySettings() {
        permissions.openAccessibilitySettings()
    }

    func openInputMonitoringSettings() {
        permissions.openInputMonitoringSettings()
    }

    func exportDiagnostics() -> URL? {
        diagnostics.export(snapshot: statusPayload)
    }

    private func bind() {
        peripheral.$status
            .removeDuplicates()
            .sink { [weak self] status in
                self?.diagnostics.record("BLE 状态：\(String(describing: status))")
            }
            .store(in: &cancellables)

        peripheral.$isSubscribed
            .removeDuplicates()
            .sink { [weak self] isConnected in
                self?.routing.connectionDidChange(isConnected: isConnected)
                self?.diagnostics.record(isConnected ? "iPhone 已订阅 HID 输入报告" : "iPhone HID 订阅已断开")
            }
            .store(in: &cancellables)

        Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in _ = self?.permissions.refresh() }
            .store(in: &cancellables)

        routing.onEmergencyExit = { [weak self] in
            self?.diagnostics.record("紧急快捷键触发，已退出独占模式", level: "warning")
        }

        sleepWakeMonitor.onWillSleep = { [weak self] in
            guard let self else { return }
            routing.prepareForSleep()
            peripheral.prepareForSleep()
            diagnostics.record("Mac 即将睡眠，已释放全部按键")
        }
        sleepWakeMonitor.onDidWake = { [weak self] in
            guard let self else { return }
            permissions.refresh()
            peripheral.resumeAfterWake()
            diagnostics.record("Mac 已唤醒，正在恢复等待配对")
        }
    }
}
