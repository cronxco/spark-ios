import AppIntents
import Foundation
import SparkKit

// MARK: - Entity queries
//
// The new Siri prefers `IndexedEntity` auto-resolution against the semantic
// index. These queries are the deterministic fallback: `entities(for:)` resolves
// identifiers Siri hands back, `suggestedEntities()` powers the Shortcuts
// picker, and `EntityStringQuery.entities(matching:)` backs free-text matching.
// All reads go through the shared cached `IntentService` SwiftData layer so they
// work in the extension process and offline.

public struct EventEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [EventEntity.ID]) async throws -> [EventEntity] {
        await MainActor.run { IntentService.eventEntities(matching: identifiers) }
    }

    public func suggestedEntities() async throws -> [EventEntity] {
        await MainActor.run { IntentService.eventEntities(limit: 15) }
    }

    public func entities(matching string: String) async throws -> [EventEntity] {
        await MainActor.run { IntentService.eventEntities(query: string) }
    }
}

public struct BlockEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [BlockEntity.ID]) async throws -> [BlockEntity] {
        await MainActor.run { IntentService.blockEntities(matching: identifiers) }
    }

    public func suggestedEntities() async throws -> [BlockEntity] {
        await MainActor.run { IntentService.blockEntities(limit: 15) }
    }

    public func entities(matching string: String) async throws -> [BlockEntity] {
        let needle = string.lowercased()
        return await MainActor.run {
            IntentService.blockEntities(limit: 500).filter {
                $0.title.lowercased().contains(needle) || ($0.body?.lowercased().contains(needle) ?? false)
            }
        }
    }
}

public struct PlaceEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [PlaceEntity.ID]) async throws -> [PlaceEntity] {
        await MainActor.run { IntentService.placeEntities(matching: identifiers) }
    }

    public func suggestedEntities() async throws -> [PlaceEntity] {
        await MainActor.run { IntentService.placeEntities(limit: 25) }
    }

    public func entities(matching string: String) async throws -> [PlaceEntity] {
        let needle = string.lowercased()
        return await MainActor.run {
            IntentService.placeEntities(limit: 500).filter {
                $0.name.lowercased().contains(needle) || ($0.address?.lowercased().contains(needle) ?? false)
            }
        }
    }
}

public struct MetricEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [MetricEntity.ID]) async throws -> [MetricEntity] {
        await MainActor.run { IntentService.metricEntities(matching: identifiers) }
    }

    public func suggestedEntities() async throws -> [MetricEntity] {
        await MainActor.run { IntentService.metricEntities(limit: 25) }
    }

    public func entities(matching string: String) async throws -> [MetricEntity] {
        let needle = string.lowercased()
        return await MainActor.run {
            IntentService.metricEntities(limit: 500).filter {
                $0.displayName.lowercased().contains(needle)
                    || $0.id.lowercased().contains(needle)
                    || $0.keywords.contains { $0.lowercased().contains(needle) }
            }
        }
    }
}

public struct AnomalyEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [AnomalyEntity.ID]) async throws -> [AnomalyEntity] {
        await MainActor.run { IntentService.anomalyEntities(matching: identifiers) }
    }

    public func suggestedEntities() async throws -> [AnomalyEntity] {
        await MainActor.run { IntentService.anomalyEntities(limit: 15) }
    }

    public func entities(matching string: String) async throws -> [AnomalyEntity] {
        let needle = string.lowercased()
        return await MainActor.run {
            IntentService.anomalyEntities(limit: 200).filter {
                $0.summary.lowercased().contains(needle)
                    || ($0.metric?.lowercased().contains(needle) ?? false)
            }
        }
    }
}

public struct IntegrationEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [IntegrationEntity.ID]) async throws -> [IntegrationEntity] {
        await MainActor.run { IntentService.integrationEntities(matching: identifiers) }
    }

    public func suggestedEntities() async throws -> [IntegrationEntity] {
        await MainActor.run { IntentService.integrationEntities() }
    }

    public func entities(matching string: String) async throws -> [IntegrationEntity] {
        let needle = string.lowercased()
        return await MainActor.run {
            IntentService.integrationEntities().filter {
                $0.name.lowercased().contains(needle) || $0.service.lowercased().contains(needle)
            }
        }
    }
}

public struct DaySummaryEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [DaySummaryEntity.ID]) async throws -> [DaySummaryEntity] {
        await MainActor.run { IntentService.daySummaryEntities(matching: identifiers) }
    }

    public func suggestedEntities() async throws -> [DaySummaryEntity] {
        await MainActor.run { IntentService.daySummaryEntities(limit: 7) }
    }

    public func entities(matching string: String) async throws -> [DaySummaryEntity] {
        let needle = string.lowercased()
        return await MainActor.run {
            IntentService.daySummaryEntities(limit: 60).filter {
                $0.title.lowercased().contains(needle) || $0.id.contains(needle)
            }
        }
    }
}
