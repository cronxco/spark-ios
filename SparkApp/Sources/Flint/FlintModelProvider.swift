import Foundation
import FoundationModels

// MARK: - Flint model provider (iOS 27)
//
// PCC-primary generation with on-device fallback, per the iOS 27 decision:
// try Private Cloud Compute first (better quality, supports deep reasoning +
// tool calling), fall back to the on-device system model when PCC is
// unavailable (EU, not signed in to Apple Intelligence, offline), and finally
// to a static fallback handled by the caller.
//
// Reasoning is tiered: `.light` for the quick summary line, `.deep` for the
// digest (which also gets the live-data tools attached).

/// Which model tier actually produced a result — surfaced in telemetry.
enum FlintGenerationTier: String, Sendable, Equatable {
    case privateCloudCompute = "pcc"
    case onDevice = "on_device"
    case staticFallback = "static"
}

/// Reasoning intensity requested for a generation.
enum FlintReasoning: Sendable {
    case light
    case deep

    var maximumResponseTokens: Int {
        switch self {
        case .light: 80
        case .deep: 500
        }
    }
}

/// A resolved session plus the tier it represents.
struct FlintResolvedSession {
    let session: LanguageModelSession
    let tier: FlintGenerationTier
    let availability: FlintGenerationAvailability
}

enum FlintModelProvider {
    /// Resolves the best available model for the requested reasoning level.
    /// Returns `.failure` with the reason when no language model is available
    /// (caller then uses the static fallback note).
    static func resolve(
        reasoning: FlintReasoning,
        instructions: String,
        tools: [any Tool] = []
    ) -> Result<FlintResolvedSession, FlintGenerationAvailability> {
        // 1. Private Cloud Compute (primary).
        if let pcc = privateCloudComputeModel(), pccIsAvailable(pcc) {
            let session = LanguageModelSession(model: pcc, tools: tools, instructions: instructions)
            return .success(FlintResolvedSession(
                session: session,
                tier: .privateCloudCompute,
                availability: .privateCloudCompute
            ))
        }

        // 2. On-device system model (fallback).
        let device = SystemLanguageModel.default
        switch device.availability {
        case .available:
            let session = LanguageModelSession(model: device, tools: tools, instructions: instructions)
            return .success(FlintResolvedSession(
                session: session,
                tier: .onDevice,
                availability: .onDevice
            ))
        case .unavailable(let reason):
            return .failure(availability(from: reason))
        @unknown default:
            return .failure(.unavailable)
        }
    }

    static func generationOptions(for reasoning: FlintReasoning) -> GenerationOptions {
        GenerationOptions(maximumResponseTokens: reasoning.maximumResponseTokens)
    }

    // MARK: - Private Cloud Compute resolution
    //
    // PCC is exposed as a `SystemLanguageModel.UseCase`-style provider on iOS 27.
    // Availability is a *runtime* check (not OS-version gated): it is false in the
    // EU, on ineligible devices, when Apple Intelligence is off, or offline. The
    // call is isolated here so the rest of Flint is provider-agnostic.

    private static func privateCloudComputeModel() -> PrivateCloudComputeLanguageModel? {
        PrivateCloudComputeLanguageModel()
    }

    private static func pccIsAvailable(_ model: PrivateCloudComputeLanguageModel) -> Bool {
        if case .available = model.availability { return true }
        return false
    }

    private static func availability(
        from reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> FlintGenerationAvailability {
        switch reason {
        case .deviceNotEligible: .deviceNotEligible
        case .appleIntelligenceNotEnabled: .appleIntelligenceNotEnabled
        case .modelNotReady: .modelNotReady
        @unknown default: .unavailable
        }
    }
}
