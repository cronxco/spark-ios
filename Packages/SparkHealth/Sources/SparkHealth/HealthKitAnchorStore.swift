import Foundation
import HealthKit

/// Persists HKQueryAnchor per type identifier to App Group UserDefaults.
/// Encoded with NSKeyedArchiver (HKQueryAnchor is NSSecureCoding).
public final class HealthKitAnchorStore: Sendable {
    private static let suiteName = "group.co.cronx.spark"
    private static let keyPrefix = "hk.anchor."

    public static let shared = HealthKitAnchorStore()

    private init() {}

    public func anchor(for key: String) -> HKQueryAnchor? {
        guard let defaults = UserDefaults(suiteName: Self.suiteName),
              let data = defaults.data(forKey: Self.keyPrefix + key)
        else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    public func save(_ anchor: HKQueryAnchor, for key: String) {
        guard let defaults = UserDefaults(suiteName: Self.suiteName),
              let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
        else { return }
        defaults.set(data, forKey: Self.keyPrefix + key)
    }

    public func remove(for key: String) {
        UserDefaults(suiteName: Self.suiteName)?.removeObject(forKey: Self.keyPrefix + key)
    }
}
