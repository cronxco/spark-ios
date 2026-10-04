import Foundation
import SparkKit
import SwiftData

public struct SpotlightDiagnosticsSnapshot: Sendable {
    public let capturedAt: Date
    public let isSignedIn: Bool
    public let canOpenStore: Bool
    public let counts: [SpotlightEntityCount]

    public var totalCount: Int {
        counts.reduce(0) { $0 + $1.count }
    }

    public init(
        capturedAt: Date = .now,
        isSignedIn: Bool,
        canOpenStore: Bool,
        counts: [SpotlightEntityCount]
    ) {
        self.capturedAt = capturedAt
        self.isSignedIn = isSignedIn
        self.canOpenStore = canOpenStore
        self.counts = counts
    }
}

public struct SpotlightEntityCount: Identifiable, Sendable {
    public var id: String { name }

    public let name: String
    public let count: Int

    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}

public struct SpotlightIndexReport: Sendable {
    public var startedAt: Date
    public var finishedAt: Date?
    public var skippedReason: String?
    public var batches: [SpotlightIndexBatchReport]

    public var indexedCount: Int {
        batches.reduce(0) { $0 + $1.indexedCount }
    }

    public var failures: [SpotlightIndexBatchReport] {
        batches.filter { $0.errorDescription != nil }
    }

    public var hasFailures: Bool {
        !failures.isEmpty
    }

    public init(
        startedAt: Date = .now,
        finishedAt: Date? = nil,
        skippedReason: String? = nil,
        batches: [SpotlightIndexBatchReport] = []
    ) {
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.skippedReason = skippedReason
        self.batches = batches
    }

    @MainActor
    mutating func record(_ name: String, index: @MainActor () async throws -> Int) async {
        do {
            let count = try await index()
            batches.append(SpotlightIndexBatchReport(name: name, indexedCount: count))
        } catch {
            batches.append(SpotlightIndexBatchReport(
                name: name,
                indexedCount: 0,
                errorDescription: String(describing: error)
            ))
        }
    }
}

public struct SpotlightIndexBatchReport: Identifiable, Sendable {
    public var id: String { name }

    public let name: String
    public let indexedCount: Int
    public let errorDescription: String?

    public init(name: String, indexedCount: Int, errorDescription: String? = nil) {
        self.name = name
        self.indexedCount = indexedCount
        self.errorDescription = errorDescription
    }
}

public enum SpotlightDiagnostics {
    @MainActor
    public static func snapshot() async -> SpotlightDiagnosticsSnapshot {
        async let token = KeychainTokenStore().accessToken()
        let canOpenStore = IntentService.makeContext() != nil

        return await SpotlightDiagnosticsSnapshot(
            isSignedIn: token != nil,
            canOpenStore: canOpenStore,
            counts: [
                SpotlightEntityCount(name: "Events", count: IntentService.eventEntities(matching: nil, limit: 1000).count),
                SpotlightEntityCount(name: "Blocks", count: IntentService.blockEntities(matching: nil, limit: 1000).count),
                SpotlightEntityCount(name: "Places", count: IntentService.placeEntities(matching: nil, limit: 1000).count),
                SpotlightEntityCount(name: "Integrations", count: IntentService.integrationEntities().count),
                SpotlightEntityCount(name: "Money accounts", count: IntentService.moneyAccountEntities(matching: nil, limit: 1000).count),
                SpotlightEntityCount(name: "Metrics", count: IntentService.metricEntities(matching: nil, limit: 1000).count),
                SpotlightEntityCount(name: "Anomalies", count: IntentService.anomalyEntities(matching: nil, limit: 1000).count),
                SpotlightEntityCount(name: "Spend summaries", count: IntentService.spendSummaryEntities(matching: nil, limit: 90).count),
                SpotlightEntityCount(name: "Day summaries", count: IntentService.daySummaryEntities(matching: nil, limit: 90).count),
            ]
        )
    }
}
