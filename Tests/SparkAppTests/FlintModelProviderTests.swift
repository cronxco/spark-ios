import Foundation
import Testing

@testable import Spark

@Suite("Flint model provider")
struct FlintModelProviderTests {
    private func snapshot(
        killSwitch: Bool = false,
        availability: FlintPCCSnapshot.Availability = .available,
        supportsLocale: Bool = true,
        quotaLimitReached: Bool = false
    ) -> FlintPCCSnapshot {
        FlintPCCSnapshot(
            isDisabledByKillSwitch: killSwitch,
            availability: availability,
            supportsCurrentLocale: supportsLocale,
            isQuotaLimitReached: quotaLimitReached
        )
    }

    @Test("an available model with quota left is ready")
    func readyWhenEverythingIsFine() {
        #expect(snapshot().readiness == .ready)
        #expect(snapshot().readiness.isReady)
    }

    @Test("the kill switch wins over every other signal")
    func killSwitchWins() {
        #expect(snapshot(killSwitch: true).readiness == .disabled)
        #expect(snapshot(killSwitch: true, availability: .deviceNotEligible, quotaLimitReached: true).readiness == .disabled)
    }

    @Test("availability is reported before locale and quota")
    func availabilityOrder() {
        #expect(snapshot(availability: .deviceNotEligible, supportsLocale: false).readiness == .deviceNotEligible)
        #expect(snapshot(availability: .systemNotReady, quotaLimitReached: true).readiness == .systemNotReady)
        #expect(snapshot(availability: .other).readiness == .unavailable)
    }

    @Test("an unsupported locale is reported before the quota")
    func localeBeforeQuota() {
        #expect(snapshot(supportsLocale: false, quotaLimitReached: true).readiness == .unsupportedLocale)
    }

    @Test("a used-up daily quota keeps PCC out even though the model is available")
    func quotaLimit() {
        #expect(snapshot(quotaLimitReached: true).readiness == .quotaLimitReached)
        #expect(!snapshot(quotaLimitReached: true).readiness.isReady)
    }

    @Test("readiness raw values are stable telemetry strings")
    func telemetryStrings() {
        #expect(FlintPCCReadiness.quotaLimitReached.rawValue == "quota_limit_reached")
        #expect(FlintPCCReadiness.deviceNotEligible.rawValue == "device_not_eligible")
        #expect(FlintPCCReadiness.unsupportedLocale.rawValue == "unsupported_locale")
        #expect(FlintPCCReadiness.systemNotReady.rawValue == "system_not_ready")
    }

    @Test("the kill switch reads the App Group default and is off by default")
    func killSwitchDefault() throws {
        let suite = "flint-model-provider-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(!FlintModelProvider.isPrivateCloudComputeDisabled(defaults: defaults))
        defaults.set(true, forKey: FlintModelProvider.pccKillSwitchKey)
        #expect(FlintModelProvider.isPrivateCloudComputeDisabled(defaults: defaults))
    }

    @Test("errors that are not PCC failures never trigger an on-device retry")
    func unrelatedErrorsDoNotFallBack() {
        #expect(CancellationError().privateCloudComputeFallbackReason == nil)
        #expect(URLError(.notConnectedToInternet).privateCloudComputeFallbackReason == nil)
        #expect(NSError(domain: "test", code: 1).privateCloudComputeFallbackReason == nil)
    }
}
