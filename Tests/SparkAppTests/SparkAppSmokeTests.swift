import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("SparkApp smoke")
struct SparkAppSmokeTests {
    @Test func productionEnvironmentPointsAtProductionHost() {
        #expect(APIEnvironment.production.name == "production")
        #expect(APIEnvironment.production.baseURL.host() == "spark.cronx.co")
    }

    @Test func metricBaselineStatusShowsNormalInsideBaseline() throws {
        let status = try #require(MetricBaselineStatus.make(
            event: event(value: "18", unit: "GBP"),
            metric: metric(low: 16, high: 22)
        ))

        #expect(status.state == .normal)
        #expect(status.title == "Normal")
        #expect(status.trailing == "£16-£22")
    }

    @Test func metricBaselineStatusCapsDisplayedNormalRangeAtZero() throws {
        let status = try #require(MetricBaselineStatus.make(
            event: event(value: "2", unit: "GBP"),
            metric: metric(low: -4, high: 8)
        ))

        #expect(status.state == .normal)
        #expect(status.title == "Normal")
        #expect(status.trailing == "£0-£8")
    }

    @Test func metricBaselineStatusShowsHighDeviationOutsideBaseline() throws {
        let status = try #require(MetricBaselineStatus.make(
            event: event(value: "23", unit: "GBP"),
            metric: metric(low: 16, high: 22)
        ))

        #expect(status.state == .high)
        #expect(status.title == "Outside Normal Range")
        #expect(status.trailing == "+5%")
    }

    @Test func metricBaselineStatusShowsLowDeviationOutsideBaseline() throws {
        let status = try #require(MetricBaselineStatus.make(
            event: event(value: "14", unit: "GBP"),
            metric: metric(low: 16, high: 22)
        ))

        #expect(status.state == .low)
        #expect(status.title == "Outside Normal Range")
        #expect(status.trailing == "-13%")
    }

    @Test func metricBaselineStatusHidesWhenBaselineIsMissing() {
        let status = MetricBaselineStatus.make(
            event: event(value: "18", unit: "GBP"),
            metric: metric(low: nil, high: nil)
        )

        #expect(status == nil)
    }

    @Test func metricBaselineStatusUsesMetricIdentifierNotEventUnit() throws {
        let status = try #require(MetricBaselineStatus.make(
            event: event(value: "1.4", unit: "m/s"),
            metric: MetricDetail(
                id: "apple_health.had_stair_speed_up.m/s",
                title: "Stair Speed Up",
                domain: "health",
                unit: "m/s",
                baseline: MetricDetail.Baseline(low: 1, high: 2)
            ),
            metricIdentifier: "apple_health.had_stair_speed_up"
        ))

        #expect(status.metricIdentifier == "apple_health.had_stair_speed_up")
        #expect(!status.metricIdentifier.contains("m/s"))
    }

    @Test func metricAnomalyRowShowsHighValueAndMatchingEvent() throws {
        let date = try #require(Self.dayFormatter.date(from: "2026-05-04"))
        let event = event(value: "23", unit: "GBP", time: date)
        let row = MetricAnomalyRowModel.make(
            anomaly: MetricDetail.AnomalyPoint(id: "a1", date: date, severity: "high", value: 23),
            detail: metric(low: 16, high: 22, series: []),
            recentEvents: [event]
        )

        #expect(row.title == "Above Normal Range")
        #expect(row.trailing == "23 GBP")
        #expect(row.state == .high)
        #expect(row.eventId == "evt_1")
    }

    @Test func metricAnomalyRowShowsLowValueAgainstZeroCappedBaseline() throws {
        let date = try #require(Self.dayFormatter.date(from: "2026-05-04"))
        let row = MetricAnomalyRowModel.make(
            anomaly: MetricDetail.AnomalyPoint(id: "a1", date: date, severity: "high", value: -1),
            detail: metric(low: -4, high: 22, series: []),
            recentEvents: []
        )

        #expect(row.title == "Below Normal Range")
        #expect(row.trailing == "-1 GBP")
        #expect(row.state == .low)
        #expect(row.eventId == nil)
    }

    @Test func metricAnomalyRowFallsBackWithoutBaselineOrValue() throws {
        let date = try #require(Self.dayFormatter.date(from: "2026-05-04"))
        let row = MetricAnomalyRowModel.make(
            anomaly: MetricDetail.AnomalyPoint(id: "a1", date: date, severity: "high", value: nil),
            detail: metric(low: nil, high: nil, series: []),
            recentEvents: []
        )

        #expect(row.title == "Outside Normal Range")
        #expect(row.trailing == nil)
        #expect(row.state == .unknown)
        #expect(row.eventId == nil)
    }

    private func event(value: String, unit: String?, time: Date? = nil) -> Event {
        Event(
            id: "evt_1",
            time: time,
            service: "gocardless",
            domain: "money",
            action: "payment_to",
            value: value,
            unit: unit
        )
    }

    private func metric(low: Double?, high: Double?, series: [MetricDetail.Point] = []) -> MetricDetail {
        MetricDetail(
            id: "gocardless.payment_to",
            title: "Payment To",
            domain: "money",
            unit: "GBP",
            baseline: {
                guard let low, let high else { return nil }
                return MetricDetail.Baseline(low: low, high: high)
            }(),
            series: series
        )
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
