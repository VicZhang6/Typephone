import XCTest
@testable import MacInput

final class HIDReportTests: XCTestCase {
    func testZeroReportHasBootKeyboardSize() {
        XCTAssertEqual(HIDReportBuilder.zero.count, HIDReportDescriptor.inputReportSize)
        XCTAssertTrue(HIDReportBuilder.zero.allSatisfy { $0 == 0 })
    }

    func testKeyboardReportPlacesModifierAndKeys() {
        let report = HIDReportBuilder.keyboardReport(
            modifiers: [.leftShift, .leftGUI],
            keys: [.a, .enter]
        )

        XCTAssertEqual(Array(report), [0x0A, 0x00, 0x04, 0x28, 0x00, 0x00, 0x00, 0x00])
    }

    func testKeyboardReportCapsAtSixKeys() {
        let report = HIDReportBuilder.keyboardReport(
            keys: [.a, .b, .c, .d, .e, .f, .g]
        )

        XCTAssertEqual(Array(report.dropFirst(2)), [0x04, 0x05, 0x06, 0x07, 0x08, 0x09])
    }

    func testConsumerEjectReportAndRelease() {
        XCTAssertEqual(Array(HIDConsumerReportBuilder.report(.eject)), [0xB8, 0x00])
        XCTAssertEqual(Array(HIDConsumerReportBuilder.zero), [0x00, 0x00])
    }

    func testDescriptorDeclaresKeyboardAndConsumerReportIDs() {
        let bytes = HIDReportDescriptor.bytes
        let reportIDs = zip(bytes, bytes.dropFirst())
            .filter { $0.0 == 0x85 }
            .map(\.1)
        XCTAssertTrue(reportIDs.contains(0x01))
        XCTAssertTrue(reportIDs.contains(0x02))
    }
}
