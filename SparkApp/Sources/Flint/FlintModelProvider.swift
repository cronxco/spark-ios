import Foundation
import FoundationModels
import SparkKit

// MARK: - Flint model provider (iOS 27)
//
// PCC-primary generation with on-device fallback, per the iOS 27 decision:
// try Private Cloud Compute first (better quality, supports deep reasoning +
// tool calling), fall back to the on-device system model when PCC is
// unavailable (ineligible device, Apple Intelligence off, unsupported locale,
// daily quota used up, offline), and finally to a static fallback handled by
// the caller. Runtime PCC failures (quota, network, service) are handled by
// `FlintGenerationService`, which re-resolves with PCC excluded.
//
// PCC needs the managed `com.apple.developer.private-cloud-compute`
// entitlement (SparkApp.entitlements). The App Group default
// `spark.flint.pcc.disabled` is a kill switch that forces on-device only.
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

    var contextReasoningLevel: ContextOptions.ReasoningLevel {
        switch self {
        case .light: .light
        case .deep: .deep
        }
    }
}

/// A resolved session plus the tier it represents.
struct FlintResolvedSession {
    let session: LanguageModelSession
    let tier: FlintGenerationTier
    let availability: FlintGenerationAvailability
    /// Why PCC was skipped when this session is on-device; `nil` when PCC was
    /// used or was not requested.
    var pccSkipReason: FlintPCCReadiness?
}

/// Whether the Private Cloud Compute model can serve a request right now.
enum FlintPCCReadiness: String, Sendable, Equatable {
    case ready
    case disabled
    case deviceNotEligible = "device_not_eligible"
    case systemNotReady = "system_not_ready"
    case unavailable
    case unsupportedLocale = "unsupported_locale"
    case quotaLimitReached = "quota_limit_reached"

    var isReady: Bool { self == .ready }
}

/// The inputs to the PCC readiness decision, separated from the framework
/// types so the ordering of the checks can be unit-tested.
struct FlintPCCSnapshot: Sendable, Equatable {
    enum Availability: Sendable, Equatable {
        case available
        case deviceNotEligible
        case systemNotReady
        case other
    }

    var isDisabledByKillSwitch: Bool
    var availability: Availability
    var supportsCurrentLocale: Bool
    var isQuotaLimitReached: Bool

    var readiness: FlintPCCReadiness {
        if isDisabledByKillSwitch { return .disabled }
        switch availability {
        case .available: break
        case .deviceNotEligible: return .deviceNotEligible
        case .systemNotReady: return .systemNotReady
        case .other: return .unavailable
        }
        if !supportsCurrentLocale { return .unsupportedLocale }
        if isQuotaLimitReached { return .quotaLimitReached }
        return .ready
    }
}

enum FlintModelProvider {
    /// Resolves the best available model for the requested reasoning level.
    /// Returns `.failure` with the reason when no language model is available
    /// (caller then uses the static fallback note).
    static func resolve(
        reasoning: FlintReasoning,
        instructions: String,
        tools: [any Tool] = [],
        allowPrivateCloudCompute: Bool = true
    ) -> Result<FlintResolvedSession, FlintGenerationAvailability> {
        // 1. Private Cloud Compute (primary).
        var skipReason: FlintPCCReadiness?
        if allowPrivateCloudCompute {
            if isPrivateCloudComputeDisabled() {
                skipReason = .disabled
            } else {
                let pcc = PrivateCloudComputeLanguageModel()
                let readiness = pccSnapshot(for: pcc).readiness
                if readiness.isReady {
                    let session = LanguageModelSession(model: pcc, tools: tools, instructions: instructions)
                    return .success(FlintResolvedSession(
                        session: session,
                        tier: .privateCloudCompute,
                        availability: .privateCloudCompute,
                        pccSkipReason: nil
                    ))
                }
                skipReason = readiness
            }
        }

        // 2. On-device system model (fallback).
        let device = SystemLanguageModel.default
        switch device.availability {
        case .available:
            let session = LanguageModelSession(model: device, tools: tools, instructions: instructions)
            return .success(FlintResolvedSession(
                session: session,
                tier: .onDevice,
                availability: .onDevice,
                pccSkipReason: skipReason
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

    static func contextOptions(for reasoning: FlintReasoning) -> ContextOptions {
        ContextOptions(includeSchemaInPrompt: true, reasoningLevel: reasoning.contextReasoningLevel)
    }

    // MARK: - Private Cloud Compute resolution
    //
    // Availability is a *runtime* check (not OS-version gated; the deployment
    // target is iOS 27): it is false on ineligible devices, when Apple
    // Intelligence is off, for unsupported locales, and once the user's daily
    // quota is used. The call is isolated here so the rest of Flint is
    // provider-agnostic.

    static let pccKillSwitchKey = "spark.flint.pcc.disabled"

    static func isPrivateCloudComputeDisabled(defaults: UserDefaults = .sparkAppGroup) -> Bool {
        defaults.bool(forKey: pccKillSwitchKey)
    }

    private static func pccSnapshot(for model: PrivateCloudComputeLanguageModel) -> FlintPCCSnapshot {
        let availability: FlintPCCSnapshot.Availability
        if case .available = model.availability {
            availability = .available
        } else if case .unavailable(.deviceNotEligible) = model.availability {
            availability = .deviceNotEligible
        } else if case .unavailable(.systemNotReady) = model.availability {
            availability = .systemNotReady
        } else {
            availability = .other
        }
        return FlintPCCSnapshot(
            isDisabledByKillSwitch: false,
            availability: availability,
            supportsCurrentLocale: model.supportsLocale(.current),
            isQuotaLimitReached: model.quotaUsage.isLimitReached
        )
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
