import Foundation
import SwiftData

/// Factory for the shared SwiftData container. The store lives in the App Group
/// container so the main app, widgets, and other extensions all read/write the
/// same cache.
public enum SparkDataStore {
    public static let appGroupIdentifier = "group.co.cronx.spark"
    public static let storeFilename = "Spark.sqlite"

    public enum StoreError: Error {
        case appGroupContainerUnavailable
    }

    /// Returns the URL of the SwiftData store inside the App Group container.
    public static func storeURL(appGroupIdentifier: String = appGroupIdentifier) throws -> URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw StoreError.appGroupContainerUnavailable
        }
        return container.appendingPathComponent(storeFilename, isDirectory: false)
    }

    /// Default container bound to the App Group. Use from app + extensions.
    public static func makeContainer() throws -> ModelContainer {
        let url = try storeURL()
        let configuration = ModelConfiguration(url: url)
        return try ModelContainer(
            for: Schema(versionedSchema: SparkSchemaV1.self),
            configurations: configuration
        )
    }

    /// In-memory container for tests and previews.
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Schema(versionedSchema: SparkSchemaV1.self),
            configurations: configuration
        )
    }
}
