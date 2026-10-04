import Foundation
import Testing
@testable import SparkKit

@Suite("Feed endpoints")
struct FeedEndpointTests {
    @Test("feed endpoint carries date filter")
    func feedEndpointDateFilter() {
        let endpoint = FeedEndpoint.feed(cursor: "cur_1", limit: 50, domain: "money", date: "2026-05-04")

        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/feed")
        #expect(endpoint.query.first { $0.name == "cursor" }?.value == "cur_1")
        #expect(endpoint.query.first { $0.name == "limit" }?.value == "50")
        #expect(endpoint.query.first { $0.name == "domain" }?.value == "money")
        #expect(endpoint.query.first { $0.name == "date" }?.value == "2026-05-04")
    }
}
