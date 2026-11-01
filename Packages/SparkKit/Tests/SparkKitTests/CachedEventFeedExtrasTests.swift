import Foundation
import Testing

@testable import SparkKit

@Suite("Feed extras on events")
struct CachedEventFeedExtrasTests {
    private let feedJSON = """
    {
        "id": "e1",
        "time": "2026-11-01T03:10:00Z",
        "service": "receipt",
        "domain": "money",
        "action": "had_receipt_from",
        "integration": { "id": "i1", "name": "Receipts", "service": "receipt" },
        "block_refs": [
            { "id": "b1", "block_type": "tax_summary", "title": "Tax Summary", "display_value": "$1.20" },
            { "id": "b2", "block_type": "line_item", "title": "callisto (s-1vcpu-1gb)" }
        ],
        "block_refs_total": 4
    }
    """

    private func decodeEvent(_ json: String) throws -> Event {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Event.self, from: Data(json.utf8))
    }

    private func cached() -> CachedEvent {
        CachedEvent(id: "e1", time: nil, service: "receipt", domain: "money", action: "had_receipt_from")
    }

    @Test("the feed's integration and block pills decode")
    func decodesFeedExtras() throws {
        let event = try decodeEvent(feedJSON)
        #expect(event.integration?.name == "Receipts")
        #expect(event.blockRefs?.map(\.title) == ["Tax Summary", "callisto (s-1vcpu-1gb)"])
        #expect(event.blockRefs?.first?.displayValue == "$1.20")
        #expect(event.blockRefs?.last?.displayValue == nil)
        #expect(event.blockRefsTotal == 4)
    }

    @Test("an event without them decodes as before")
    func decodesWithoutExtras() throws {
        let event = try decodeEvent("""
        { "id": "e1", "service": "monzo", "domain": "money", "action": "card_payment_to" }
        """)
        #expect(event.integration == nil)
        #expect(event.blockRefs == nil)
        #expect(event.blockRefsTotal == nil)
    }

    @Test("block pills survive the cache")
    func blockRefsRoundTrip() throws {
        let row = cached()
        row.applyFeedExtras(from: try decodeEvent(feedJSON))
        #expect(row.integrationName == "Receipts")
        #expect(row.decodedBlockRefs.map(\.id) == ["b1", "b2"])
        #expect(row.blockRefsTotal == 4)
    }

    @Test("a payload without them keeps what the feed cached")
    func keepsExtrasFromAnEarlierFeed() throws {
        let row = cached()
        row.applyFeedExtras(from: try decodeEvent(feedJSON))
        row.applyFeedExtras(from: Event(id: "e1", time: nil, service: "receipt", domain: "money", action: "had_receipt_from"))
        #expect(row.integrationName == "Receipts")
        #expect(row.decodedBlockRefs.count == 2)
    }

    @Test("an empty or unreadable store reads as no pills")
    func noPills() {
        let row = cached()
        #expect(row.decodedBlockRefs.isEmpty)
        row.blockRefsData = Data("not json".utf8)
        #expect(row.decodedBlockRefs.isEmpty)
    }
}
