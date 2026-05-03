import Foundation
import HealthKit
import SparkKit

/// Registers HKObserverQuery for each authorised type. On each fire, runs an
/// HKAnchoredObjectQuery and hands new samples to HealthSampleUploader.
/// Background delivery is enabled per-type so iOS can wake the app.
///
/// Observer queries do not fire on the simulator — test on device.
public final class HealthKitObserver: @unchecked Sendable {
    public static let shared = HealthKitObserver()

    private let store = HKHealthStore()
    private let anchorStore = HealthKitAnchorStore.shared
    private let uploader = HealthSampleUploader.shared
    private let lock = NSLock()
    private var observerQueries: [String: HKObserverQuery] = [:]

    private init() {}

    // MARK: - Public API

    public func startObserving() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        for identifier in HealthKitTypeMap.quantityTypes {
            let type = HKQuantityType(identifier)
            let freq = HealthKitTypeMap.backgroundFrequency(for: identifier)
            register(type: type, key: identifier.rawValue, frequency: freq)
        }

        for identifier in HealthKitTypeMap.categoryTypes {
            let type = HKCategoryType(identifier)
            let freq = HealthKitTypeMap.backgroundFrequency(for: identifier)
            register(type: type, key: identifier.rawValue, frequency: freq)
        }
    }

    public func stopObserving() {
        let queries = lock.withLock { observerQueries }
        for query in queries.values { store.stop(query) }
        lock.withLock { observerQueries.removeAll() }
    }

    // MARK: - Private

    private func register(type: HKObjectType, key: String, frequency: HKUpdateFrequency) {
        store.enableBackgroundDelivery(for: type, frequency: frequency) { _, _ in }

        let query = HKObserverQuery(sampleType: type as! HKSampleType, predicate: nil) { [weak self] _, _, error in
            guard error == nil, let self else { return }
            self.fetchNewSamples(for: type, key: key)
        }
        store.execute(query)
        lock.withLock { observerQueries[key] = query }
    }

    private func fetchNewSamples(for objectType: HKObjectType, key: String) {
        guard let sampleType = objectType as? HKSampleType else { return }
        let anchor = anchorStore.anchor(for: key)

        let anchoredQuery = HKAnchoredObjectQuery(
            type: sampleType,
            predicate: nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, deleted, newAnchor, error in
            guard let self, error == nil else { return }

            if let newAnchor {
                let converted = self.convert(samples: samples ?? [], key: key)
                if !converted.isEmpty {
                    self.uploader.upload(samples: converted)
                    self.anchorStore.save(newAnchor, for: key)
                }
            }
        }
        store.execute(anchoredQuery)
    }

    private func convert(samples: [HKSample], key: String) -> [HealthSample] {
        samples.compactMap { sample -> HealthSample? in
            let sourceBundle = sample.sourceRevision.source.bundleIdentifier

            if let qty = sample as? HKQuantitySample {
                let identifier = HKQuantityTypeIdentifier(rawValue: key)
                let (unit, unitStr) = HealthKitTypeMap.unit(for: identifier)
                return HealthSample(
                    externalId: sample.uuid.uuidString,
                    type: key,
                    start: sample.startDate,
                    end: sample.endDate,
                    value: qty.quantity.doubleValue(for: unit),
                    unit: unitStr,
                    source: sourceBundle
                )
            }

            if let cat = sample as? HKCategorySample {
                return HealthSample(
                    externalId: sample.uuid.uuidString,
                    type: key,
                    start: sample.startDate,
                    end: sample.endDate,
                    value: Double(cat.value),
                    unit: "category",
                    source: sourceBundle
                )
            }

            if sample is HKWorkout {
                return HealthSample(
                    externalId: sample.uuid.uuidString,
                    type: "HKWorkoutTypeIdentifier",
                    start: sample.startDate,
                    end: sample.endDate,
                    value: sample.endDate.timeIntervalSince(sample.startDate),
                    unit: "s",
                    source: sourceBundle
                )
            }

            return nil
        }
    }
}
