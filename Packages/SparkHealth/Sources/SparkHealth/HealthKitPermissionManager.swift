import Foundation
import HealthKit
import Observation

/// Three-wave HealthKit authorization manager. Each wave is independently
/// requestable and skippable per Apple HIG just-in-time guidelines.
@MainActor
@Observable
public final class HealthKitPermissionManager {
    public enum Wave: String, Sendable {
        case essentials
        case activity
        case advanced
    }

    public enum AuthState: Sendable {
        case notDetermined
        case granted
        case denied
    }

    public private(set) var essentialsState: AuthState = .notDetermined
    public private(set) var activityState: AuthState = .notDetermined
    public private(set) var advancedState: AuthState = .notDetermined

    private let store = HKHealthStore()
    private let defaults = UserDefaults(suiteName: "group.co.cronx.spark")

    public static let shared = HealthKitPermissionManager()

    private init() {
        loadPersistedState()
    }

    // MARK: - Public API

    public var isHealthAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    public func requestEssentials() async {
        let read: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.heartRate),
            HKCategoryType(.sleepAnalysis),
        ]
        await request(read: read, wave: .essentials)
    }

    public func requestActivity() async {
        let read: Set<HKObjectType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.appleExerciseTime),
            HKCategoryType(.appleStandHour),
        ]
        await request(read: read, wave: .activity)
    }

    public func requestAdvanced() async {
        let read: Set<HKObjectType> = [
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.vo2Max),
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.oxygenSaturation),
            HKCategoryType(.mindfulSession),
        ]
        await request(read: read, wave: .advanced)
    }

    // MARK: - Private

    private func request(read: Set<HKObjectType>, wave: Wave) async {
        guard isHealthAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: read)
            let granted = read.allSatisfy { type in
                store.authorizationStatus(for: type) != .notDetermined
            }
            let state: AuthState = granted ? .granted : .denied
            setAuthState(state, for: wave)
            persistState(state, for: wave)
        } catch {
            setAuthState(.denied, for: wave)
        }
    }

    private func setAuthState(_ state: AuthState, for wave: Wave) {
        switch wave {
        case .essentials: essentialsState = state
        case .activity:   activityState = state
        case .advanced:   advancedState = state
        }
    }

    private func persistState(_ state: AuthState, for wave: Wave) {
        defaults?.set(state == .granted, forKey: "hk.auth.\(wave.rawValue)")
    }

    private func loadPersistedState() {
        essentialsState = boolToAuthState(defaults?.bool(forKey: "hk.auth.essentials"))
        activityState   = boolToAuthState(defaults?.bool(forKey: "hk.auth.activity"))
        advancedState   = boolToAuthState(defaults?.bool(forKey: "hk.auth.advanced"))
    }

    private func boolToAuthState(_ value: Bool?) -> AuthState {
        guard let value else { return .notDetermined }
        return value ? .granted : .notDetermined
    }
}
