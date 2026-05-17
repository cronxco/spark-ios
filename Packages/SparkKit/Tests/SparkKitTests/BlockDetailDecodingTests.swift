import Foundation
import Testing
@testable import SparkKit

@Suite("BlockDetail decoding")
struct BlockDetailDecodingTests {
    @Test("decodes schema compact block payload")
    func decodesSchemaCompactBlockPayload() throws {
        let json = """
        {
          "block_type": "fetch_summary_paragraph",
          "content": "Thousands of young African men have signed up to fight in Moscow's war against Ukraine.",
          "id": "3ffff171-d586-4f5f-977e-a8482a8995d0",
          "time": "2026-05-04T15:01:08+00:00",
          "title": "Paragraph Summary"
        }
        """

        let detail = try makeDecoder().decode(BlockDetail.self, from: Data(json.utf8))

        #expect(detail.id == "3ffff171-d586-4f5f-977e-a8482a8995d0")
        #expect(detail.block.blockType == "fetch_summary_paragraph")
        #expect(detail.block.title == "Paragraph Summary")
        #expect(detail.block.content?.hasPrefix("Thousands of young African men") == true)
        #expect(detail.event == nil)
        #expect(detail.aiSummary == nil)
    }

    @Test("decodes wrapped block detail payload")
    func decodesWrappedBlockDetailPayload() throws {
        let json = """
        {
          "block": {
            "id": "block_wrapped",
            "block_type": "note",
            "title": "Wrapped Block",
            "time": null,
            "content": "Wrapped content"
          },
          "summary_ai": "Summary text"
        }
        """

        let detail = try makeDecoder().decode(BlockDetail.self, from: Data(json.utf8))

        #expect(detail.id == "block_wrapped")
        #expect(detail.block.content == "Wrapped content")
        #expect(detail.aiSummary == "Summary text")
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
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot parse date"
            )
        }
        return decoder
    }
}
