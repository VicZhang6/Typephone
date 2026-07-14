import AppKit
import Combine

/// Owns the `NSStatusItem` and rebuilds its menu whenever `AppState` changes.
@MainActor
final class MenuBarController: NSObject {

    private let statusItem: NSStatusItem
    private let state: AppState
    private var cancellables = Set<AnyCancellable>()

    init(state: AppState) {
        self.state = state
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.button?.title = "⌨︎"
        bind()
    }

    private func bind() {
        state.peripheral.$status
            .combineLatest(state.peripheral.$isSubscribed,
                            state.peripheral.$lastReportHex,
                            state.peripheral.$lastLEDReport)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        state.routing.$mode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        state.permissions.$listenAccess
            .combineLatest(state.permissions.$accessibilityAccess)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(makeStatusItem())
        menu.addItem(.separator())

        let sendA = NSMenuItem(title: "Send “a” to iPhone", action: #selector(sendA(_:)),
                                  keyEquivalent: "")
        sendA.target = self
        sendA.isEnabled = state.canSendA
        menu.addItem(sendA)

        menu.addItem(.separator())

        let advertise = NSMenuItem(title: toggleTitle, action: #selector(toggleAdvertising(_:)),
                                     keyEquivalent: "")
        advertise.target = self
        menu.addItem(advertise)

        let restart = NSMenuItem(title: "重新广播", action: #selector(restart(_:)), keyEquivalent: "")
        restart.target = self
        menu.addItem(restart)

        menu.addItem(.separator())

        let modeItem = NSMenuItem(title: "输入模式", action: nil, keyEquivalent: "")
        let modeMenu = NSMenu()
        for mode in RoutingMode.allCases {
            let item = NSMenuItem(
                title: "\(mode == state.routing.mode ? "✓ " : "")\(mode.title)",
                action: #selector(setRoutingMode(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode.rawValue
            item.toolTip = mode.detail
            modeMenu.addItem(item)
        }
        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        let permissions = NSMenuItem(
            title: state.permissions.canSuppressKeyboard ? "输入权限：已授予" : "配置输入监控权限…",
            action: #selector(requestPermissions(_:)),
            keyEquivalent: ""
        )
        permissions.target = self
        menu.addItem(permissions)

        menu.addItem(.separator())

        let diag = NSMenuItem(title: "诊断信息", action: #selector(showDiagnostics(_:)), keyEquivalent: "")
        diag.target = self
        menu.addItem(diag)

        let export = NSMenuItem(title: "导出诊断 JSON", action: #selector(exportDiagnostics(_:)), keyEquivalent: "")
        export.target = self
        menu.addItem(export)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出 Typephone", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.title = state.statusDot
    }

    private var toggleTitle: String {
        if state.peripheral.isAdvertising || state.peripheral.status == .advertising { return "停止广播" }
        return "开始广播"
    }

    private func makeStatusItem() -> NSMenuItem {
        let item = NSMenuItem(title: "\(state.statusDot)  \(state.statusText)", action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: - Actions

    @objc private func sendA(_ sender: Any?) { state.sendLetterA() }
    @objc private func toggleAdvertising(_ sender: Any?) { state.toggleAdvertising() }
    @objc private func restart(_ sender: Any?) { state.restart() }
    @objc private func showDiagnostics(_ sender: Any?) {
        let caps = state.peripheral.lastLEDReport.contains(.capsLock) ? "ON" : "OFF"
        let msg = """
        状态：\(state.statusText)
        已订阅：\(state.peripheral.isSubscribed ? "是" : "否")
        输入模式：\(state.routing.mode.title)
        键盘监听：\(state.permissions.canCaptureKeyboard ? "已授予" : "缺失")
        辅助功能：\(state.permissions.accessibilityAccess ? "已授予" : "缺失")
        报告队列：\(state.peripheral.queueDepth)
        最近发送报告：\(state.peripheral.lastReportHex.isEmpty ? "(无)" : state.peripheral.lastReportHex)
        iPhone Caps Lock：\(caps)
        """
        let alert = NSAlert()
        alert.messageText = "Typephone 诊断"
        alert.informativeText = msg
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
    @objc private func setRoutingMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = RoutingMode(rawValue: raw) else { return }
        _ = state.setRoutingMode(mode)
    }
    @objc private func requestPermissions(_ sender: Any?) { state.requestPermissions() }
    @objc private func exportDiagnostics(_ sender: Any?) { _ = state.exportDiagnostics() }
    @objc private func quit(_ sender: Any?) {
        state.shutdown()
        NSApp.terminate(nil)
    }
}
