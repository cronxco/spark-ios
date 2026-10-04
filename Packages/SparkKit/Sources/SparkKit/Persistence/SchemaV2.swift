import Foundation
import SwiftData

public enum SparkSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        SparkSchemaV1.models + [CachedCheckIn.self]
    }
}
