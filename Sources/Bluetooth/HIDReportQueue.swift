import Foundation

struct HIDReportDestination: OptionSet, Sendable {
    let rawValue: UInt8

    static let reportInput = HIDReportDestination(rawValue: 1 << 0)
    static let bootInput = HIDReportDestination(rawValue: 1 << 1)
    static let consumerInput = HIDReportDestination(rawValue: 1 << 2)
}

/// Ordered notification queue with per-characteristic delivery tracking.
/// A report is removed only after every subscribed destination accepts it.
struct HIDReportQueue: Sendable {
    private struct Frame: Sendable {
        let data: Data
        var pending: HIDReportDestination
    }

    private var frames: [Frame] = []

    var count: Int { frames.count }
    var isEmpty: Bool { frames.isEmpty }

    mutating func enqueue(_ data: Data, destinations: HIDReportDestination) {
        guard !destinations.isEmpty else { return }
        frames.append(Frame(data: data, pending: destinations))
    }

    mutating func drain(deliver: (Data, HIDReportDestination) -> Bool) {
        while !frames.isEmpty {
            var frame = frames[0]
            if frame.pending.contains(.reportInput), deliver(frame.data, .reportInput) {
                frame.pending.remove(.reportInput)
            }
            if frame.pending.contains(.bootInput), deliver(frame.data, .bootInput) {
                frame.pending.remove(.bootInput)
            }
            if frame.pending.contains(.consumerInput), deliver(frame.data, .consumerInput) {
                frame.pending.remove(.consumerInput)
            }
            frames[0] = frame
            if !frame.pending.isEmpty { return }
            frames.removeFirst()
        }
    }

    mutating func removeAll(keepingCapacity: Bool = false) {
        frames.removeAll(keepingCapacity: keepingCapacity)
    }
}
