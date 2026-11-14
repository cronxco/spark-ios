import Foundation
import FoundationModels
import SparkKit

@Generable
private struct GeneratedAskFlintAnswer {
    @Guide(description: "The answer, in two or three short sentences of plain text.")
    var text: String
}

/// The fallback behind Ask Flint when Spark's server is unreachable or out of
/// allowance. It runs Apple's model (Private Cloud Compute first, then on
/// device) with Flint's read-only tools, which read the live API where they
/// can and the SwiftData cache where they can't. It never changes anything.
struct AskFlintLocalAnswerer: AskFlintLocalAnswering {
    func answer(question: String) async -> String? {
        let instructions = """
        You are Flint, the assistant inside Spark, the user's personal data app.
        Answer the user's question about their own data using the provided tools.
        Use only what the tools return. If they return nothing useful, say you can't tell from what is on this device.
        You cannot change any data here. If asked to, say changes need a connection to Spark.
        Do not give medical or financial advice. Be brief and specific. British English.
        """

        var allowPrivateCloudCompute = true

        for _ in 0..<2 {
            guard case .success(let model) = FlintModelProvider.resolve(
                reasoning: .moderate,
                instructions: instructions,
                tools: FlintTools.digestTools,
                allowPrivateCloudCompute: allowPrivateCloudCompute
            ) else {
                return nil
            }

            do {
                let response = try await model.session.respond(
                    generating: GeneratedAskFlintAnswer.self,
                    options: FlintModelProvider.generationOptions(for: .moderate),
                    contextOptions: FlintModelProvider.contextOptions(for: .moderate),
                    metadata: [
                        "spark.generation.path": "ask_flint_local",
                        "spark.generation.tier": model.tier.rawValue,
                    ]
                ) {
                    """
                    Answer this question from the user's Spark data.

                    Question: \(question)
                    """
                }
                let text = response.content.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : text
            } catch where model.tier == .privateCloudCompute && error.privateCloudComputeFallbackReason != nil {
                // PCC could not serve it (quota, network, service): try once
                // more on the device.
                allowPrivateCloudCompute = false
            } catch {
                return nil
            }
        }

        return nil
    }
}
