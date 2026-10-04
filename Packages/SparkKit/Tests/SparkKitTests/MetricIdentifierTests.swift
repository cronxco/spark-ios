import Foundation
import Testing
@testable import SparkKit

@Suite("Metric identifiers")
struct MetricIdentifierTests {
    @Test("builds direct identifier from event service and action")
    func buildsDirectIdentifierFromEvent() {
        let event = Event(
            id: "evt_sleep",
            time: nil,
            service: "oura",
            domain: "health",
            action: "sleep_score"
        )

        #expect(MetricIdentifier.from(event: event) == "oura.sleep_score")
    }

    @Test("splits exact two-part metric identifiers")
    func splitsExactIdentifier() throws {
        let parts = try #require(MetricIdentifier.split("oura.sleep_score"))

        #expect(parts.service == "oura")
        #expect(parts.action == "sleep_score")
    }

    @Test("rejects ambiguous identifiers")
    func rejectsAmbiguousIdentifiers() {
        #expect(MetricIdentifier.split("sleep_score") == nil)
        #expect(MetricIdentifier.split("oura.") == nil)
        #expect(MetricIdentifier.split(".sleep_score") == nil)
        #expect(MetricIdentifier.split("oura.sleep.score") == nil)
    }

    @Test("rejects unit suffixed metric identifiers")
    func rejectsUnitSuffixedIdentifiers() {
        #expect(!MetricIdentifier.isValid("apple_health.had_stair_speed_up.m/s"))
        #expect(!MetricIdentifier.isValid("apple_health.had_physical_effort.kcal/hr·kg"))
    }

    @Test("accepts service action metric identifiers")
    func acceptsServiceActionIdentifiers() {
        #expect(MetricIdentifier.isValid("apple_health.had_stair_speed_up"))
        #expect(MetricIdentifier.isValid("apple_health.had_physical_effort"))
    }
}
