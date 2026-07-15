import XCTest
@testable import MacInput

final class HIDSubscriptionStateTests: XCTestCase {
    func testAnySubscriptionMeansCentralIsConnected() {
        XCTAssertTrue(HIDSubscriptionState.isConnected([.batteryLevel]))
        XCTAssertTrue(HIDSubscriptionState.isConnected([.consumerInputReport]))
        XCTAssertFalse(HIDSubscriptionState.isConnected([]))
    }

    func testOnlyKeyboardInputSubscriptionIsReadyForTyping() {
        XCTAssertFalse(HIDSubscriptionState.isKeyboardReady([.batteryLevel]))
        XCTAssertFalse(HIDSubscriptionState.isKeyboardReady([.consumerInputReport]))
        XCTAssertTrue(HIDSubscriptionState.isKeyboardReady([.inputReport]))
        XCTAssertTrue(HIDSubscriptionState.isKeyboardReady([.bootKeyboardInput]))
    }
}
