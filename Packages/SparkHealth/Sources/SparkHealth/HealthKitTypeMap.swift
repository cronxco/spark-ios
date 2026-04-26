import Foundation
import HealthKit
import SparkKit

/// Bidirectional mapping between HK type identifiers and SparkKit server strings.
/// Server strings are the HK identifier raw values per API spec §5.6.
public enum HealthKitTypeMap {
    // MARK: - Quantity types

    public static let quantityTypes: [HKQuantityTypeIdentifier] = [
        .stepCount,
        .heartRate,
        .activeEnergyBurned,
        .distanceWalkingRunning,
        .appleExerciseTime,
        .heartRateVariabilitySDNN,
        .vo2Max,
        .respiratoryRate,
        .oxygenSaturation,
    ]

    // MARK: - Category types

    public static let categoryTypes: [HKCategoryTypeIdentifier] = [
        .sleepAnalysis,
        .appleStandHour,
        .mindfulSession,
    ]

    // MARK: - Lookup

    public static func serverType(for quantityIdentifier: HKQuantityTypeIdentifier) -> String {
        quantityIdentifier.rawValue
    }

    public static func serverType(for categoryIdentifier: HKCategoryTypeIdentifier) -> String {
        categoryIdentifier.rawValue
    }

    public static func unit(for identifier: HKQuantityTypeIdentifier) -> (HKUnit, String) {
        switch identifier {
        case .stepCount:                return (.count(), "count")
        case .heartRate:                return (.count().unitDivided(by: .minute()), "count/min")
        case .activeEnergyBurned:       return (.kilocalorie(), "kcal")
        case .distanceWalkingRunning:   return (.meter(), "m")
        case .appleExerciseTime:        return (.minute(), "min")
        case .heartRateVariabilitySDNN: return (HKUnit(from: "ms"), "ms")
        case .vo2Max:                   return (HKUnit(from: "ml/kg/min"), "ml/kg/min")
        case .respiratoryRate:          return (.count().unitDivided(by: .minute()), "count/min")
        case .oxygenSaturation:         return (.percent(), "%")
        default:                        return (.count(), "count")
        }
    }

    public static func backgroundFrequency(for identifier: HKQuantityTypeIdentifier) -> HKUpdateFrequency {
        switch identifier {
        case .heartRate, .activeEnergyBurned:
            return .immediate
        case .stepCount, .distanceWalkingRunning, .appleExerciseTime:
            return .hourly
        default:
            return .daily
        }
    }

    public static func backgroundFrequency(for identifier: HKCategoryTypeIdentifier) -> HKUpdateFrequency {
        switch identifier {
        case .sleepAnalysis: return .immediate
        default: return .daily
        }
    }
}
