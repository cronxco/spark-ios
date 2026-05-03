import CoreSpotlight
import Foundation
import SparkKit
import SwiftData
import UniformTypeIdentifiers

/// Incrementally indexes SwiftData cache into CoreSpotlight so the user can
/// find events, blocks, places, and integrations from the iOS home-screen search.
///
/// Called by BGTaskCoordinator's nightly prefetch task. Items older than
/// `ttlDays` are purged on each run.
public enum SpotlightIndexer {
    private static let batchSize = 200
    private static let ttlDays = 30

    // MARK: - Index

    @MainActor
    public static func indexBatch(container: ModelContainer) async {
        let context = ModelContext(container)
        var items: [CSSearchableItem] = []

        if let events = try? context.fetch(FetchDescriptor<CachedEvent>()) {
            items += events.map(makeItem(for:))
        }
        if let blocks = try? context.fetch(FetchDescriptor<CachedBlock>()) {
            items += blocks.map(makeItem(for:))
        }
        if let places = try? context.fetch(FetchDescriptor<CachedPlace>()) {
            items += places.map(makeItem(for:))
        }
        if let integrations = try? context.fetch(FetchDescriptor<CachedIntegration>()) {
            items += integrations.map(makeItem(for:))
        }

        let chunks = stride(from: 0, to: items.count, by: batchSize).map {
            Array(items[$0..<min($0 + batchSize, items.count)])
        }
        for chunk in chunks {
            try? await CSSearchableIndex.default().indexSearchableItems(chunk)
        }
    }

    // MARK: - Purge

    @MainActor
    public static func purgeStaleItems(container: ModelContainer) async {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -ttlDays, to: .now) else { return }
        let context = ModelContext(container)
        var identifiers: [String] = []

        let eventDesc = FetchDescriptor<CachedEvent>(predicate: #Predicate { $0.lastSyncedAt < cutoff })
        if let stale = try? context.fetch(eventDesc) {
            identifiers += stale.map { "co.cronx.spark.event.\($0.id)" }
        }

        let blockDesc = FetchDescriptor<CachedBlock>(predicate: #Predicate { $0.lastSyncedAt < cutoff })
        if let stale = try? context.fetch(blockDesc) {
            identifiers += stale.map { "co.cronx.spark.block.\($0.id)" }
        }

        let placeDesc = FetchDescriptor<CachedPlace>(predicate: #Predicate { $0.lastSyncedAt < cutoff })
        if let stale = try? context.fetch(placeDesc) {
            identifiers += stale.map { "co.cronx.spark.place.\($0.id)" }
        }

        let integDesc = FetchDescriptor<CachedIntegration>(predicate: #Predicate { $0.lastSyncedAt < cutoff })
        if let stale = try? context.fetch(integDesc) {
            identifiers += stale.map { "co.cronx.spark.integration.\($0.service)" }
        }

        if !identifiers.isEmpty {
            try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers)
        }
    }

    // MARK: - Item factories

    private static func makeItem(for event: CachedEvent) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        let actionLabel = event.action.replacingOccurrences(of: "_", with: " ").capitalized
        let domainLabel = event.domain.replacingOccurrences(of: "_", with: " ").capitalized
        attrs.title = "\(actionLabel) \(domainLabel)"
        attrs.contentDescription = event.service.capitalized
        attrs.keywords = [event.service, event.domain, event.action]
        attrs.lastUsedDate = event.time
        attrs.contentURL = URL(string: "https://spark.cronx.co/events/\(event.id)")
        return CSSearchableItem(
            uniqueIdentifier: "co.cronx.spark.event.\(event.id)",
            domainIdentifier: "co.cronx.spark.events",
            attributeSet: attrs
        )
    }

    private static func makeItem(for block: CachedBlock) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = block.title
        attrs.contentDescription = block.content
        attrs.lastUsedDate = block.time
        attrs.keywords = [block.blockType]
        attrs.contentURL = URL(string: "https://spark.cronx.co/blocks/\(block.id)")
        return CSSearchableItem(
            uniqueIdentifier: "co.cronx.spark.block.\(block.id)",
            domainIdentifier: "co.cronx.spark.blocks",
            attributeSet: attrs
        )
    }

    private static func makeItem(for place: CachedPlace) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = place.title
        attrs.contentDescription = place.address
        if let lat = place.latitude { attrs.latitude = NSNumber(value: lat) }
        if let lon = place.longitude { attrs.longitude = NSNumber(value: lon) }
        attrs.contentURL = URL(string: "https://spark.cronx.co/places/\(place.id)")
        return CSSearchableItem(
            uniqueIdentifier: "co.cronx.spark.place.\(place.id)",
            domainIdentifier: "co.cronx.spark.places",
            attributeSet: attrs
        )
    }

    private static func makeItem(for integration: CachedIntegration) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = integration.name
        attrs.contentDescription = integration.service.capitalized
        attrs.contentURL = URL(string: "https://spark.cronx.co/integrations/\(integration.service)/details")
        // Use service name as identifier (matches DeepLink routing by service).
        return CSSearchableItem(
            uniqueIdentifier: "co.cronx.spark.integration.\(integration.service)",
            domainIdentifier: "co.cronx.spark.integrations",
            attributeSet: attrs
        )
    }
}
