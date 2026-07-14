import Foundation
import Network
import AppKit

/// Small loopback-only control plane used by the Electron shell.
///
/// The native process remains the owner of CoreBluetooth. Electron talks to
/// this server with newline-delimited JSON so the UI can be replaced without
/// moving BLE/HID work into JavaScript.
@MainActor
final class ControlServer {
    static let port: UInt16 = 43821

    private weak var state: AppState?
    private var listener: NWListener?

    init(state: AppState) {
        self.state = state
    }

    func start() {
        guard listener == nil else { return }

        do {
            let parameters = NWParameters.tcp
            parameters.requiredInterfaceType = .loopback
            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: Self.port)!)
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.accept(connection)
                }
            }
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    NSLog("Control server failed: %{public}@", error.localizedDescription)
                }
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            NSLog("Unable to start control server: %{public}@", error.localizedDescription)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func accept(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                NSLog("Control connection failed: %{public}@", error.localizedDescription)
            }
        }
        connection.start(queue: .main)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    NSLog("Control connection receive failed: %{public}@", error.localizedDescription)
                    connection.cancel()
                    return
                }

                var pending = buffer
                if let data { pending.append(data) }

                while let newline = pending.firstIndex(of: 0x0A) {
                    let line = pending[..<newline]
                    pending.removeSubrange(...newline)
                    handle(line: String(decoding: line, as: UTF8.self), on: connection)
                }

                if isComplete {
                    connection.cancel()
                } else {
                    receive(on: connection, buffer: pending)
                }
            }
        }
    }

    private func handle(line: String, on connection: NWConnection) {
        guard
            let data = line.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let command = object["command"] as? String
        else {
            send(["type": "error", "message": "Invalid command"], on: connection)
            return
        }

        switch command {
        case "getStatus":
            sendStatus(on: connection)
        case "startAdvertising":
            state?.peripheral.startAdvertising()
            sendStatus(on: connection)
        case "stopAdvertising":
            state?.peripheral.stopAdvertising()
            sendStatus(on: connection)
        case "toggleAdvertising":
            state?.toggleAdvertising()
            sendStatus(on: connection)
        case "sendA":
            state?.sendLetterA()
            sendStatus(on: connection)
        case "restart":
            state?.restart()
            sendStatus(on: connection)
        case "setRoutingMode":
            guard let rawMode = object["mode"] as? String,
                  let mode = RoutingMode(rawValue: rawMode) else {
                send(["type": "error", "message": "Invalid routing mode"], on: connection)
                return
            }
            guard let state else {
                send(["type": "error", "message": "Native state unavailable"], on: connection)
                return
            }
            _ = state.setRoutingMode(mode)
            sendStatus(on: connection)
        case "requestPermissions":
            state?.requestPermissions()
            sendStatus(on: connection)
        case "openAccessibilitySettings":
            state?.openAccessibilitySettings()
            sendStatus(on: connection)
        case "openInputMonitoringSettings":
            state?.openInputMonitoringSettings()
            sendStatus(on: connection)
        case "exportDiagnostics":
            guard let state else {
                send(["type": "error", "message": "Native state unavailable"], on: connection)
                return
            }
            var response = state.statusPayload
            response["exportedPath"] = state.exportDiagnostics()?.path ?? NSNull()
            send(response, on: connection)
        case "shutdown":
            sendStatus(on: connection)
            DispatchQueue.main.async { NSApp.terminate(nil) }
        default:
            send(["type": "error", "message": "Unknown command: \(command)"], on: connection)
        }
    }

    private func sendStatus(on connection: NWConnection) {
        guard let state else {
            send(["type": "error", "message": "Native state unavailable"], on: connection)
            return
        }
        send(state.statusPayload, on: connection)
    }

    private func send(_ payload: [String: Any], on connection: NWConnection) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var framed = data
        framed.append(0x0A)
        connection.send(content: framed, completion: .contentProcessed { error in
            if let error {
                NSLog("Control connection send failed: %{public}@", error.localizedDescription)
            }
        })
    }
}
