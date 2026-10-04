import Foundation

/// The search screen's recent queries.
///
/// Recents stay on this device: they live in the app's standard
/// `UserDefaults` (not the App Group, not iCloud key-value storage) and no
/// endpoint sends them to the server. Each query is stamped when it is
/// searched and expires `maxAge` (30 days) later; expired entries are dropped
/// whenever the list is read or written.
public struct RecentSearchStore {
    /// The standard-defaults key. Sign-out removes it.
    public static let defaultsKey = "spark.search.recents"

    /// How long a recent search is kept: 30 days.
    public static let maxAge: TimeInterval = 30 * 24 * 60 * 60

    /// How many recent searches are kept.
    public static let maxCount = 8

    public struct Entry: Codable, Equatable, Sendable {
        public let query: String
        public let searchedAt: Date

        public init(query: String, searchedAt: Date) {
            self.query = query
            self.searchedAt = searchedAt
        }
    }

    private let defaults: UserDefaults
    private let now: () -> Date

    public init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.now = now
    }

    /// The unexpired recent queries, newest first. Prunes expired ones from storage.
    public func load() -> [String] {
        let stored = storedEntries()
        let live = unexpired(stored)
        if live != stored {
            save(live)
        }
        return live.map(\.query)
    }

    /// Records a search and returns the updated recent queries, newest first.
    @discardableResult
    public func record(_ query: String) -> [String] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var entries = unexpired(storedEntries())
        guard !clean.isEmpty else {
            save(entries)
            return entries.map(\.query)
        }

        entries.removeAll { $0.query == clean }
        entries.insert(Entry(query: clean, searchedAt: now()), at: 0)
        if entries.count > Self.maxCount {
            entries = Array(entries.prefix(Self.maxCount))
        }
        save(entries)
        return entries.map(\.query)
    }

    /// Forgets every recent search.
    public func clear() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    /// Entries are JSON-encoded `Data`. Anything else under the key, such as
    /// the undated `[String]` older builds stored, reads as empty because its
    /// age is unknown.
    private func storedEntries() -> [Entry] {
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private func unexpired(_ entries: [Entry]) -> [Entry] {
        let cutoff = now().addingTimeInterval(-Self.maxAge)
        return entries.filter { $0.searchedAt > cutoff }
    }

    private func save(_ entries: [Entry]) {
        guard !entries.isEmpty, let data = try? JSONEncoder().encode(entries) else {
            defaults.removeObject(forKey: Self.defaultsKey)
            return
        }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
