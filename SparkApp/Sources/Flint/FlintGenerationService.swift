import Foundation
import SparkKit

#if canImport(FoundationModels)
import FoundationModels

@Generable
private struct GeneratedFlintDailyNote {
    var title: String
    var summary: String
    var highlights: [String]
    var watchouts: [String]
    var suggestedActions: [String]

    var note: FlintDailyNote {
        FlintDailyNote(
            title: title,
            summary: summary,
            highlights: highlights,
            watchouts: watchouts,
            suggestedActions: suggestedActions
        )
    }
}

@Generable
private struct GeneratedTodaySummaryLine {
    var text: String
}
#endif

enum FlintGenerationAvailability: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unavailable
}

struct FlintGenerationResult: Sendable, Equatable {
    let note: FlintDailyNote
    let availability: FlintGenerationAvailability
    let usedAppleIntelligence: Bool
}

enum FlintGenerationService {
    static func generateNote(from facts: FlintBriefingFacts) async throws -> FlintGenerationResult {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            let session = LanguageModelSession(
                instructions: """
                You are Flint, Spark's concise daily briefing assistant.
                Use only the supplied Spark briefing facts.
                Do not invent missing data.
                Avoid medical or financial advice; phrase suggestions as lightweight observations.
                Keep the note calm, specific, and useful.
                """
            )
            let response = try await session.respond(
                generating: GeneratedFlintDailyNote.self,
                options: GenerationOptions(maximumResponseTokens: 500)
            ) {
                """
                Create a daily highlight note from these facts.
                Return:
                - a short title
                - a two sentence summary
                - up to four highlights
                - up to three watchouts
                - up to three suggested actions

                Spark briefing facts:
                \(facts.promptText)
                """
            }
            return FlintGenerationResult(
                note: response.content.note,
                availability: .available,
                usedAppleIntelligence: true
            )
        case .unavailable(let reason):
            return FlintGenerationResult(
                note: facts.fallbackNote,
                availability: availability(from: reason),
                usedAppleIntelligence: false
            )
        @unknown default:
            return FlintGenerationResult(
                note: facts.fallbackNote,
                availability: .unavailable,
                usedAppleIntelligence: false
            )
        }
        #else
        return FlintGenerationResult(
            note: facts.fallbackNote,
            availability: .unavailable,
            usedAppleIntelligence: false
        )
        #endif
    }

    static func generateTodaySummaryLine(
        from facts: FlintBriefingFacts,
        context: FlintBriefingFacts.SummaryLineContext
    ) async throws -> FlintGenerationResult {
        let fallback = FlintDailyNote(
            title: "",
            summary: facts.fallbackSummaryLine(context: context) ?? "",
            highlights: [],
            watchouts: [],
            suggestedActions: []
        )

        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            let session = LanguageModelSession(
                instructions: """
                You write the subtitle under the user's Day page heading.
                Use only the supplied briefing facts.
                The app is named Spark, but Spark is not the user and must not be described as doing the user's actions.
                Do not write phrases like "Spark slept", "Spark walked", "Spark spent", or "Spark had".
                Write about the user directly ("You slept...") or use neutral phrasing ("Sleep held steady...").
                Help the user understand the main pattern at a glance.
                Choose the single most useful pattern for the user to notice.
                Prefer anomalies or unusual changes, then activity, sleep, or spend highlights, then a neutral recap.
                Do not invent missing data.
                For today, describe the day so far.
                For past dates, describe the day in review.
                Do not say "today" for past dates.
                Avoid raw metric names, IDs, source names, and jargon.
                Avoid medical or financial advice.
                Avoid percentage changes; they are not meaningful in this header.
                Write one warm, plain-English sentence.
                Keep it ideally 80-140 characters and never more than 180 characters.
                """
            )
            let response = try await session.respond(
                generating: GeneratedTodaySummaryLine.self,
                options: GenerationOptions(maximumResponseTokens: 80)
            ) {
                """
                Write one sentence for the top of the day page.
                Tone: calm, specific, concise, and human.
                Context: \(context == .daySoFar ? "today's day so far" : "the day in review").

                Briefing facts:
                \(facts.promptText)
                """
            }
            return FlintGenerationResult(
                note: FlintDailyNote(
                    title: "",
                    summary: response.content.text,
                    highlights: [],
                    watchouts: [],
                    suggestedActions: []
                ),
                availability: .available,
                usedAppleIntelligence: true
            )
        case .unavailable(let reason):
            return FlintGenerationResult(
                note: fallback,
                availability: availability(from: reason),
                usedAppleIntelligence: false
            )
        @unknown default:
            return FlintGenerationResult(
                note: fallback,
                availability: .unavailable,
                usedAppleIntelligence: false
            )
        }
        #else
        return FlintGenerationResult(
            note: fallback,
            availability: .unavailable,
            usedAppleIntelligence: false
        )
        #endif
    }

    #if canImport(FoundationModels)
    private static func availability(
        from reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> FlintGenerationAvailability {
        switch reason {
        case .deviceNotEligible:
            return .deviceNotEligible
        case .appleIntelligenceNotEnabled:
            return .appleIntelligenceNotEnabled
        case .modelNotReady:
            return .modelNotReady
        @unknown default:
            return .unavailable
        }
    }
    #endif
}
