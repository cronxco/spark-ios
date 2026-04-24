import Foundation
import SwiftData
import Testing
@testable import SparkKit

@Suite("SparkDataStore")
@MainActor
struct SparkDataStoreTests {
    @Test("in-memory container boots with every SchemaV1 model")
    func inMemoryContainerBoots() throws {
        let container = try SparkDataStore.makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(CachedIntegration(
            id: "int-1",
            service: "monzo",
            name: "Personal",
            instanceType: "checking",
            status: "active"
        ))
        try context.save()

        let descriptor = FetchDescriptor<CachedIntegration>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.service == "monzo")
    }

    @Test("unique constraint on identifier is enforced")
    func uniqueMetricIdentifier() throws {
        let container = try SparkDataStore.makeInMemoryContainer()
        let context = ModelContext(container)

        context.insert(CachedMetric(
            id: "m-1",
            identifier: "oura.sleep.score",
            displayName: "Sleep Score",
            service: "oura",
            action: "sleep",
            eventCount: 10
        ))
        context.insert(CachedMetric(
            id: "m-2",
            identifier: "oura.sleep.score",
            displayName: "Sleep Score (dup)",
            service: "oura",
            action: "sleep",
            eventCount: 99
        ))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CachedMetric>())
        #expect(fetched.count == 1)
    }

    @Test("SyncCursor round-trips cursor + timestamp")
    func syncCursorRoundTrip() throws {
        let container = try SparkDataStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let ts = Date(timeIntervalSince1970: 1_730_000_000)
        context.insert(SyncCursor(resource: "events", cursor: "cur-1", lastSyncedAt: ts))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SyncCursor>())
        #expect(fetched.first?.resource == "events")
        #expect(fetched.first?.cursor == "cur-1")
        #expect(fetched.first?.lastSyncedAt == ts)
    }
}
