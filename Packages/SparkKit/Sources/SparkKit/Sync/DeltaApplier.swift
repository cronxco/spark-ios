import Foundation
import SwiftData

/// Interface for the delta-sync applier. The production implementation lands in
/// Phase 3 (in the `SparkSync` package) — the interface is declared here so
/// Phase 1 code paths compile against a stable contract.
public protocol DeltaApplying: Sendable {
    /// Apply a delta payload for the given resource, advancing the cursor on
    /// success. Implementations are responsible for their own transactionality.
    func apply(
        resource: String,
        payload: Data,
        container: ModelContainer
    ) async throws -> DeltaApplyResult
}

public struct DeltaApplyResult: Sendable, Equatable {
    public let upserted: Int
    public let deleted: Int
    public let nextCursor: String?

    public init(upserted: Int, deleted: Int, nextCursor: String?) {
        self.upserted = upserted
        self.deleted = deleted
        self.nextCursor = nextCursor
    }
}

/// Phase 1 placeholder. Always throws so any accidental wiring before Phase 3
/// fails loudly rather than silently dropping writes.
public struct UnimplementedDeltaApplier: DeltaApplying {
    public init() {}

    public func apply(
        resource: String,
        payload _: Data,
        container _: ModelContainer
    ) async throws -> DeltaApplyResult {
        throw DeltaApplierError.notYetImplemented(resource: resource)
    }
}

public enum DeltaApplierError: Error, Equatable {
    case notYetImplemented(resource: String)
}
