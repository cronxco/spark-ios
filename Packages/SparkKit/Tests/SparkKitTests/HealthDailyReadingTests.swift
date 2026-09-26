import Foundation
import Testing
@testable import SparkKit

@Suite("Health daily readings")
struct HealthDailyReadingTests {
    private var london: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }

    private func instant(_ iso: String) throws -> Date {
        try Date(iso, strategy: .iso8601)
    }

    @Test("a reading is filed under its local day, not the UTC date of its start")
    func localDay() throws {
        // 00:30 BST on 26 Sep is still 25 Sep in UTC.
        let reading = try HealthSample.dailyReading(
            type: "HKQuantityTypeIdentifierStepCount",
            day: try instant("2026-09-25T23:30:00Z"),
            value: 8064,
            unit: "count",
            source: "HealthKit",
            asOf: try instant("2026-09-26T19:00:00Z"),
            calendar: london
        )

        #expect(reading.metadata?["date"] == "2026-09-26")
        #expect(reading.externalId == "HKQuantityTypeIdentifierStepCount:2026-09-26")
        let londonMidnight = try instant("2026-09-25T23:00:00Z")
        #expect(reading.start == londonMidnight)
        #expect(reading.value == 8064)
    }

    @Test("as_of records when the reading was taken, and ends a still-running day")
    func asOfForToday() throws {
        let asOf = try instant("2026-09-26T19:00:00Z")
        let reading = HealthSample.dailyReading(
            type: "HKQuantityTypeIdentifierStepCount",
            day: asOf,
            value: 8064,
            unit: "count",
            source: "HealthKit",
            asOf: asOf,
            calendar: london
        )

        #expect(reading.metadata?["as_of"] == "2026-09-26T19:00:00Z")
        #expect(reading.end == asOf)
    }

    @Test("a past day ends at its local midnight however late it is re-read")
    func pastDayEnd() throws {
        let reading = try HealthSample.dailyReading(
            type: "HKQuantityTypeIdentifierHeartRate",
            day: try instant("2026-09-24T12:00:00Z"),
            value: 62,
            unit: "count/min",
            source: "HealthKit",
            asOf: try instant("2026-09-26T08:00:00Z"),
            calendar: london
        )

        #expect(reading.metadata?["date"] == "2026-09-24")
        let endOfDay = try instant("2026-09-24T23:00:00Z")
        #expect(reading.end == endOfDay)
        #expect(reading.metadata?["as_of"] == "2026-09-26T08:00:00Z")
    }

    @Test("the reading encodes the metadata the server reads")
    func encodesMetadata() throws {
        let reading = try HealthSample.dailyReading(
            type: "HKQuantityTypeIdentifierStepCount",
            day: try instant("2026-09-26T12:00:00Z"),
            value: 77,
            unit: "count",
            source: "HealthKit",
            asOf: try instant("2026-09-26T12:00:00Z"),
            calendar: london
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(HealthSampleBatch(samples: [reading]))) as? [String: Any]
        )
        let sample = try #require((json["samples"] as? [[String: Any]])?.first)
        let metadata = try #require(sample["metadata"] as? [String: String])

        #expect(sample["external_id"] as? String == "HKQuantityTypeIdentifierStepCount:2026-09-26")
        #expect(metadata == ["date": "2026-09-26", "as_of": "2026-09-26T12:00:00Z"])
    }

    @Test("uploads are split into batches the server accepts")
    func batching() {
        let samples = (0 ..< 1201).map { index in
            HealthSample(
                externalId: "sample-\(index)",
                type: "HKQuantityTypeIdentifierStepCount",
                start: Date(timeIntervalSince1970: 0),
                end: Date(timeIntervalSince1970: 0),
                value: Double(index),
                unit: "count",
                source: "HealthKit"
            )
        }

        let batches = HealthSampleBatch.batches(of: samples)

        #expect(batches.map(\.samples.count) == [500, 500, 201])
        #expect(batches.flatMap(\.samples).map(\.externalId) == samples.map(\.externalId))
        #expect(HealthSampleBatch.batches(of: []).isEmpty)
    }
}
