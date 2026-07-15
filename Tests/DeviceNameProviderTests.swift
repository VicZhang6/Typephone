import XCTest
@testable import MacInput

final class DeviceNameProviderTests: XCTestCase {
    func testNormalizesComputerNameWhitespace() {
        XCTAssertEqual(DeviceNameProvider.normalized("  Vic’s MacBook  \n"), "Vic’s MacBook")
    }

    func testFallsBackForMissingOrEmptyComputerName() {
        XCTAssertEqual(DeviceNameProvider.normalized(nil), DeviceNameProvider.fallbackName)
        XCTAssertEqual(DeviceNameProvider.normalized(" \n\t "), DeviceNameProvider.fallbackName)
    }
}
