import Foundation
import Testing
@testable import SparkKit

@Suite("ETagCache")
struct ETagCacheTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "spark.etag.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("store + get round-trip")
    func roundTrip() async throws {
        let defaults = makeDefaults()
        let cache = ETagCache(defaults: defaults)
        let url = URL(string: "https://spark.cronx.co/api/v1/mobile/briefing/today")!

        await cache.store("\"abc123\"", for: url)
        let loaded = await cache.etag(for: url)
        #expect(loaded == "\"abc123\"")
    }

    @Test("returns nil for unseen URL")
    func unseenURL() async {
        let cache = ETagCache(defaults: makeDefaults())
        let url = URL(string: "https://spark.cronx.co/unseen")!
        #expect(await cache.etag(for: url) == nil)
    }

    @Test("clear removes a single URL")
    func clearSingle() async {
        let cache = ETagCache(defaults: makeDefaults())
        let url = URL(string: "https://spark.cronx.co/one")!
        await cache.store("\"x\"", for: url)
        await cache.clear(for: url)
        #expect(await cache.etag(for: url) == nil)
    }

    @Test("clearAll wipes all stored etags")
    func clearAllWipesTaggedKeys() async {
        let cache = ETagCache(defaults: makeDefaults())
        let a = URL(string: "https://spark.cronx.co/a")!
        let b = URL(string: "https://spark.cronx.co/b")!
        await cache.store("\"x\"", for: a)
        await cache.store("\"y\"", for: b)
        await cache.clearAll()
        #expect(await cache.etag(for: a) == nil)
        #expect(await cache.etag(for: b) == nil)
    }
}
