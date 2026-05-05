import Foundation
import Testing
@testable import SparkKit

@Suite("EventDetail decoding")
struct EventDetailDecodingTests {
    @Test("knowledge reprocess endpoint posts to knowledge event path")
    func knowledgeReprocessEndpoint() {
        let endpoint = EventsEndpoint.reprocessKnowledgeEvent(id: "evt_article")

        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/knowledge/events/evt_article/reprocess")
        #expect(endpoint.query.isEmpty)
    }

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
        #expect(detail.tags.names == ["news"])
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

    @Test("decodes compact event display metadata")
    func decodesCompactEventDisplayMetadata() throws {
        let json = """
        {
          "id": "evt_1",
          "time": null,
          "service": "monzo",
          "domain": "money",
          "action": "card_payment",
          "display_name": "Card Payment",
          "hidden": false,
          "value": -10.5,
          "display_value": "£10.50",
          "tags": [{ "name": "coffee", "type": "merchant_category" }],
          "blocks_count": 2,
          "tldr": "Coffee at Prufrock.",
          "actor": {
            "id": "acct_1",
            "title": "Monzo",
            "concept": "account",
            "type": "bank_account",
            "media_url": "https://cdn.example.com/monzo.png"
          },
          "target": {
            "id": "merchant_1",
            "title": "Prufrock",
            "concept": "merchant",
            "type": "place",
            "media_url": null
          }
        }
        """

        let event = try JSONDecoder().decode(Event.self, from: Data(json.utf8))

        #expect(event.displayName == "Card Payment")
        #expect(event.hidden == false)
        #expect(event.displayValue == "£10.50")
        #expect(event.value == "-10.5")
        #expect(event.tags.names == ["coffee"])
        #expect(event.tags.first?.type == "merchant_category")
        #expect(event.blocksCount == 2)
        #expect(event.actor?.type == "bank_account")
        #expect(event.actor?.mediaUrl == "https://cdn.example.com/monzo.png")
        #expect(event.target?.type == "place")
    }

    @Test("decodes legacy string tags")
    func decodesLegacyStringTags() throws {
        let json = """
        {
          "event": {
            "id": "evt_tags",
            "time": null,
            "service": "fetch",
            "domain": "knowledge",
            "action": "saved",
            "tags": ["news", "swift"]
          },
          "blocks": [],
          "related": [],
          "tags": ["news", "swift"]
        }
        """

        let detail = try JSONDecoder().decode(EventDetail.self, from: Data(json.utf8))

        #expect(detail.event.tags.names == ["news", "swift"])
        #expect(detail.tags.names == ["news", "swift"])
    }

    @Test("decodes knowledge article summary, content, raw, and takeaway blocks")
    func decodesKnowledgeArticleBlocks() throws {
        let json = """
        {
          "event": {
            "id": "evt_article",
            "time": null,
            "service": "fetch",
            "domain": "knowledge",
            "action": "saved"
          },
          "blocks": [
            {
              "id": "blk_summary",
              "block_type": "fetch_summary_paragraph",
              "title": "Summary",
              "content": "A concise paragraph summary."
            },
            {
              "id": "blk_newsletter_summary",
              "block_type": "newsletter_summary_paragraph",
              "title": "Newsletter Summary",
              "content": "A newsletter style summary."
            },
            {
              "id": "blk_content",
              "block_type": "fetch_content",
              "title": "Article Body",
              "content": "# Heading\\n\\nReadable article body."
            },
            {
              "id": "blk_raw",
              "block_type": "fetch_raw_content",
              "title": "Raw Body",
              "content": "<html>Raw article body</html>"
            },
            {
              "id": "blk_takeaways",
              "block_type": "key_takeaways",
              "title": "Key Takeaways",
              "content": "First takeaway\\nSecond takeaway"
            }
          ],
          "related": [],
          "tags": []
        }
        """

        let detail = try JSONDecoder().decode(EventDetail.self, from: Data(json.utf8))

        #expect(detail.blocks.map(\.id) == [
            "blk_summary",
            "blk_newsletter_summary",
            "blk_content",
            "blk_raw",
            "blk_takeaways",
        ])
        #expect(detail.blocks.map(\.blockType) == [
            "fetch_summary_paragraph",
            "newsletter_summary_paragraph",
            "fetch_content",
            "fetch_raw_content",
            "key_takeaways",
        ])
        #expect(detail.blocks.first?.content == "A concise paragraph summary.")
        #expect(detail.blocks[2].content == "# Heading\n\nReadable article body.")
        #expect(detail.blocks[3].content == "<html>Raw article body</html>")
        #expect(detail.blocks[4].content == "First takeaway\nSecond takeaway")
    }

    @Test("decodes numeric block values from event detail payloads")
    func decodesNumericBlockValues() throws {
        let json = """
        {
          "action": "pot_transfer_to",
          "blocks": [
            {
              "block_type": "pot_transfer",
              "id": "b63b9459-aa79-4fb8-b881-163ab82e2ada",
              "time": null,
              "title": "Pot Transfer",
              "unit": "GBP",
              "value": 2.48
            }
          ],
          "display_name": "Pot Transfer",
          "display_value": "<span class=\\\"text-[0.875em]\\\">£<\\/span>2.48",
          "domain": "money",
          "hidden": false,
          "id": "0c6a0d23-d5ef-497e-b969-58e6d40bb8f6",
          "service": "monzo",
          "tags": [],
          "time": null,
          "unit": "GBP",
          "value": 2.48
        }
        """

        let detail = try JSONDecoder().decode(EventDetail.self, from: Data(json.utf8))

        #expect(detail.event.value == "2.48")
        #expect(detail.blocks.first?.value == "2.48")
        #expect(detail.blocks.first?.unit == "GBP")
    }

    @Test("decodes hidden as suppress from default feed")
    func decodesHiddenAsSuppressFromDefaultFeed() throws {
        let hiddenJSON = """
        {
          "id": "evt_hidden",
          "time": null,
          "service": "monzo",
          "domain": "money",
          "action": "balance_update",
          "display_name": "Balance Update",
          "hidden": true
        }
        """
        let visibleJSON = """
        {
          "id": "evt_visible",
          "time": null,
          "service": "monzo",
          "domain": "money",
          "action": "card_payment",
          "display_name": "Card Payment",
          "hidden": false
        }
        """

        let hidden = try JSONDecoder().decode(Event.self, from: Data(hiddenJSON.utf8))
        let visible = try JSONDecoder().decode(Event.self, from: Data(visibleJSON.utf8))

        #expect(hidden.hidden == true)
        #expect(visible.hidden == false)
    }
}
