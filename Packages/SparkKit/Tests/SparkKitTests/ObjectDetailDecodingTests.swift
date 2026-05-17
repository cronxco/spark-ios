import Foundation
import Testing
@testable import SparkKit

@Suite("ObjectDetail decoding")
struct ObjectDetailDecodingTests {
    @Test("decodes flat object detail payload")
    func decodesFlatObjectDetailPayload() throws {
        let json = """
        {
          "id": "obj_1",
          "concept": "bookmark",
          "type": "fetch_webpage",
          "title": "AI Is African Intelligence",
          "time": "2026-05-03T08:45:11+00:00",
          "content": "# Heading\\n\\nFull article body",
          "url": "https://www.404media.co/story",
          "media_url": "https://cdn.example.com/image.jpeg",
          "recent_events": [
            {
              "id": "evt_1",
              "time": "2026-05-03T08:45:26+00:00",
              "service": "fetch",
              "domain": "knowledge",
              "action": "bookmarked"
            }
          ]
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot parse date"
            )
        }

        let detail = try decoder.decode(ObjectDetail.self, from: Data(json.utf8))
        #expect(detail.id == "obj_1")
        #expect(detail.object.content == "# Heading\n\nFull article body")
        #expect(detail.object.url == "https://www.404media.co/story")
        #expect(detail.recentEvents.count == 1)
        #expect(detail.relatedObjects.isEmpty)
        #expect(detail.tags.isEmpty)
    }
}
