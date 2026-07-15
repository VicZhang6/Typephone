import SwiftUI
import AppKit
import Darwin

private struct ElectronControlConfiguration: Decodable {
    let port: UInt16
    let authToken: String

    static func readFromParentPipe() -> ElectronControlConfiguration? {
        let handle = FileHandle(fileDescriptor: 3, closeOnDealloc: true)
        let data = handle.readDataToEndOfFile()
        guard
            let configuration = try? JSONDecoder().decode(Self.self, from: data),
            configuration.port >= 1024,
            configuration.authToken.count == 64,
            configuration.authToken.allSatisfy(\.isHexDigit)
        else {
            return nil
        }
        return configuration
    }
}

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
    private var parentMonitor: DispatchSourceTimer?
    private var expectedParentPID: pid_t?

    private var isElectronHelper: Bool {
        CommandLine.arguments.contains("--electron-helper")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if isElectronHelper {
            guard let configuration = ElectronControlConfiguration.readFromParentPipe() else {
                NSLog("Missing or invalid Electron control configuration")
                NSApp.terminate(nil)
                return
            }
            controlServer = ControlServer(
                state: state,
                port: configuration.port,
                authToken: configuration.authToken
            )
            controlServer?.start()
            startParentMonitor()
        } else {
            menuBarController = MenuBarController(state: state)
        }
        // Begin advertising automatically on launch so the iPhone can pair
        // without any extra clicks.
        state.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        parentMonitor?.cancel()
        parentMonitor = nil
        state.shutdown()
        controlServer?.stop()
    }

    private func startParentMonitor() {
        let parentPID = getppid()
        guard parentPID > 1 else {
            parentDidExit()
            return
        }
        expectedParentPID = parentPID

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(250), repeating: .milliseconds(250))
        timer.setEventHandler { [weak self] in
            guard let self, let expectedParentPID else { return }
            if getppid() != expectedParentPID {
                parentDidExit()
            }
        }
        timer.resume()
        parentMonitor = timer
    }

    private func parentDidExit() {
        parentMonitor?.cancel()
        parentMonitor = nil
        state.shutdown()
        controlServer?.stop()
        NSApp.terminate(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            exit(0)
        }
    }
}
