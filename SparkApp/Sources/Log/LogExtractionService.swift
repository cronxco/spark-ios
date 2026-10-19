import Foundation
import FoundationModels

enum LogExtractionError: Error, Equatable {
    /// No language model can serve the request (Apple Intelligence off, device ineligible, model not ready).
    case unavailable
}

/// Reads one line of free text into a `LogDraft` with the Flint model stack:
/// Private Cloud Compute first, the on-device model if PCC cannot serve it.
enum LogExtractionService {
    static let instructions = """
    You turn one short line the user typed into a log entry for wine, beer, TV, cinema or board games.
    Copy only what the user said. Never invent a season, an episode, a quantity or a time.
    The title is the name of the thing, spelled as the user wrote it, without quantity, serving, verbs or episode numbers.
    "Half a bottle" is quantity 0.5 of a bottle. "A can of" is one beer served as a can. "A pint" is one beer, draft, 568 millilitres.
    Put the words for when it happened in when, as written: "yesterday at 8pm", "last night", "this morning". Leave when empty for now.
    "With Dan and Sam" puts Dan and Sam in people. Leave people empty if nobody is named.
    "Episodes 1 and 2 of The Diplomat" is tv, title The Diplomat, episodes [1, 2], no season.
    """

    static func extract(from text: String) async throws -> LogDraft {
        var allowPrivateCloudCompute = true

        for _ in 0..<3 {
            let resolved = FlintModelProvider.resolve(
                reasoning: .light,
                instructions: instructions,
                allowPrivateCloudCompute: allowPrivateCloudCompute
            )

            switch resolved {
            case .failure:
                throw LogExtractionError.unavailable
            case .success(let model):
                do {
                    let response = try await model.session.respond(
                        generating: LogDraft.self,
                        options: FlintModelProvider.generationOptions(for: .light, maximumResponseTokens: 200),
                        contextOptions: FlintModelProvider.contextOptions(for: .light),
                        metadata: [
                            "spark.generation.path": "log_entry",
                            "spark.generation.tier": model.tier.rawValue,
                        ]
                    ) {
                        "Log entry: \(text)"
                    }
                    return response.content
                } catch where model.tier == .privateCloudCompute && error.privateCloudComputeFallbackReason != nil {
                    allowPrivateCloudCompute = false
                }
            }
        }

        throw LogExtractionError.unavailable
    }
}
