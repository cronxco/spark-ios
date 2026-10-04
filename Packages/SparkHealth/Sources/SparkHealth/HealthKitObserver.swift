import Foundation
import HealthKit
import SparkKit

/// Registers HKObserverQuery for each authorised type. On each fire, runs an
/// HKAnchoredObjectQuery for what is new and hands it to HealthSampleUploader.
/// Background delivery is enabled per-type so iOS can wake the app.
///
/// Quantity types are uploaded as one reading per local day — HealthKit's own
/// daily total or average for each day the new samples touch — rather than as
/// the samples themselves. The server keeps one reading per metric per day, and
/// HealthKit's statistics count an overlap between iPhone and Watch once.
///
/// Observer queries do not fire on the simulator — test on device.
public final class HealthKitObserver: @unchecked Sendable {
    public static let shared = HealthKitObserver()
    public static let uploadEnabledKey = "health.upload.enabled"

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
        // While uploads are off, nothing is read and the anchor stays put, so
        // turning them on sends everything since the last delivered upload.
        let enabled = UserDefaults(suiteName: "group.co.cronx.sparkapp")?
            .bool(forKey: Self.uploadEnabledKey) == true
        guard enabled else { return }
        let anchor = anchorStore.anchor(for: key)

        let anchoredQuery = HKAnchoredObjectQuery(
            type: sampleType,
            predicate: nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, deleted, newAnchor, error in
            guard let self, error == nil, let newAnchor else { return }
            let samples = samples ?? []
            let deleted = deleted ?? []
            guard !samples.isEmpty || !deleted.isEmpty,
                  let archivedAnchor = self.anchorStore.archive(newAnchor)
            else { return }

            // The anchor moves only once the server has accepted everything it
            // covers. A failed or interrupted upload leaves it where it was, so
            // the next run re-reads the same samples; the server keeps the
            // latest reading of a day, so sending one twice is harmless.
            let anchorStore = self.anchorStore
            let advanceAnchor: @Sendable (Bool) -> Void = { delivered in
                if delivered { anchorStore.save(archived: archivedAnchor, for: key) }
            }

            if HealthKitTypeMap.quantityTypes.contains(HKQuantityTypeIdentifier(rawValue: key)) {
                var days = Self.localDays(touchedBy: samples)
                if !deleted.isEmpty {
                    // A deletion carries only the sample's UUID, not its date.
                    days.formUnion(Self.recentLocalDays(Self.deletionRereadDays))
                }
                self.uploadDailyReadings(key: key, days: days, completion: advanceAnchor)
            } else {
                // Category samples upload as they are; a deletion has nothing
                // to send.
                self.uploader.upload(samples: self.convert(samples: samples, key: key), completion: advanceAnchor)
            }
        }
        store.execute(anchoredQuery)
    }

    /// How far back a deletion re-reads, since HealthKit does not say which
    /// day a deleted sample belonged to. Deleting data from further back
    /// leaves that day's reading as it was.
    private static let deletionRereadDays = 30

    /// The start of each of the last `count` local days, today included.
    private static func recentLocalDays(_ count: Int) -> Set<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return Set((0 ..< count).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) })
    }

    /// The start of each local day a sample covers; one that runs past
    /// midnight touches both days.
    private static func localDays(touchedBy samples: [HKSample]) -> Set<Date> {
        let calendar = Calendar.current
        var days = Set<Date>()
        for sample in samples {
            var day = calendar.startOfDay(for: sample.startDate)
            let last = calendar.startOfDay(for: sample.endDate)
            while day <= last {
                days.insert(day)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return days
    }

    /// Reads HealthKit's daily statistic for each of `days` and uploads it as
    /// that day's reading, taken now. `completion` hears whether every reading
    /// was delivered.
    ///
    /// A day with nothing left to read, such as one whose only samples were
    /// deleted, sends nothing: the API has no way to clear a day, and a zero
    /// would invent a reading for a day HealthKit has no data for.
    private func uploadDailyReadings(key: String, days: Set<Date>, completion: @escaping @Sendable (Bool) -> Void) {
        guard let first = days.min() else {
            completion(true)
            return
        }
        let identifier = HKQuantityTypeIdentifier(rawValue: key)
        let calendar = Calendar.current
        let asOf = Date()

        let query = HKStatisticsCollectionQuery(
            quantityType: HKQuantityType(identifier),
            quantitySamplePredicate: HKQuery.predicateForSamples(withStart: first, end: asOf, options: []),
            options: HealthKitTypeMap.dailyStatistic(for: identifier),
            anchorDate: first,
            intervalComponents: DateComponents(day: 1)
        )
        query.initialResultsHandler = { [weak self] _, collection, error in
            guard let self, error == nil, let collection else {
                completion(false)
                return
            }
            let identifier = HKQuantityTypeIdentifier(rawValue: key)
            let (unit, unitString) = HealthKitTypeMap.unit(for: identifier)
            let summed = HealthKitTypeMap.dailyStatistic(for: identifier) == .cumulativeSum

            let readings: [HealthSample] = collection.statistics().compactMap { statistics in
                guard days.contains(calendar.startOfDay(for: statistics.startDate)),
                      let quantity = summed ? statistics.sumQuantity() : statistics.averageQuantity()
                else { return nil }

                return HealthSample.dailyReading(
                    type: HealthKitTypeMap.serverType(for: identifier),
                    day: statistics.startDate,
                    value: quantity.doubleValue(for: unit),
                    unit: unitString,
                    source: "HealthKit",
                    asOf: asOf,
                    calendar: calendar
                )
            }
            self.uploader.upload(samples: readings, completion: completion)
        }
        store.execute(query)
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
