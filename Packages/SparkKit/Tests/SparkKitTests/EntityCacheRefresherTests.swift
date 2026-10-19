import Foundation
import SwiftData
import Testing
@testable import SparkKit

@MainActor
struct EntityCacheRefresherTests {
    @Test func integrationsUpsertWithoutDuplicating() throws {
        let container = try SparkDataStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let integration = Integration(id: "i1", service: "oura", name: "Oura", instanceType: "ring", status: "up_to_date")

        EntityCacheRefresher.upsert(integrations: [integration], in: context)
        EntityCacheRefresher.upsert(integrations: [integration], in: context)

        let rows = try context.fetch(FetchDescriptor<CachedIntegration>())
        #expect(rows.count == 1)
        #expect(rows.first?.name == "Oura")
    }

    @Test func pruneDropsOnlyRowsMissingFromTheFetchedSet() throws {
        let container = try SparkDataStore.makeInMemoryContainer()
        let context = ModelContext(container)
        for id in ["i1", "i2"] {
            context.insert(CachedIntegration(id: id, service: "oura", name: id, status: "active"))
        }

        EntityCacheRefresher.prune(integrationsKeeping: ["i1"], in: context)

        let rows = try context.fetch(FetchDescriptor<CachedIntegration>())
        #expect(rows.map(\.id) == ["i1"])
    }

    @Test func anomaliesDescribeAgainstBaseline() throws {
        #expect(try EntityCacheRefresher.describe(Self.anomaly(current: "44 years", baseline: "40 years")) == "Heart age is 44 years, against 40 years normally")
        #expect(try EntityCacheRefresher.describe(Self.anomaly(current: nil, baseline: nil)) == "Heart age")
    }

    private static func anomaly(current: String?, baseline: String?) throws -> Anomaly {
        let json = """
        {"id":"a1","metric":"oura.heart_age","display_name":"Heart age","valence":"bad","is_ordinal":false\(current.map { ",\"current_display\":\"\($0)\"" } ?? "")\(baseline.map { ",\"baseline_display\":\"\($0)\"" } ?? "")}
        """
        return try JSONDecoder().decode(Anomaly.self, from: Data(json.utf8))
    }
}
