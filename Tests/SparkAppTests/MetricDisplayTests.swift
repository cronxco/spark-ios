import Foundation
import SparkKit
import Testing

@testable import Spark

@Suite("Explore metric display")
struct MetricDisplayTests {
    @Test("drops the action verb and the Apple prefix, in sentence case")
    func titles() {
        #expect(MetricDisplay.title("Had Heart Rate Variability", service: "apple_health") == "Heart rate variability")
        #expect(MetricDisplay.title("Apple Sleeping Wrist Temperature", service: "apple_health") == "Sleeping wrist temperature")
        #expect(MetricDisplay.title("Sleep Score", service: "oura") == "Sleep score")
        #expect(MetricDisplay.title("Vo2 Max", service: "apple_health") == "VO2 max")
        #expect(MetricDisplay.title("SpO2", service: "oura") == "SpO2")
        #expect(MetricDisplay.title("Did Workout", service: "apple_health") == "Workout")
    }

    @Test("both Google Calendar service ids share one name")
    func serviceNames() {
        #expect(MetricDisplay.serviceName("google_calendar") == MetricDisplay.serviceName("google-calendar"))
        #expect(MetricDisplay.serviceName("apple_health") == "Apple Health")
        #expect(MetricDisplay.serviceName("some_new_thing") == "Some new thing")
    }

    @Test("formats values with the unit the reader expects")
    func values() {
        #expect(MetricDisplay.format(86, unit: "percent", action: "had_sleep_score") == .init(text: "86", unit: nil))
        #expect(MetricDisplay.format(95.4, unit: "percent", action: "had_spo2") == .init(text: "95", unit: "%"))
        #expect(MetricDisplay.format(27_960, unit: "seconds") == .init(text: "7h 46m", unit: nil))
        #expect(MetricDisplay.format(77, unit: "count/min") == .init(text: "77", unit: "bpm"))
        #expect(MetricDisplay.format(36.157, unit: "degC") == .init(text: "36.2", unit: "°C"))
        #expect(MetricDisplay.format(12_430, unit: "count", action: "had_step_count") == .init(text: "12,430", unit: "steps"))
        #expect(MetricDisplay.format(0.1, unit: "GBP") == .init(text: "£0.10", unit: nil))
        #expect(MetricDisplay.format(2, unit: "stress_level") == .init(text: "Normal", unit: nil))
    }

    @Test("comparison amounts run the unit on, except word units")
    func amounts() {
        #expect(MetricDisplay.amount(6.4, unit: "count/min") == "6bpm")
        #expect(MetricDisplay.amount(1440, unit: "seconds") == "24m")
        #expect(MetricDisplay.amount(4179, unit: "count", action: "had_step_count") == "4,179 steps")
        #expect(MetricDisplay.amount(3.1, unit: "percent", action: "had_sleep_score") == "3")
    }

    @Test("the arrow's colour follows the metric's polarity")
    func polarity() throws {
        let rhr = try #require(MetricDisplay.comparison(value: 77, mean: 70.58, unit: "count/min", action: "had_resting_heart_rate"))
        #expect(rhr.text == "6bpm above 30d trend")
        #expect(rhr.direction == .up)
        #expect(rhr.isGood == false)

        let spend = try #require(MetricDisplay.comparison(value: 0.1, mean: 33.44, unit: "GBP", action: "card_payment_to"))
        #expect(spend.text == "£33.34 below 30d trend")
        #expect(spend.isGood == true)

        let temperature = try #require(MetricDisplay.comparison(value: 36.16, mean: 35.45, unit: "degC", action: "had_apple_sleeping_wrist_temperature"))
        #expect(temperature.isGood == nil)
    }

    @Test("a difference that rounds away reads as on trend")
    func onTrend() throws {
        let comparison = try #require(MetricDisplay.comparison(value: 82.2, mean: 82.0, unit: "percent", action: "had_sleep_score"))
        #expect(comparison.text == "On 30d trend")
        #expect(comparison.direction == .steady)
    }

    @Test("ordinal levels get no comparison")
    func ordinal() {
        #expect(MetricDisplay.comparison(value: 3, mean: 2.1, unit: "stress_level", action: "had_stress_score") == nil)
    }

    @Test("counts days from the series' UTC dates to the local day")
    func daysAgo() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        let reading = try #require(utc.date(from: DateComponents(year: 2026, month: 10, day: 30)))

        var london = Calendar(identifier: .gregorian)
        london.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let lateEvening = try #require(london.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 30)))

        #expect(MetricDisplay.daysAgo(reading, now: lateEvening, calendar: london) == 1)
        #expect(MetricDisplay.staleness(daysAgo: 1) == "from yesterday")
        #expect(MetricDisplay.staleness(daysAgo: 0) == nil)
        #expect(MetricDisplay.dayLabel(daysAgo: 3) == "3 days ago")
    }
}
