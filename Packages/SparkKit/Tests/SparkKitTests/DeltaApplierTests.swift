import Foundation
import Testing
@testable import SparkKit

@Suite("DeltaApplier")
struct DeltaApplierTests {
    @Test("Phase 1 stub throws notYetImplemented for any resource")
    func stubThrows() async throws {
        let applier = UnimplementedDeltaApplier()
        let container = try await MainActor.run { try SparkDataStore.makeInMemoryContainer() }

        await #expect(throws: DeltaApplierError.self) {
            _ = try await applier.apply(
                resource: "events",
                payload: Data(),
                container: container
            )
        }
    }
}
