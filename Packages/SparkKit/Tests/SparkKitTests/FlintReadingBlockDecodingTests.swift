import Foundation
import Testing
@testable import SparkKit

/// A reading pick's link and length live on the block's own columns server-side
/// and are serialised alongside its content. Without them the client is back to
/// recovering both from prose.
@Suite("Flint reading block decoding")
struct FlintReadingBlockDecodingTests {
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test("decodes url and minutes on a reading pick")
    func decodesReadingPick() throws {
        let json = """
        {
          "id": "block-1",
          "block_type": "flint_reading_pick",
          "title": "Reversing UK mobile rail tickets",
          "content": "You are on the Paddington leg today.",
          "url": "https://eta.st/2023/01/31/rail-tickets.html",
          "minutes": 15
        }
        """.data(using: .utf8)!

        let block = try Self.decoder.decode(FlintDigestBlock.self, from: json)

        #expect(block.url == "https://eta.st/2023/01/31/rail-tickets.html")
        #expect(block.minutes == 15)
        #expect(block.isQuestion == false)
    }

    @Test("a block without them decodes with both nil")
    func decodesWithoutOptionalFields() throws {
        let json = """
        {"id": "block-2", "block_type": "flint_editorial_note", "title": "Run notes", "content": "Ran fine."}
        """.data(using: .utf8)!

        let block = try Self.decoder.decode(FlintDigestBlock.self, from: json)

        #expect(block.url == nil)
        #expect(block.minutes == nil)
    }

    @Test("decodes referenced event ids on a news block")
    func decodesNewsReferences() throws {
        let json = """
        {
          "id": "block-3",
          "block_type": "flint_news",
          "title": "Saudi pipeline closure",
          "content": "The Economist reports the pipeline closed.",
          "referenced_event_ids": ["event-1", "event-2"]
        }
        """.data(using: .utf8)!

        let block = try Self.decoder.decode(FlintDigestBlock.self, from: json)

        #expect(block.blockType == "flint_news")
        #expect(block.title == "Saudi pipeline closure")
    }

    @Test("decodes structured news fields")
    func structuredNews() throws {
        let json = Data("""
        {
          "id": "story-1",
          "block_type": "flint_news",
          "title": "Rates hold",
          "content": "Legacy fallback.",
          "news": {
            "summary": "The Bank held rates.",
            "sources": [
              {"publication": "The Economist", "position": "Focused on inflation."},
              {"publication": "POLITICO", "position": "Focused on the vote split."}
            ],
            "why_it_matters": "Mortgage pricing may remain stable.",
            "what_to_watch": "The next inflation release."
          }
        }
        """.utf8)

        let block = try Self.decoder.decode(FlintDigestBlock.self, from: json)

        #expect(block.news?.summary == "The Bank held rates.")
        #expect(block.news?.sources.map(\.publication) == ["The Economist", "POLITICO"])
        #expect(block.news?.whyItMatters == "Mortgage pricing may remain stable.")
        #expect(block.news?.whatToWatch == "The next inflation release.")
    }

    @Test("decodes key points, a disagreement and linked sources")
    func keyPointsAndLinkedSources() throws {
        let json = Data("""
        {
          "id": "story-1",
          "block_type": "flint_news",
          "title": "Trump rejects Iran's seven-day ceasefire",
          "content": "Iran offered a seven-day pause; Trump turned it down.",
          "news": {
            "key_points": ["Hormuz would have reopened on day seven.", "The NYT puts the frozen assets at $12bn."],
            "contested": "The Guardian and the NYT differ on strikes after the midterms.",
            "sources": [
              {"publication": "The Economist, World in Brief", "position": "Reported the rejection.", "origin": "feed", "event_id": "evt-1"},
              {"publication": "The New York Times", "position": "Set out the terms.", "origin": "research", "url": "https://www.nytimes.com/2026/09/26/us/politics/trump-iran-hormuz-strait.html"}
            ],
            "what_to_watch": "Iran's formal response through mediators."
          }
        }
        """.utf8)

        let block = try Self.decoder.decode(FlintDigestBlock.self, from: json)
        let news = try #require(block.news)

        #expect(news.summary == nil)
        #expect(news.keyPoints?.count == 2)
        #expect(news.contested == "The Guardian and the NYT differ on strikes after the midterms.")
        #expect(news.sources[0].eventId == "evt-1")
        #expect(news.sources[0].origin == .feed)
        #expect(news.sources[0].isResearch == false)
        #expect(news.sources[1].url == "https://www.nytimes.com/2026/09/26/us/politics/trump-iran-hormuz-strait.html")
        #expect(news.sources[1].isResearch)
    }

    @Test("an unknown source origin does not cost the story")
    func unknownOrigin() throws {
        let json = Data("""
        {"publication": "Wire", "position": "Filed first.", "origin": "wire", "url": "https://example.com/story"}
        """.utf8)

        let source = try Self.decoder.decode(FlintNewsSource.self, from: json)

        #expect(source.origin == nil)
        #expect(source.isResearch)
    }
}
