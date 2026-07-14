import Foundation
import OSLog

@MainActor
final class DiagnosticsRecorder {
    struct Entry: Codable {
        let timestamp: Date
        let level: String
        let message: String
    }

    private let logger = Logger(subsystem: "com.viczhang.typephone", category: "diagnostics")
    private var entries: [Entry] = []
    private let maxEntries = 500

    func record(_ message: String, level: String = "info") {
        entries.append(Entry(timestamp: Date(), level: level, message: message))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        switch level {
        case "error": logger.error("\(message, privacy: .public)")
        case "warning": logger.warning("\(message, privacy: .public)")
        default: logger.info("\(message, privacy: .public)")
        }
    }

    func export(snapshot: [String: Any]) -> URL? {
        let payload: [String: Any] = [
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "snapshot": snapshot,
            "events": entries.map {
                [
                    "timestamp": ISO8601DateFormatter().string(from: $0.timestamp),
                    "level": $0.level,
                    "message": $0.message
                ]
            }
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "Typephone-Diagnostics-\(formatter.string(from: Date())).json"
        let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            record("诊断信息已导出到 \(url.path)")
            return url
        } catch {
            record("诊断信息导出失败：\(error.localizedDescription)", level: "error")
            return nil
        }
    }

    var eventCount: Int { entries.count }
}
