import Foundation
import Testing
@testable import SparkKit

@Suite("DeepLink")
struct DeepLinkTests {
    @Test("parses OAuth callback URL")
    func authCallback() throws {
        let url = try #require(URL(string: "spark://auth/callback?code=abc123&state=xyz789"))
        let link = DeepLink.parse(url)
        #expect(link == .authCallback(code: "abc123", state: "xyz789"))
    }

    @Test("OAuth callback missing params returns nil")
    func authCallbackMissingParams() throws {
        let url = try #require(URL(string: "spark://auth/callback?code=abc"))
        #expect(DeepLink.parse(url) == nil)
    }

    @Test("parses /today with no date")
    func todayWithoutDate() throws {
        let url = try #require(URL(string: "https://spark.cronx.co/today"))
        if case .today(let date) = DeepLink.parse(url) {
            #expect(date == nil)
        } else {
            Issue.record("expected .today")
        }
    }

    @Test("parses /day/YYYY-MM-DD")
    func dayWithDate() throws {
        let url = try #require(URL(string: "https://spark.cronx.co/day/2026-03-14"))
        let link = DeepLink.parse(url)
        if case .day(let date) = link {
            let components = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
            #expect(components.year == 2026)
            #expect(components.month == 3)
            #expect(components.day == 14)
        } else {
            Issue.record("expected .day got \(String(describing: link))")
        }
    }

    @Test("parses /event/:id")
    func event() throws {
        let url = try #require(URL(string: "https://spark.cronx.co/event/evt_abc"))
        #expect(DeepLink.parse(url) == .event(id: "evt_abc"))
    }

    @Test("unknown host returns nil")
    func unknownHost() throws {
        let url = try #require(URL(string: "https://example.com/today"))
        #expect(DeepLink.parse(url) == nil)
    }

    @Test("unknown path returns nil")
    func unknownPath() throws {
        let url = try #require(URL(string: "https://spark.cronx.co/totally-unknown"))
        #expect(DeepLink.parse(url) == nil)
    }

    @Test("parses /events/:id (plural)")
    func eventsPlural() throws {
        let url = try #require(URL(string: "https://spark.cronx.co/events/evt_xyz"))
        #expect(DeepLink.parse(url) == .event(id: "evt_xyz"))
    }

    @Test("parses /objects/:id")
    func object() throws {
        let url = try #require(URL(string: "https://spark.cronx.co/objects/obj_123"))
        #expect(DeepLink.parse(url) == .object(id: "obj_123"))
    }

    @Test("parses /blocks/:id")
    func block() throws {
        let url = try #require(URL(string: "https://spark.cronx.co/blocks/blk_abc"))
        #expect(DeepLink.parse(url) == .block(id: "blk_abc"))
    }

    @Test("parses /metrics/:identifier")
    func metric() throws {
        let url = try #require(URL(string: "https://spark.cronx.co/metrics/sleep_score"))
        #expect(DeepLink.parse(url) == .metric(identifier: "sleep_score"))
    }

    @Test("parses /places/:id")
    func place() throws {
        let url = try #require(URL(string: "https://spark.cronx.co/places/plc_42"))
        #expect(DeepLink.parse(url) == .place(id: "plc_42"))
    }

    @Test("parses /integrations/:service/details")
    func integration() throws {
        let url = try #require(URL(string: "https://spark.cronx.co/integrations/monzo/details"))
        #expect(DeepLink.parse(url) == .integration(service: "monzo"))
    }

    @Test("/integrations without /details suffix returns nil")
    func integrationWithoutDetails() throws {
        let url = try #require(URL(string: "https://spark.cronx.co/integrations/monzo"))
        #expect(DeepLink.parse(url) == nil)
    }
}
