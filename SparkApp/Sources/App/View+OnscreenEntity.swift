import SwiftUI

/// Onscreen awareness for the rebuilt iOS 27 Siri.
///
/// Detail screens advertise the Spark entity currently on screen as the
/// `current` `NSUserActivity`, with a `persistentIdentifier` that mirrors the
/// `IndexedEntity` identifier fed into the Spotlight semantic index. This lets
/// Siri resolve "this" — "tell me more about this", "acknowledge this" — to the
/// matching Spark entity and route it through the app's intents.
///
/// `persistentIdentifier` deliberately matches the entity `id` used by the
/// `EntityQuery.entities(for:)` resolvers in SparkIntelligence, so the onscreen
/// activity and the indexed entity reconcile to the same record.
///
/// - Note: When building against the shipped iOS 27 SDK, the per-row
///   `.appEntityIdentifier(_:)` annotation can be layered on top of this for
///   multi-item lists; the single-primary-item screens below rely on the
///   `NSUserActivity` anchor.
extension View {
    func sparkOnscreenEntity(
        type: String,
        identifier: String,
        title: String,
        subtitle: String? = nil
    ) -> some View {
        userActivity(Self.sparkActivityType(for: type), isActive: true) { activity in
            activity.title = title
            activity.persistentIdentifier = "\(type):\(identifier)"
            activity.isEligibleForSearch = true
            activity.isEligibleForPrediction = true
            activity.isEligibleForHandoff = false
            var info: [String: String] = ["entityType": type, "entityID": identifier]
            if let subtitle { info["subtitle"] = subtitle }
            activity.addUserInfoEntries(from: info)
            activity.requiredUserInfoKeys = ["entityType", "entityID"]
        }
    }

    private static func sparkActivityType(for entityType: String) -> String {
        "co.cronx.sparkapp.onscreen.\(entityType)"
    }
}
