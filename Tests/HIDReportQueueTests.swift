import XCTest
@testable import MacInput

final class HIDReportQueueTests: XCTestCase {
    func testBackpressureRetriesOnlyPendingDestination() {
        var queue = HIDReportQueue()
        queue.enqueue(Data([1]), destinations: [.reportInput, .bootInput])
        queue.enqueue(Data([2]), destinations: [.reportInput, .bootInput])

        var calls: [(UInt8, HIDReportDestination)] = []
        var rejectBootOnce = true
        queue.drain { data, destination in
            calls.append((data[0], destination))
            if destination == .bootInput && rejectBootOnce {
                rejectBootOnce = false
                return false
            }
            return true
        }

        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(calls.count, 2)

        queue.drain { data, destination in
            calls.append((data[0], destination))
            return true
        }

        XCTAssertTrue(queue.isEmpty)
        XCTAssertEqual(calls.map(\.0), [1, 1, 1, 2, 2])
        XCTAssertEqual(calls[2].1, .bootInput)
    }

    func testFiveThousandReportsKeepOrder() {
        var queue = HIDReportQueue()
        for index in 0..<5_000 {
            queue.enqueue(Data([UInt8(index % 251)]), destinations: [.reportInput])
        }

        var delivered: [UInt8] = []
        queue.drain { data, _ in
            delivered.append(data[0])
            return true
        }

        XCTAssertTrue(queue.isEmpty)
        XCTAssertEqual(delivered.count, 5_000)
        let expected = (0..<251).map { UInt8($0) }
        XCTAssertEqual(Array(delivered.prefix(251)), expected)
    }
}
