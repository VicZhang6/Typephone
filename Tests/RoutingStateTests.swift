import XCTest
@testable import MacInput

final class RoutingStateTests: XCTestCase {
    func testHeldHostKeyPassesThroughUntilRelease() {
        var passthrough = HostKeyPassthrough()
        passthrough.begin(with: [55])

        XCTAssertTrue(passthrough.shouldPassThrough(keyCode: 55, isPressed: true))
        XCTAssertTrue(passthrough.shouldPassThrough(keyCode: 55, isPressed: false))
        XCTAssertFalse(passthrough.shouldPassThrough(keyCode: 55, isPressed: false))
    }

    func testNewKeyIsNotPassedThrough() {
        var passthrough = HostKeyPassthrough()
        passthrough.begin(with: [55])

        XCTAssertFalse(passthrough.shouldPassThrough(keyCode: 0, isPressed: true))
    }
}
