import Foundation
import Testing
@testable import SparkKit

@Suite("RecentSearchStore")
struct RecentSearchStoreTests {
    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_790_000_000)

        func advance(days: Double) {
            now = now.addingTimeInterval(days * 24 * 60 * 60)
        }
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "spark.recents.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeStore(_ defaults: UserDefaults, _ clock: Clock) -> RecentSearchStore {
        RecentSearchStore(defaults: defaults, now: { clock.now })
    }

    @Test("records searches newest first, trimmed and de-duplicated")
    func recordsNewestFirst() {
        let store = makeStore(makeDefaults(), Clock())

        store.record("tesco")
        store.record("  run  ")
        let recents = store.record("tesco")

        #expect(recents == ["tesco", "run"])
        #expect(store.load() == ["tesco", "run"])
    }

    @Test("ignores blank queries")
    func ignoresBlank() {
        let store = makeStore(makeDefaults(), Clock())

        #expect(store.record("   ").isEmpty)
        #expect(store.load().isEmpty)
    }

    @Test("keeps at most maxCount searches")
    func capsCount() {
        let store = makeStore(makeDefaults(), Clock())

        for index in 0..<(RecentSearchStore.maxCount + 3) {
            store.record("query \(index)")
        }

        let recents = store.load()
        #expect(recents.count == RecentSearchStore.maxCount)
        #expect(recents.first == "query \(RecentSearchStore.maxCount + 2)")
    }

    @Test("expires searches after 30 days on read and prunes them from storage")
    func expiresOnRead() {
        let defaults = makeDefaults()
        let clock = Clock()
        let store = makeStore(defaults, clock)

        store.record("old")
        clock.advance(days: 20)
        store.record("newer")

        clock.advance(days: 9)
        #expect(store.load() == ["newer", "old"])

        clock.advance(days: 2)
        #expect(store.load() == ["newer"])

        let stored = defaults.data(forKey: RecentSearchStore.defaultsKey)
            .flatMap { try? JSONDecoder().decode([RecentSearchStore.Entry].self, from: $0) }
        #expect(stored?.map(\.query) == ["newer"])

        clock.advance(days: 30)
        #expect(store.load().isEmpty)
        #expect(defaults.object(forKey: RecentSearchStore.defaultsKey) == nil)
    }

    @Test("drops expired searches when a new one is recorded")
    func expiresOnWrite() {
        let clock = Clock()
        let store = makeStore(makeDefaults(), clock)

        store.record("old")
        clock.advance(days: 31)

        #expect(store.record("fresh") == ["fresh"])
    }

    @Test("searching again refreshes a query's 30 days")
    func searchingAgainRefreshes() {
        let clock = Clock()
        let store = makeStore(makeDefaults(), clock)

        store.record("tesco")
        clock.advance(days: 25)
        store.record("tesco")
        clock.advance(days: 25)

        #expect(store.load() == ["tesco"])
    }

    @Test("undated recents from older builds are discarded")
    func discardsLegacyStrings() {
        let defaults = makeDefaults()
        defaults.set(["legacy one", "legacy two"], forKey: RecentSearchStore.defaultsKey)
        let store = makeStore(defaults, Clock())

        #expect(store.load().isEmpty)
        #expect(store.record("new") == ["new"])
    }

    @Test("clear forgets every search")
    func clearForgets() {
        let defaults = makeDefaults()
        let store = makeStore(defaults, Clock())

        store.record("tesco")
        store.clear()

        #expect(store.load().isEmpty)
        #expect(defaults.object(forKey: RecentSearchStore.defaultsKey) == nil)
    }
}
