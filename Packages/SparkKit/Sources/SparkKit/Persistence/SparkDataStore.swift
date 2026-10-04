import Foundation
import SwiftData

/// Factory for the shared SwiftData container. The store lives in the App Group
/// container so the main app, widgets, and other extensions all read/write the
/// same cache.
public enum SparkDataStore {
    public static let appGroupIdentifier = "group.co.cronx.sparkapp"
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
            for: Schema(versionedSchema: SparkSchemaV3.self),
            migrationPlan: SparkMigrationPlan.self,
            configurations: configuration
        )
    }

    /// Deletes every cached record from the shared store.
    ///
    /// Sign-out has to leave nothing of the departing user behind: the store
    /// lives in the App Group, so anything left here is visible to the next
    /// account and to every extension. An equivalent wipe previously existed
    /// only inside `#if DEBUG` in DebugView and was never called on sign-out.
    ///
    /// Every model in `SparkSchemaV3` must appear below; a model added to the
    /// schema and forgotten here survives logout.
    @MainActor
    public static func purgeAll(in container: ModelContainer) throws {
        let context = container.mainContext

        try context.delete(model: CachedEvent.self)
        try context.delete(model: CachedObject.self)
        try context.delete(model: CachedBlock.self)
        try context.delete(model: CachedIntegration.self)
        try context.delete(model: CachedPlace.self)
        try context.delete(model: CachedMetric.self)
        try context.delete(model: CachedAnomaly.self)
        try context.delete(model: CachedDaySummary.self)
        try context.delete(model: CachedNotification.self)
        try context.delete(model: CachedCheckIn.self)
        try context.delete(model: CachedMoneyAccount.self)
        try context.delete(model: SyncCursor.self)

        try context.save()
    }

    /// In-memory container for tests and previews.
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Schema(versionedSchema: SparkSchemaV3.self),
            configurations: configuration
        )
    }
}
