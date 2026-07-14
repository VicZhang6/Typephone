import XCTest
@testable import MacInput

final class KeyboardStateTests: XCTestCase {
    func testStateBuildsStableSortedReport() {
        var state = KeyboardState()
        state.press(.z)
        state.press(.a)
        state.setModifier(.leftControl, pressed: true)

        XCTAssertEqual(Array(state.report()), [0x01, 0x00, 0x04, 0x1D, 0x00, 0x00, 0x00, 0x00])
    }

    func testReleaseAndClearRemoveAllPressedKeys() {
        var state = KeyboardState()
        state.press(.a)
        state.press(.b)
        state.release(.a)
        XCTAssertEqual(Array(state.report()), [0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00])

        state.clear()
        XCTAssertTrue(state.isEmpty)
        XCTAssertEqual(state.report(), HIDReportBuilder.zero)
    }
}
