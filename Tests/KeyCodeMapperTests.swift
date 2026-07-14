import XCTest
@testable import MacInput

final class KeyCodeMapperTests: XCTestCase {
    func testLetterAndPunctuationMapping() {
        XCTAssertEqual(KeyCodeMapper.hidKey(for: 0), .a)
        XCTAssertEqual(KeyCodeMapper.hidKey(for: 49), .space)
        XCTAssertEqual(KeyCodeMapper.hidKey(for: 36), .enter)
        XCTAssertEqual(KeyCodeMapper.hidKey(for: 123), .leftArrow)
    }

    func testModifierMapping() {
        XCTAssertEqual(KeyCodeMapper.modifier(for: 59), .leftControl)
        XCTAssertEqual(KeyCodeMapper.modifier(for: 55), .leftGUI)
        XCTAssertTrue(KeyCodeMapper.isCapsLock(57))
    }
}
