import Foundation
import FoundationModels
import SparkKit

// iOS 27 baseline: FoundationModels is always available, so the previous
// `#if canImport(FoundationModels)` compile-time fallbacks are gone. Runtime
// availability fallbacks (PCC → on-device → static) live in FlintModelProvider.

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

enum FlintGenerationAvailability: Error, Equatable, Sendable {
    case privateCloudCompute
    case onDevice
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unavailable

    /// Whether the result came from a real model (PCC or on-device) rather than
    /// the static fallback.
    var isModelBacked: Bool {
        self == .privateCloudCompute || self == .onDevice
    }
}

/// Lightweight usage record for telemetry / PCC budgeting.
struct FlintGenerationUsage: Sendable, Equatable {
    let tier: FlintGenerationTier
    /// Token budget requested for the response (upper bound).
    let responseTokenBudget: Int
    let inputTokens: Int
    let cachedInputTokens: Int
    let outputTokens: Int
    let reasoningTokens: Int
    let totalTokens: Int
}

struct FlintGenerationResult: Sendable, Equatable {
    let note: FlintDailyNote
    let availability: FlintGenerationAvailability
    let usedAppleIntelligence: Bool
    let tier: FlintGenerationTier
    let usage: FlintGenerationUsage?
}

enum FlintGenerationService {
    // MARK: - Daily note (digest) — deep reasoning + live-data tools

    static func generateNote(from facts: FlintBriefingFacts) async throws -> FlintGenerationResult {
        let instructions = """
        You are Flint, Spark's concise daily briefing assistant.
        Use the supplied Spark briefing facts; you may call the provided tools to
        fetch additional Spark data when it improves accuracy.
        Do not invent missing data.
        Avoid medical or financial advice; phrase suggestions as lightweight observations.
        Keep the note calm, specific, and useful.
        """

        let resolved = FlintModelProvider.resolve(
            reasoning: .deep,
            instructions: instructions,
            tools: FlintTools.digestTools
        )

        switch resolved {
        case .failure(let availability):
            return staticResult(note: facts.fallbackNote, availability: availability)
        case .success(let model):
            let response = try await model.session.respond(
                generating: GeneratedFlintDailyNote.self,
                options: FlintModelProvider.generationOptions(for: .deep),
                contextOptions: FlintModelProvider.contextOptions(for: .deep),
                metadata: [
                    "spark.generation.path": "digest",
                    "spark.generation.tier": model.tier.rawValue,
                ]
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
            return modelResult(
                note: response.content.note,
                tier: model.tier,
                availability: model.availability,
                reasoning: .deep,
                usage: response.usage
            )
        }
    }

    // MARK: - Today summary line — light reasoning, no tools

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

        let instructions = """
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

        let resolved = FlintModelProvider.resolve(reasoning: .light, instructions: instructions)

        switch resolved {
        case .failure(let availability):
            return staticResult(note: fallback, availability: availability)
        case .success(let model):
            let response = try await model.session.respond(
                generating: GeneratedTodaySummaryLine.self,
                options: FlintModelProvider.generationOptions(for: .light),
                contextOptions: FlintModelProvider.contextOptions(for: .light),
                metadata: [
                    "spark.generation.path": "summary_line",
                    "spark.generation.tier": model.tier.rawValue,
                ]
            ) {
                """
                Write one sentence for the top of the day page.
                Tone: calm, specific, concise, and human.
                Context: \(context == .daySoFar ? "today's day so far" : "the day in review").

                Briefing facts:
                \(facts.promptText)
                """
            }
            let note = FlintDailyNote(
                title: "",
                summary: response.content.text,
                highlights: [],
                watchouts: [],
                suggestedActions: []
            )
            return modelResult(
                note: note,
                tier: model.tier,
                availability: model.availability,
                reasoning: .light,
                usage: response.usage
            )
        }
    }

    // MARK: - Result builders

    private static func modelResult(
        note: FlintDailyNote,
        tier: FlintGenerationTier,
        availability: FlintGenerationAvailability,
        reasoning: FlintReasoning,
        usage: LanguageModelSession.Usage
    ) -> FlintGenerationResult {
        FlintGenerationResult(
            note: note,
            availability: availability,
            usedAppleIntelligence: true,
            tier: tier,
            usage: FlintGenerationUsage(
                tier: tier,
                responseTokenBudget: reasoning.maximumResponseTokens,
                inputTokens: usage.input.totalTokenCount,
                cachedInputTokens: usage.input.cachedTokenCount,
                outputTokens: usage.output.totalTokenCount,
                reasoningTokens: usage.output.reasoningTokenCount,
                totalTokens: usage.totalTokenCount
            )
        )
    }

    private static func staticResult(
        note: FlintDailyNote,
        availability: FlintGenerationAvailability
    ) -> FlintGenerationResult {
        FlintGenerationResult(
            note: note,
            availability: availability,
            usedAppleIntelligence: false,
            tier: .staticFallback,
            usage: nil
        )
    }
}
