import AppIntents
import SparkIntelligence
import SwiftUI

/// Onscreen awareness for the rebuilt iOS 27 Siri.
///
/// Detail screens advertise the Spark entity currently on screen through the
/// native iOS 27 `.appEntityIdentifier(_:)` annotation and a matching
/// `current` `NSUserActivity`. This lets Siri resolve "this" — "tell me more
/// about this", "acknowledge this" — to the matching Spark entity and route it
/// through the app's intents.
///
/// `persistentIdentifier` deliberately matches the entity `id` used by the
/// `EntityQuery.entities(for:)` resolvers in SparkIntelligence, so the onscreen
/// activity and the indexed entity reconcile to the same record.
///
extension View {
    func sparkOnscreenEntity(
        type: String,
        identifier: String,
        title: String,
        subtitle: String? = nil
    ) -> some View {
        let nativeIdentifier = "\(type):\(identifier)"
        return sparkAppEntityIdentifier(type: type, identifier: identifier)
            .userActivity(Self.sparkActivityType(for: type), isActive: true) { activity in
            activity.title = title
            activity.persistentIdentifier = nativeIdentifier
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

    func sparkAppEntityIdentifier(type: String, identifier: String?) -> some View {
        appEntityIdentifier(Self.entityIdentifier(type: type, identifier: identifier))
    }

    private static func entityIdentifier(type: String, identifier: String?) -> EntityIdentifier? {
        guard let identifier, !identifier.isEmpty else { return nil }
        switch type {
        case "event": return EntityIdentifier(for: EventEntity.self, identifier: identifier)
        case "block": return EntityIdentifier(for: BlockEntity.self, identifier: identifier)
        case "place": return EntityIdentifier(for: PlaceEntity.self, identifier: identifier)
        case "metric": return EntityIdentifier(for: MetricEntity.self, identifier: identifier)
        case "anomaly": return EntityIdentifier(for: AnomalyEntity.self, identifier: identifier)
        case "integration": return EntityIdentifier(for: IntegrationEntity.self, identifier: identifier)
        case "moneyAccount": return EntityIdentifier(for: MoneyAccountEntity.self, identifier: identifier)
        case "spend":
            return EntityIdentifier(
                for: SpendSummaryEntity.self,
                identifier: identifier.hasPrefix("spend:") ? identifier : "spend:\(identifier)"
            )
        case "day": return EntityIdentifier(for: DaySummaryEntity.self, identifier: identifier)
        default: return nil
        }
    }
}
