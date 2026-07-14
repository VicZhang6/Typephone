import SwiftUI
import AppKit

/// Native menu-bar host. `LSUIElement = true` keeps it out of the Dock.
@main
struct MacInputApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var menuBarController: MenuBarController?
    private var controlServer: ControlServer?

    private var isElectronHelper: Bool {
        CommandLine.arguments.contains("--electron-helper")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !isElectronHelper {
            menuBarController = MenuBarController(state: state)
        }
        controlServer = ControlServer(state: state)
        controlServer?.start()
        // Begin advertising automatically on launch so the iPhone can pair
        // without any extra clicks.
        state.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.shutdown()
        controlServer?.stop()
    }
}
