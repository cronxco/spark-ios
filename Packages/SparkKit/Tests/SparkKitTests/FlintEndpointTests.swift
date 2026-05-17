import Foundation
import Testing
@testable import SparkKit

@Suite("Flint endpoint")
struct FlintEndpointTests {
    @Test("all digests endpoint includes date period and all flag")
    func allDigestsEndpoint() {
        let endpoint = FlintEndpoint.digests(date: "2026-05-16", period: .morning)

        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/flint/digests")
        #expect(endpoint.query.contains(URLQueryItem(name: "date", value: "2026-05-16")))
        #expect(endpoint.query.contains(URLQueryItem(name: "period", value: "morning")))
        #expect(endpoint.query.contains(URLQueryItem(name: "all", value: "true")))
    }

    @Test("latest endpoint omits period and all flag by default")
    func latestDigestEndpoint() {
        let endpoint = FlintEndpoint.latestDigest(date: "2026-05-16")

        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/flint/digests")
        #expect(endpoint.query == [URLQueryItem(name: "date", value: "2026-05-16")])
    }

    @Test("answer endpoint encodes snake case body")
    func answerEndpoint() throws {
        let endpoint = FlintEndpoint.answerQuestion(
            blockID: "block-1",
            FlintQuestionAnswerRequest(answer: "Yes", answerNote: "Felt good")
        )
        let body = try #require(endpoint.body)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: String]

        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/flint/questions/block-1/answer")
        #expect(endpoint.contentType == "application/json")
        #expect(object?["answer"] == "Yes")
        #expect(object?["answer_note"] == "Felt good")
    }

    @Test("digest decodes question and content blocks")
    func decodesDigest() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = """
        {
          "event_id": 42,
          "digest_object_id": "digest-1",
          "date": "2026-05-16",
          "period": "morning",
          "title": "Morning Digest",
          "summary": "Start here.",
          "created_at": "2026-05-16T08:30:00Z",
          "block_count": 2,
          "unanswered_question_count": 1,
          "blocks": [
            {
              "id": "q-1",
              "block_type": "flint_user_question",
              "title": "Sleep Check",
              "time": "2026-05-16T08:30:00Z",
              "question": "Did you sleep well?",
              "topic": "health",
              "priority": "high",
              "answer_options": ["Yes", "No"],
              "answer": null,
              "answer_note": null,
              "answered_at": null,
              "answered": false
            },
            {
              "id": "note-1",
              "block_type": "flint_editorial_note",
              "title": "Context",
              "time": "2026-05-16T08:31:00Z",
              "content": "**Hydrate** early."
            }
          ]
        }
        """

        let digest = try decoder.decode(FlintDigest.self, from: Data(json.utf8))

        #expect(digest.eventID == "42")
        #expect(digest.period == .morning)
        #expect(digest.unansweredQuestionCount == 1)
        #expect(digest.blocks[0].isQuestion)
        #expect(digest.blocks[0].priority == .high)
        #expect(digest.blocks[0].answerOptions == ["Yes", "No"])
        #expect(digest.blocks[1].blockType == "flint_editorial_note")
        #expect(digest.blocks[1].content == "**Hydrate** early.")
    }

    @Test("content block decodes entity references with unknown-type fallback")
    func decodesBlockReferences() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = """
        {
          "event_id": "e-1",
          "date": "2026-05-16",
          "period": "morning",
          "title": "Morning Digest",
          "created_at": "2026-05-16T08:30:00Z",
          "block_count": 1,
          "unanswered_question_count": 0,
          "blocks": [
            {
              "id": "ins-1",
              "block_type": "flint_health_insight",
              "title": "Health",
              "content": "You did a [Morning Walk](https://spark.cronx.co/event/abc) today.",
              "references": [
                {"type": "event", "id": "abc", "title": "Morning Walk", "service": "Strava", "domain": "health"},
                {"type": "starship", "id": "xyz", "title": "Future Thing"}
              ]
            }
          ]
        }
        """

        let digest = try decoder.decode(FlintDigest.self, from: Data(json.utf8))
        let refs = try #require(digest.blocks[0].references)

        #expect(refs.count == 2)
        #expect(refs[0].type == .event)
        #expect(refs[0].id == "abc")
        #expect(refs[0].title == "Morning Walk")
        #expect(refs[0].service == "Strava")
        #expect(refs[0].domain == "health")
        #expect(refs[1].type == .unknown)
        #expect(refs[1].service == nil)
    }

    @Test("content block without references decodes to nil")
    func decodesBlockWithoutReferences() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = """
        {
          "event_id": "e-1",
          "date": "2026-05-16",
          "title": "Digest",
          "created_at": "2026-05-16T08:30:00Z",
          "block_count": 1,
          "unanswered_question_count": 0,
          "blocks": [
            {"id": "n-1", "block_type": "flint_editorial_note", "title": "Note", "content": "Plain."}
          ]
        }
        """

        let digest = try decoder.decode(FlintDigest.self, from: Data(json.utf8))
        #expect(digest.blocks[0].references == nil)
    }

    @Test("all response decodes digest list")
    func decodesDigestList() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = """
        {
          "date": "2026-05-16",
          "count": 1,
          "digests": [
            {
              "event_id": "event-1",
              "digest_object_id": null,
              "date": "2026-05-16",
              "period": "evening",
              "title": "Evening Digest",
              "summary": null,
              "created_at": "2026-05-16T20:00:00Z",
              "block_count": 0,
              "unanswered_question_count": 0,
              "blocks": []
            }
          ]
        }
        """

        let response = try decoder.decode(FlintDigestListResponse.self, from: Data(json.utf8))

        #expect(response.count == 1)
        #expect(response.digests.first?.period == .evening)
    }
}
