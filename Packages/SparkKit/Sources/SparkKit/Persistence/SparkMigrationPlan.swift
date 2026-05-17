import Foundation
import SwiftData

public enum SparkMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SparkSchemaV1.self, SparkSchemaV2.self, SparkSchemaV3.self]
    }

    public static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SparkSchemaV1.self, toVersion: SparkSchemaV2.self),
            .lightweight(fromVersion: SparkSchemaV2.self, toVersion: SparkSchemaV3.self),
        ]
    }
}
