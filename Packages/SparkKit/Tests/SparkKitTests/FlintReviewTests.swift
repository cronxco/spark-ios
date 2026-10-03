import Foundation
import Testing
@testable import SparkKit

@Suite("Flint review")
struct FlintReviewTests {
    @Test("decodes a receipt suggestion with candidates and an automatic link")
    func decodesQueue() throws {
        let json = """
        {
          "data": [
            {
              "id": "r-1",
              "kind": "receipt_suggestion",
              "title": "Coffee House receipt",
              "summary": "Spark found possible transactions for this receipt but was not sure enough to link one.",
              "confidence": 0.7,
              "created_at": "2026-10-03T08:00:00+00:00",
              "subject": {"id": "r-1", "title": "Coffee House receipt", "amount": 4.5, "unit": "GBP", "time": "2026-10-03T08:00:00+00:00", "service": "receipt"},
              "candidates": [
                {"id": "t-1", "title": "Coffee House", "amount": 4.5, "unit": "GBP", "time": "2026-10-03T08:05:00+00:00", "service": "monzo", "confidence": 0.7}
              ],
              "actions": ["confirm", "dismiss"]
            },
            {
              "id": "l-1",
              "kind": "auto_link",
              "title": "Pot",
              "summary": "Spark linked these transactions by itself.",
              "confidence": 0.91,
              "created_at": "2026-10-02T08:00:00+00:00",
              "relationship_type": "transferred_to",
              "subject": {"id": "t-2", "title": "Pot", "amount": 10, "unit": "GBP", "time": null, "service": "monzo"},
              "linked": {"id": "t-3", "title": "Savings", "amount": 10, "unit": "GBP", "time": null, "service": "gocardless"},
              "actions": ["keep", "undo"]
            }
          ]
        }
        """

        let response = try makeDecoder().decode(FlintReviewResponse.self, from: Data(json.utf8))

        #expect(response.data.count == 2)
        #expect(response.data[0].kind == .receiptSuggestion)
        #expect(response.data[0].candidates.first?.id == "t-1")
        #expect(response.data[0].candidates.first?.confidence == 0.7)
        #expect(response.data[0].actions == [.confirm, .dismiss])
        #expect(response.data[1].kind == .autoLink)
        #expect(response.data[1].linked?.title == "Savings")
        #expect(response.data[1].candidates.isEmpty)
        #expect(response.data[1].subject.amount == 10)
    }

    @Test("an unknown kind skips only that item and unknown actions are dropped")
    func decodesUnknownValuesLeniently() throws {
        let json = """
        {
          "data": [
            {
              "id": "x-1",
              "kind": "something_new",
              "title": "New",
              "summary": "A kind this build doesn't know.",
              "subject": {"id": "x-1"},
              "actions": ["confirm"]
            },
            {
              "id": "l-1",
              "kind": "auto_link",
              "title": "Pot",
              "summary": "Spark linked these transactions by itself.",
              "subject": {"id": "t-2"},
              "actions": ["keep", "snooze", "undo"]
            }
          ]
        }
        """

        let response = try makeDecoder().decode(FlintReviewResponse.self, from: Data(json.utf8))

        #expect(response.data.map(\.id) == ["l-1"])
        #expect(response.data[0].actions == [.keep, .undo])
    }

    @Test("action endpoint posts the action and chosen transaction")
    func actionEndpoint() throws {
        let endpoint = FlintEndpoint.reviewAction(
            kind: .receiptSuggestion,
            id: "r-1",
            FlintReviewActionRequest(action: .confirm, transactionID: "t-1")
        )

        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/flint/review/receipt_suggestion/r-1")
        let body = try #require(endpoint.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(object == ["action": "confirm", "transaction_id": "t-1"])
    }

    @Test("queue endpoint skips the cache")
    func queueEndpoint() {
        let endpoint = FlintEndpoint.review()

        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/flint/review")
        #expect(endpoint.headers["Cache-Control"] == "no-cache")
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
