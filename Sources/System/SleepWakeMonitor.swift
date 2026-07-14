import AppKit

@MainActor
final class SleepWakeMonitor {
    var onWillSleep: (() -> Void)?
    var onDidWake: (() -> Void)?

    private var observers: [NSObjectProtocol] = []
    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.notificationCenter = notificationCenter
        observers.append(notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onWillSleep?() }
        })

        observers.append(notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onDidWake?() }
        })
    }

    func stop() {
        observers.forEach(notificationCenter.removeObserver)
        observers.removeAll()
    }
}
