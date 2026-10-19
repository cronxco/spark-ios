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
    /// Why a request that wanted PCC was served by a lower tier, e.g.
    /// `quota_limit_reached` or `network_failure`. `nil` when PCC served the
    /// request or the lower tier was the first choice.
    var pccFallbackReason: String?
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

        return try await generate(
            reasoning: .deep,
            instructions: instructions,
            tools: FlintTools.digestTools,
            fallbackNote: facts.fallbackNote,
            path: "digest"
        ) { model in
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

    // MARK: - Today summary — moderate reasoning, day and baseline tools

    static func generateTodaySummaryLine(
        from facts: FlintBriefingFacts,
        context: FlintBriefingFacts.SummaryLineContext
    ) async throws -> FlintGenerationResult {
        // No model, no line: the Day summary never shows a raw fact line.
        let fallback = FlintDailyNote(
            title: "",
            summary: "",
            highlights: [],
            watchouts: [],
            suggestedActions: []
        )

        let instructions = """
        You write the short summary at the top of the user's Day page.
        Use the supplied briefing facts. You may call getDaySummary for the previous day to compare, and getMetricBaseline for a normal range.
        The app is named Spark, but Spark is not the user and must not be described as doing the user's actions.
        Write about the user directly ("You slept...") or use neutral phrasing ("Sleep held steady...").
        Write two or three short sentences, never more than 320 characters in total.
        Lead with the single biggest change from the previous day or from normal. Give both values and the gap, for example "47 minutes less than the night before" or "from 96 to 79".
        Then say what it adds up to in plain terms, for example "a less settled night despite plenty of sleep" or "recovery looks steady".
        Mention anything unusual plainly and by when it happened ("heart rate spiked around 1am"). Never write "anomaly", "streak", "resilience level" or "reading".
        Say durations naturally ("7 hours 49 minutes") and times on the 24-hour clock.
        Skip money, media and knowledge unless something there is clearly notable.
        Only state numbers that appear in the facts or tool results. Never invent data and never repeat a fact.
        Do not give medical or financial advice. No greetings, no filler, no exclamation marks.
        For today, describe the day so far. For past dates, describe the day in review and do not say "today".
        If nothing is worth saying, return empty text.
        Style example, not to be reused for its facts: "You slept 7 hours 49 minutes, 47 minutes less than the night before, and sleep score fell from 96 to 79. Readiness held at 82, but efficiency was 73%, so the night was less settled than the hours suggest."
        """

        return try await generate(
            reasoning: .moderate,
            instructions: instructions,
            tools: FlintTools.summaryTools,
            fallbackNote: fallback,
            path: "summary_line"
        ) { model in
            let response = try await model.session.respond(
                generating: GeneratedTodaySummaryLine.self,
                options: FlintModelProvider.generationOptions(for: .moderate),
                contextOptions: FlintModelProvider.contextOptions(for: .moderate),
                metadata: [
                    "spark.generation.path": "summary_line",
                    "spark.generation.tier": model.tier.rawValue,
                ]
            ) {
                """
                Write the summary for the top of the day page.
                Tone: calm, specific, concise, and human.
                Context: \(context == .daySoFar ? "today's day so far" : "the day in review").

                Spark briefing facts:
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
                reasoning: .moderate,
                usage: response.usage
            )
        }
    }

    // MARK: - Tier fallback

    /// Runs `respond` against the best available tier. A PCC runtime failure
    /// (quota used up, no network, service down, rate limit, timeout) re-resolves
    /// with PCC excluded so the request is served on-device; a model-manager
    /// runtime failure is retried on the same tier. Anything that still fails
    /// ends at the static fallback.
    private static func generate(
        reasoning: FlintReasoning,
        instructions: String,
        tools: [any Tool],
        fallbackNote: FlintDailyNote,
        path: String,
        respond: (FlintResolvedSession) async throws -> FlintGenerationResult
    ) async throws -> FlintGenerationResult {
        var allowPrivateCloudCompute = true
        var fallbackReason: String?

        for _ in 0..<3 {
            let resolved = FlintModelProvider.resolve(
                reasoning: reasoning,
                instructions: instructions,
                tools: tools,
                allowPrivateCloudCompute: allowPrivateCloudCompute
            )

            switch resolved {
            case .failure(let availability):
                return staticResult(note: fallbackNote, availability: availability, pccFallbackReason: fallbackReason)
            case .success(let model):
                let reason = fallbackReason ?? model.pccSkipReason?.rawValue
                do {
                    var result = try await respond(model)
                    result.pccFallbackReason = reason
                    SparkObservability.captureFlintGeneration(path: path, result: result)
                    return result
                } catch where model.tier == .privateCloudCompute && error.privateCloudComputeFallbackReason != nil {
                    fallbackReason = error.privateCloudComputeFallbackReason
                    allowPrivateCloudCompute = false
                } catch where error.isFoundationModelManagerRuntimeFailure {
                    continue
                }
            }
        }

        return staticResult(note: fallbackNote, availability: .modelNotReady, pccFallbackReason: fallbackReason)
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
        availability: FlintGenerationAvailability,
        pccFallbackReason: String? = nil
    ) -> FlintGenerationResult {
        FlintGenerationResult(
            note: note,
            availability: availability,
            usedAppleIntelligence: false,
            tier: .staticFallback,
            usage: nil,
            pccFallbackReason: pccFallbackReason
        )
    }
}

extension Error {
    /// A short telemetry reason when this error means the PCC tier could not
    /// serve the request but a lower tier still can; `nil` for everything else
    /// (cancellation, guardrails, programmer errors), which must not be retried
    /// on-device.
    var privateCloudComputeFallbackReason: String? {
        if self is PrivateCloudComputeLanguageModel.Error {
            return "pcc_error"
        }
        if let error = self as? LanguageModelError {
            if case .rateLimited = error { return "rate_limited" }
            if case .timeout = error { return "timeout" }
        }
        return nil
    }
}

private extension Error {
    var isFoundationModelManagerRuntimeFailure: Bool {
        let nsError = self as NSError
        return nsError.containsNSError(
            domain: "ModelManagerServices.ModelManagerError",
            code: 1046
        )
    }
}

private extension NSError {
    func containsNSError(domain: String, code: Int? = nil) -> Bool {
        if self.domain == domain {
            if let code {
                return self.code == code
            }
            return true
        }

        if let underlying = userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.containsNSError(domain: domain, code: code) {
            return true
        }

        let multipleUnderlyingErrors = userInfo[NSMultipleUnderlyingErrorsKey] as? [NSError]
            ?? (userInfo[NSMultipleUnderlyingErrorsKey] as? [Error])?.map { $0 as NSError }
            ?? []

        return multipleUnderlyingErrors.contains {
            $0.containsNSError(domain: domain, code: code)
        }
    }
}
