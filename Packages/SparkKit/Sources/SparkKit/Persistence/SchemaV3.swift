import Foundation
import SwiftData

public enum SparkSchemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)

    public static var models: [any PersistentModel.Type] {
        SparkSchemaV2.models + [CachedMoneyAccount.self]
    }
}
