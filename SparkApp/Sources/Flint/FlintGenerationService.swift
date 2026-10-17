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

    // MARK: - Today summary line — light reasoning, no tools

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
        Use only the supplied briefing facts.
        The app is named Spark, but Spark is not the user and must not be described as doing the user's actions.
        Do not write phrases like "Spark slept", "Spark walked", "Spark spent", or "Spark had".
        Write about the user directly ("You slept...") or use neutral phrasing ("Sleep held steady...").
        Write two or three short sentences, never more than 320 characters in total.
        First sentence: the main pattern worth noticing.
        Second sentence: the most notable change, anomaly or heads-up, with the actual numbers or times from the facts.
        Optional third sentence: one thing worth watching, only if the facts support it.
        Prefer anomalies and unusual changes, then activity, sleep or spend, then a neutral recap.
        Be specific: name what happened and when. Never write "an unusual reading" without saying which reading and how it differed.
        Do not invent missing data. Do not repeat the same fact twice.
        For today, describe the day so far.
        For past dates, describe the day in review.
        Do not say "today" for past dates.
        Avoid raw metric names, IDs, source names, and jargon.
        Avoid medical or financial advice.
        Avoid percentage changes.
        No greetings, no filler, no exclamation marks.
        If nothing in the facts is worth saying, return empty text rather than a generic line.
        """

        return try await generate(
            reasoning: .light,
            instructions: instructions,
            tools: [],
            fallbackNote: fallback,
            path: "summary_line"
        ) { model in
            let response = try await model.session.respond(
                generating: GeneratedTodaySummaryLine.self,
                options: FlintModelProvider.generationOptions(for: .light, maximumResponseTokens: 300),
                contextOptions: FlintModelProvider.contextOptions(for: .light),
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
                reasoning: .light,
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
