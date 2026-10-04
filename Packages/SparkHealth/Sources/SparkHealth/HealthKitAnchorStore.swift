import Foundation
import HealthKit

/// Persists HKQueryAnchor per type identifier to App Group UserDefaults.
/// Encoded with NSKeyedArchiver (HKQueryAnchor is NSSecureCoding).
public final class HealthKitAnchorStore: Sendable {
    private static let suiteName = "group.co.cronx.sparkapp"
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
        guard let data = archive(anchor) else { return }
        save(archived: data, for: key)
    }

    /// The anchor's archived form, which can cross into a `@Sendable` closure
    /// and be saved once whatever it marks as read has been delivered.
    public func archive(_ anchor: HKQueryAnchor) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
    }

    public func save(archived data: Data, for key: String) {
        UserDefaults(suiteName: Self.suiteName)?.set(data, forKey: Self.keyPrefix + key)
    }

    public func remove(for key: String) {
        UserDefaults(suiteName: Self.suiteName)?.removeObject(forKey: Self.keyPrefix + key)
    }
}
