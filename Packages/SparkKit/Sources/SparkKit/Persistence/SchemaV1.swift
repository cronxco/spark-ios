import Foundation
import SwiftData

public enum SparkSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            CachedDaySummary.self,
            CachedEvent.self,
            CachedObject.self,
            CachedBlock.self,
            CachedIntegration.self,
            CachedPlace.self,
            CachedMetric.self,
            CachedAnomaly.self,
            SyncCursor.self,
        ]
    }
}
