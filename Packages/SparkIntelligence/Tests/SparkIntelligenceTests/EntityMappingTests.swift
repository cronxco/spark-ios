import Foundation
import Testing
@testable import SparkIntelligence
import SparkKit

@Suite("Entity mappings")
struct EntityMappingTests {
    @Test("Event maps display name, summary, and keyword tags")
    func eventMapping() {
        let event = Event(
            id: "evt_1",
            time: Date(timeIntervalSince1970: 1_700_000_000),
            service: "github",
            domain: "code",
            action: "push_commit",
            displayName: "Pushed 3 commits",
            displayValue: "3 commits to main",
            tags: []
        )
        let entity = EventEntity(model: event)

        #expect(entity.id == "evt_1")
        #expect(entity.title == "Pushed 3 commits")
        #expect(entity.summary == "3 commits to main")
        #expect(entity.tags == ["github", "code", "push_commit"])
        #expect(entity.timestamp == event.time)
    }

    @Test("Event without display name derives a humanized title")
    func eventDerivedTitle() {
        let event = Event(
            id: "evt_2",
            time: nil,
            service: "oura",
            domain: "sleep_session",
            action: "record_sleep"
        )
        let entity = EventEntity(model: event)
        #expect(entity.title == "Record Sleep Sleep Session")
        // Falls back to the capitalized service when no value/tldr is present.
        #expect(entity.summary == "Oura")
    }

    @Test("Metric maps identifier as id and formats latest value")
    func metricMapping() {
        let metric = Metric(
            id: "m_1",
            identifier: "oura.sleep_score",
            displayName: "Sleep Score",
            service: "oura",
            action: "sleep_score",
            unit: "pts",
            eventCount: 30,
            mean: 82.4,
            lastEventAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let entity = MetricEntity(model: metric)

        #expect(entity.id == "oura.sleep_score")
        #expect(entity.displayName == "Sleep Score")
        #expect(entity.latestValueDescription == "82.4 pts")
        #expect(entity.keywords == ["oura", "sleep_score"])
    }

    @Test("Place maps coordinates and falls back to type for category")
    func placeMapping() {
        let place = Place(
            id: "p_1",
            title: "Home",
            type: "residence",
            latitude: 51.5,
            longitude: -0.12,
            address: "1 Example Street",
            category: nil
        )
        let entity = PlaceEntity(model: place)

        #expect(entity.name == "Home")
        #expect(entity.address == "1 Example Street")
        #expect(entity.category == "residence")
        #expect(entity.latitude == 51.5)
        #expect(entity.longitude == -0.12)
    }

    @Test("Anomaly summary prefers display name then metric")
    func anomalyMapping() {
        let withName = Anomaly(id: "a_1", metric: "oura.sleep_score", displayName: "Sleep dipped", direction: "down")
        #expect(AnomalyEntity(model: withName).summary == "Sleep dipped")

        let withoutName = Anomaly(id: "a_2", metric: "monzo.spend_daily")
        #expect(AnomalyEntity(model: withoutName).summary == "Unusual reading for monzo.spend_daily")
        #expect(AnomalyEntity(model: withoutName).keywords.contains("anomaly"))
    }

    @Test("Integration uses service slug as routable id")
    func integrationMapping() {
        let integration = Integration(id: "i_1", service: "monzo", name: "Monzo", status: "connected")
        let entity = IntegrationEntity(model: integration)
        #expect(entity.id == "monzo")
        #expect(entity.service == "monzo")
        #expect(entity.status == "connected")
    }

    @Test("Empty/whitespace strings collapse to nil")
    func nonEmptyHelper() {
        #expect("   ".nonEmpty == nil)
        #expect("".nonEmpty == nil)
        #expect("  hi ".nonEmpty == "hi")
    }
}
