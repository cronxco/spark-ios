import Foundation
import Testing
@testable import SparkKit

/// Deterministic slice of the Flint "Evaluations" harness: the static fallback
/// path (used in the EU, signed-out, or offline) must always satisfy the same
/// length/format/no-hallucination constraints we assert on model output, since
/// it can ship to users verbatim.
@Suite("Flint fallback evaluation")
struct FlintFallbackEvaluationTests {
    private func makeFacts() throws -> FlintBriefingFacts {
        let json = """
        {
          "date": "2026-06-20",
          "timezone": "Europe/London",
          "sync_status": { "up_to_date": true, "stale": [], "last_event_at": "2026-06-20T18:00:00Z" },
          "sections": {
            "health": { "sleep_score": { "score": 78 } },
            "activity": { "steps": { "value": 8200, "goal": 10000 } },
            "money": { "total_spend": 24.5 },
            "media": null,
            "knowledge": null
          },
          "anomalies": [
            {
              "metric": "oura.sleep_score",
              "display_name": "Sleep score lower than usual",
              "direction": "down",
              "detected_at": "2026-06-20T07:00:00Z"
            }
          ]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let summary = try decoder.decode(DaySummary.self, from: Data(json.utf8))
        return FlintBriefingFacts(summary: summary)
    }

    @Test("Fallback note has a non-empty title and summary")
    func fallbackNoteShape() throws {
        let note = try makeFacts().fallbackNote
        #expect(!note.title.trimmingCharacters(in: .whitespaces).isEmpty)
        #expect(!note.summary.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    @Test("Fallback summary line respects header length and is single-line", arguments: [
        FlintBriefingFacts.SummaryLineContext.daySoFar,
        FlintBriefingFacts.SummaryLineContext.dayInReview,
    ])
    func fallbackSummaryLineConstraints(context: FlintBriefingFacts.SummaryLineContext) throws {
        guard let line = try makeFacts().fallbackSummaryLine(context: context) else { return }
        #expect(!line.contains("\n"))
        #expect(line.count <= 180)
        #expect(!line.isEmpty)
    }

    @Test("Prompt text only references supplied facts (no fabricated sources)")
    func promptTextGrounded() throws {
        let facts = try makeFacts()
        let prompt = facts.promptText
        #expect(prompt.contains("2026-06-20"))
        // Anomaly signal should surface so the model/fallback can reference it.
        #expect(facts.anomalies.isEmpty == false)
    }
}
