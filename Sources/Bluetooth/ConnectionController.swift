import Combine
import Foundation

/// Product-level connection facade. BLEPeripheral owns the CoreBluetooth
/// delegate details; this object gives the UI and Electron bridge one place to
/// request start/stop/restart and to observe the desired advertising state.
@MainActor
final class ConnectionController: ObservableObject {
    let peripheral: BLEPeripheral

    @Published private(set) var wantsAdvertising = false

    init(peripheral: BLEPeripheral) {
        self.peripheral = peripheral
    }

    func start() {
        wantsAdvertising = true
        peripheral.startAdvertising()
    }

    func stop() {
        wantsAdvertising = false
        peripheral.stopAdvertising()
    }

    func restart() {
        wantsAdvertising = true
        peripheral.stopAdvertising()
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) { [weak self] in
            self?.peripheral.startAdvertising()
        }
    }
}
