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

    @Test("history endpoint uses one inclusive range and supports cursors")
    func historyEndpoint() {
        let endpoint = FlintEndpoint.history(
            from: "2026-08-16",
            to: "2026-09-14",
            cursor: "next-page"
        )

        #expect(endpoint.path == "/flint/digests")
        #expect(endpoint.query.contains(URLQueryItem(name: "from", value: "2026-08-16")))
        #expect(endpoint.query.contains(URLQueryItem(name: "to", value: "2026-09-14")))
        #expect(endpoint.query.contains(URLQueryItem(name: "limit", value: "50")))
        #expect(endpoint.query.contains(URLQueryItem(name: "cursor", value: "next-page")))
        #expect(!endpoint.query.contains(where: { $0.name == "date" || $0.name == "all" }))
    }

    @Test("open questions endpoint requests the canonical feed")
    func questionsEndpoint() {
        let endpoint = FlintEndpoint.questions(cursor: "page-2")

        #expect(endpoint.path == "/flint/questions")
        #expect(endpoint.query.contains(URLQueryItem(name: "status", value: "open")))
        #expect(endpoint.query.contains(URLQueryItem(name: "limit", value: "50")))
        #expect(endpoint.query.contains(URLQueryItem(name: "cursor", value: "page-2")))
    }

    @Test("question action carries concurrency and idempotency headers")
    func questionActionEndpoint() throws {
        let mutationID = UUID(uuidString: "7D16E962-7C8D-4761-AAC0-0A6A2307306B")!
        let endpoint = FlintEndpoint.questionAction(
            blockID: "question-1",
            version: "\"question-v1\"",
            idempotencyKey: mutationID,
            FlintQuestionActionRequest(action: .answer, answer: "Friday", context: "Thursday clashes.")
        )
        let body = try #require(endpoint.body)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])

        #expect(endpoint.path == "/flint/questions/question-1/actions")
        #expect(endpoint.headers["If-Match"] == "\"question-v1\"")
        #expect(endpoint.headers["Idempotency-Key"] == mutationID.uuidString)
        #expect(object["action"] == "answer")
        #expect(object["answer"] == "Friday")
        #expect(object["context"] == "Thursday clashes.")
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

    /// `digest_object_id` is optional on the model, so a payload that omits the
    /// key entirely must still decode. It did not: the optional-string helper
    /// led with `decodeNil(forKey:)`, which throws `keyNotFound` for an absent
    /// key, failing the whole digest. Every other fixture here sends the key —
    /// with a value or an explicit null — which is why nothing caught it, and
    /// why the Up to Speed flow silently lost digest detail for any response
    /// that left it out.
    @Test("digest decodes when digest_object_id is absent entirely")
    func decodesDigestWithoutDigestObjectID() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = """
        {
          "event_id": "digest-a",
          "date": "2026-05-16",
          "period": "morning",
          "title": "Morning Digest",
          "summary": "Start here.",
          "block_count": 1,
          "unanswered_question_count": 1,
          "blocks": [
            {
              "id": "q-1",
              "block_type": "flint_user_question",
              "title": "Sleep Check",
              "question": "Did you sleep well?",
              "answered": false
            }
          ]
        }
        """

        let digest = try decoder.decode(FlintDigest.self, from: Data(json.utf8))

        #expect(digest.digestObjectID == nil)
        #expect(digest.eventID == "digest-a")
        #expect(digest.blocks.count == 1)
        #expect(digest.blocks[0].isQuestion)
        #expect(digest.blocks[0].answered == false)
    }

    @Test("content block decodes entity references with unknown-type fallback")
    func decodesBlockReferences() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = """
        {
          "event_id": "e-1",
          "digest_object_id": null,
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
          "digest_object_id": null,
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

    @Test("history response decodes list-safe summaries and cursor metadata")
    func decodesHistory() throws {
        let json = """
        {
          "data": [{
            "id": "digest-1",
            "local_date": "2026-09-14",
            "period": "morning",
            "kind": "briefing",
            "title": "Morning Digest",
            "summary": "A short summary.",
            "generated_at": "2026-09-14T07:12:03+01:00",
            "updated_at": "2026-09-14T07:12:03+01:00",
            "unanswered_question_count": 1,
            "version": "W/\\\"digest-v1\\\"",
            "freshness": {"state": "fresh", "age_seconds": 8280}
          }],
          "meta": {
            "from": "2026-08-16",
            "to": "2026-09-14",
            "effective_timezone": "Europe/London",
            "account_id": "user-1",
            "next_cursor": "page-2"
          }
        }
        """

        let response = try makeDecoder().decode(FlintDigestHistoryResponse.self, from: Data(json.utf8))

        #expect(response.data.first?.id == "digest-1")
        #expect(response.data.first?.localDate == "2026-09-14")
        #expect(response.data.first?.freshness?.ageSeconds == 8280)
        #expect(response.meta.nextCursor == "page-2")
    }

    @Test("questions response decodes canonical status history and version")
    func decodesQuestions() throws {
        let json = """
        {
          "data": [{
            "id": "question-1",
            "digest_id": "digest-1",
            "source_digest": {"local_date": "2026-09-14", "period": "morning"},
            "status": "open",
            "question": "Should the review move to Friday?",
            "topic": "Quarterly planning",
            "answer_options": ["Yes", "No"],
            "asked_at": "2026-09-14T07:12:03+01:00",
            "effective_answer": null,
            "answer_history": [],
            "version": "\\\"question-v1\\\""
          }],
          "meta": {
            "next_cursor": null,
            "effective_timezone": "Europe/London",
            "account_id": "user-1"
          }
        }
        """

        let response = try makeDecoder().decode(FlintQuestionsResponse.self, from: Data(json.utf8))
        let question = try #require(response.data.first)

        #expect(question.status == .open)
        #expect(question.sourceDigest.period == .morning)
        #expect(question.version == "\"question-v1\"")
        #expect(question.asDigestBlock.answerOptions == ["Yes", "No"])
        #expect(question.asDigestBlock.priority == nil)
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
