import Foundation
import Testing
@testable import SparkKit

@Suite("FlintTopics decoding")
struct FlintTopicsDecodingTests {
    @Test("decodes a full topics list response")
    func decodesFullResponse() throws {
        let json = """
        {
          "data": [
            {
              "id": "6f1c9b1a-2f2d-4c9e-9c3a-2a6a1b2c3d4e",
              "title": "US–Iran escalation",
              "content": null,
              "kind": "strategic",
              "status": "active",
              "first_seen_at": "2026-09-05T00:00:00+00:00",
              "last_touched_at": "2026-09-10T07:01:28+00:00",
              "next_review_at": null,
              "origin": "digest_inference"
            },
            {
              "id": "9e8d7c6b-5a4f-4e3d-8c2b-1a0b9c8d7e6f",
              "title": "Edinburgh trip with Dan",
              "content": "Loosely planned for spring.",
              "kind": "tactical",
              "status": "dormant",
              "first_seen_at": "2026-06-01T00:00:00+00:00",
              "last_touched_at": "2026-06-15T09:00:00+00:00",
              "next_review_at": "2026-10-01T00:00:00+00:00",
              "origin": "digest_inference"
            }
          ]
        }
        """

        let response = try makeDecoder().decode(FlintTopicsResponse.self, from: Data(json.utf8))

        #expect(response.data.count == 2)

        let escalation = response.data[0]
        #expect(escalation.title == "US–Iran escalation")
        #expect(escalation.kind == .strategic)
        #expect(escalation.status == .active)
        #expect(escalation.status?.isActive == true)
        #expect(escalation.content == nil)
        #expect(escalation.nextReviewAt == nil)

        let edinburgh = response.data[1]
        #expect(edinburgh.kind == .tactical)
        #expect(edinburgh.status == .dormant)
        #expect(edinburgh.status?.isActive == false)
        #expect(edinburgh.content == "Loosely planned for spring.")
        #expect(edinburgh.nextReviewAt != nil)
    }

    @Test("decodes an empty list")
    func decodesEmptyList() throws {
        let response = try makeDecoder().decode(FlintTopicsResponse.self, from: Data(#"{"data": []}"#.utf8))
        #expect(response.data.isEmpty)
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }
}
