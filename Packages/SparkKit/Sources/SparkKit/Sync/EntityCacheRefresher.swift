import Foundation
import SwiftData

/// Fills the cache tables that no screen writes to, so Siri, Spotlight and
/// shortcuts can answer from them. Each source is independent: one failing
/// request leaves the others, and whatever was cached before, untouched.
public enum EntityCacheRefresher {
    /// Fetches integrations, metrics and money accounts, and derives anomalies
    /// from the day summaries already cached.
    @MainActor
    public static func refresh(using apiClient: APIClient, container: ModelContainer) async {
        let context = container.mainContext

        if let response = try? await apiClient.request(IntegrationsEndpoint.list()) {
            upsert(integrations: response.data, in: context)
        }
        if let metrics = try? await apiClient.request(MetricsEndpoint.list()) {
            upsert(metrics: metrics, in: context)
        }
        if let accounts = try? await apiClient.collectAllPages({ cursor in
            MoneyEndpoint.accounts(limit: 100, cursor: cursor)
        }) {
            for account in accounts {
                CachedMoneyAccount.upsert(account, in: context)
            }
        }
        upsertAnomaliesFromCachedSummaries(in: context)

        try? context.save()
    }

    static func upsert(integrations: [Integration], in context: ModelContext) {
        for integration in integrations {
            let id = integration.id
            let descriptor = FetchDescriptor<CachedIntegration>(predicate: #Predicate { $0.id == id })
            if let existing = (try? context.fetch(descriptor))?.first {
                existing.service = integration.service
                existing.name = integration.name
                existing.instanceType = integration.instanceType
                existing.status = integration.statusValue
                existing.lastSyncedAt = .now
            } else {
                context.insert(CachedIntegration(
                    id: id,
                    service: integration.service,
                    name: integration.name,
                    instanceType: integration.instanceType,
                    status: integration.statusValue
                ))
            }
        }
    }

    static func upsert(metrics: [Metric], in context: ModelContext) {
        for metric in metrics {
            let identifier = metric.identifier
            let descriptor = FetchDescriptor<CachedMetric>(predicate: #Predicate { $0.identifier == identifier })
            if let existing = (try? context.fetch(descriptor))?.first {
                existing.id = metric.id
                existing.displayName = metric.displayName
                existing.service = metric.service
                existing.action = metric.action
                existing.unit = metric.unit
                existing.eventCount = metric.eventCount
                existing.mean = metric.mean
                existing.lastEventAt = metric.lastEventAt
                existing.lastSyncedAt = .now
            } else {
                context.insert(CachedMetric(
                    id: metric.id,
                    identifier: identifier,
                    displayName: metric.displayName,
                    service: metric.service,
                    action: metric.action,
                    unit: metric.unit,
                    eventCount: metric.eventCount,
                    mean: metric.mean,
                    lastEventAt: metric.lastEventAt
                ))
            }
        }
    }

    static func upsertAnomaliesFromCachedSummaries(in context: ModelContext) {
        var descriptor = FetchDescriptor<CachedDaySummary>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 14
        guard let summaries = try? context.fetch(descriptor) else { return }
        for summary in summaries {
            guard let decoded = try? summary.decoded() else { continue }
            upsert(anomalies: decoded.anomalies, in: context)
        }
    }

    static func upsert(anomalies: [Anomaly], in context: ModelContext) {
        for anomaly in anomalies {
            let id = anomaly.id
            let descriptor = FetchDescriptor<CachedAnomaly>(predicate: #Predicate { $0.id == id })
            let existing = (try? context.fetch(descriptor))?.first
            let anomalyRow = existing ?? CachedAnomaly(id: id)
            anomalyRow.metric = anomaly.displayName ?? anomaly.metric
            anomalyRow.severity = anomaly.valence.rawValue
            anomalyRow.desc = describe(anomaly)
            anomalyRow.detectedAt = anomaly.detectedAt
            anomalyRow.acknowledgedAt = anomaly.acknowledgedAt
            anomalyRow.lastSyncedAt = .now
            if existing == nil {
                context.insert(anomalyRow)
            }
        }
    }

    static func describe(_ anomaly: Anomaly) -> String {
        let name = anomaly.displayName ?? anomaly.metric ?? "A metric"
        guard let current = anomaly.currentDisplay else { return name }
        guard let baseline = anomaly.baselineDisplay else { return "\(name) is \(current)" }
        return "\(name) is \(current), against \(baseline) normally"
    }
}
