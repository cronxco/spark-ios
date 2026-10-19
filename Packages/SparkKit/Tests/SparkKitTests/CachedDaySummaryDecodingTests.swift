import Foundation
import Testing
@testable import SparkKit

struct CachedDaySummaryDecodingTests {
    @Test func readsDatesWrittenAsNumbers() throws {
        let json = """
        {"date":"2026-10-17","timezone":"Europe/London","sync_status":{},"sections":{},"anomalies":[{"id":"a1","metric":"m","detected_at":782000000.5}]}
        """
        let row = CachedDaySummary(date: "2026-10-17", timezone: "Europe/London", payload: Data(json.utf8))
        let summary = try row.decoded()
        #expect(summary.anomalies.first?.detectedAt == Date(timeIntervalSinceReferenceDate: 782000000.5))
    }

    @Test func readsISO8601Dates() throws {
        let json = """
        {"date":"2026-10-17","timezone":"Europe/London","sync_status":{},"sections":{},"anomalies":[{"id":"a1","metric":"m","detected_at":"2026-10-17T08:00:00Z"}]}
        """
        let row = CachedDaySummary(date: "2026-10-17", timezone: "Europe/London", payload: Data(json.utf8))
        #expect(try row.decoded().anomalies.first?.detectedAt == ISO8601DateFormatter().date(from: "2026-10-17T08:00:00Z"))
    }
}
