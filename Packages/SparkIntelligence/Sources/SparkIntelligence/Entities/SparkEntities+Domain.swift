import Foundation
import SparkKit

// Convenience initializers building entities directly from SparkKit domain
// models (API responses), parallel to the `init(cached:)` paths used by the
// Spotlight indexer. Pure value mapping — no SwiftData — so they are unit
// testable and reusable wherever the app already holds decoded models.

public extension EventEntity {
    init(model event: Event) {
        let actionLabel = event.action.replacingOccurrences(of: "_", with: " ").capitalized
        let domainLabel = event.domain.replacingOccurrences(of: "_", with: " ").capitalized
        let title = event.displayName?.nonEmpty ?? "\(actionLabel) \(domainLabel)"
        self.init(
            id: event.id,
            title: title,
            summary: event.displayValue?.nonEmpty ?? event.tldr?.nonEmpty ?? event.service.capitalized,
            tags: [event.service, event.domain, event.action].filter { !$0.isEmpty },
            service: event.service,
            domain: event.domain,
            action: event.action,
            timestamp: event.time
        )
    }
}

public extension BlockEntity {
    init(model block: Block) {
        self.init(
            id: block.id,
            title: block.title,
            body: block.content?.nonEmpty,
            blockType: block.blockType,
            timestamp: block.time
        )
    }
}

public extension PlaceEntity {
    init(model place: Place) {
        self.init(
            id: place.id,
            name: place.title,
            address: place.address?.nonEmpty,
            category: place.category?.nonEmpty ?? place.type?.nonEmpty,
            latitude: place.latitude,
            longitude: place.longitude,
            visitCount: nil
        )
    }
}

public extension MetricEntity {
    init(model metric: Metric) {
        self.init(
            id: metric.identifier,
            displayName: metric.displayName,
            latestValue: metric.mean,
            unit: metric.unit?.nonEmpty,
            lastEventAt: metric.lastEventAt,
            keywords: [metric.service, metric.action].filter { !$0.isEmpty }
        )
    }
}

public extension AnomalyEntity {
    init(model anomaly: Anomaly) {
        let summary = anomaly.displayName?.nonEmpty
            ?? anomaly.metric.map { "Unusual reading for \($0)" }
            ?? "Anomaly detected"
        self.init(
            id: anomaly.id,
            summary: summary,
            metric: anomaly.metric,
            direction: anomaly.direction,
            detectedAt: anomaly.detectedAt,
            acknowledged: false
        )
    }
}

public extension IntegrationEntity {
    init(model integration: Integration) {
        self.init(
            id: integration.service,
            name: integration.name,
            service: integration.service,
            status: integration.statusValue
        )
    }
}
