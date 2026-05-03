import Foundation
import Testing
@testable import SparkKit

@Suite("EventDetail decoding")
struct EventDetailDecodingTests {
    @Test("decodes wrapped detail payload")
    func decodesWrappedPayload() throws {
        let json = """
        {
          "event": {
            "id": "evt_wrapped",
            "time": null,
            "service": "calendar",
            "domain": "knowledge",
            "action": "read"
          },
          "blocks": [],
          "related": [],
          "tags": ["news"],
          "summary_ai": "Summary text"
        }
        """

        let detail = try JSONDecoder().decode(EventDetail.self, from: Data(json.utf8))
        #expect(detail.id == "evt_wrapped")
        #expect(detail.event.service == "calendar")
        #expect(detail.tags == ["news"])
        #expect(detail.aiSummary == "Summary text")
    }

    @Test("decodes flat event payload with defaults")
    func decodesFlatPayload() throws {
        let json = """
        {
          "id": "evt_flat",
          "time": null,
          "service": "google_news",
          "domain": "knowledge",
          "action": "published",
          "actor": {
            "id": "src_1",
            "title": "The Times",
            "concept": "publisher"
          },
          "target": {
            "id": "story_1",
            "title": "Aurora Watch",
            "concept": "article"
          }
        }
        """

        let detail = try JSONDecoder().decode(EventDetail.self, from: Data(json.utf8))
        #expect(detail.id == "evt_flat")
        #expect(detail.blocks.isEmpty)
        #expect(detail.related.isEmpty)
        #expect(detail.tags.isEmpty)
        #expect(detail.actor?.title == "The Times")
        #expect(detail.target?.title == "Aurora Watch")
    }
}
