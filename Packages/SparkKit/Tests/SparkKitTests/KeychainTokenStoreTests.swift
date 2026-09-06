import Foundation
import Testing
@testable import SparkKit

@Suite("KeychainTokenStore")
struct KeychainTokenStoreTests {
    /// Each test scopes itself to a unique service name so we don't stomp on
    /// the production Keychain item or bleed state between test cases.
    /// Simulator tests still require a signed host with Keychain entitlements.
    private func makeStore(service: String = "co.cronx.sparkapp.tests.\(UUID().uuidString)") -> KeychainTokenStore {
        return KeychainTokenStore(service: service, account: "test", accessGroup: nil)
    }

    @Test("round-trips tokens through the Keychain")
    func roundTrip() async throws {
        let store = makeStore()
        try await store.store(access: "access-1", refresh: "refresh-1", expiresIn: 3600)
        let tokens = await store.tokens()
        #expect(tokens?.accessToken == "access-1")
        #expect(tokens?.refreshToken == "refresh-1")
        #expect(tokens?.expiresIn == 3600)
        await store.clear()
    }

    @Test("returns nil when no token is stored")
    func emptyState() async throws {
        let store = makeStore()
        #expect(try await store.checkedTokens() == nil)
        #expect(await store.accessToken() == nil)
        #expect(await store.refreshToken() == nil)
        #expect(await store.hasRefreshToken() == false)
    }

    @Test("replacing tokens overwrites the previous value")
    func overwrite() async throws {
        let store = makeStore()
        try await store.store(access: "old", refresh: "old-r", expiresIn: 1)
        try await store.store(access: "new", refresh: "new-r", expiresIn: 7200)
        #expect(await store.accessToken() == "new")
        #expect(await store.refreshToken() == "new-r")
        await store.clear()
    }

    @Test("separate store instances observe token rotation")
    func independentInstancesObserveRotation() async throws {
        let service = "co.cronx.sparkapp.tests.\(UUID().uuidString)"
        let first = makeStore(service: service)
        let second = makeStore(service: service)

        try await first.store(access: "old", refresh: "old-r", expiresIn: 1)
        #expect(await second.refreshToken() == "old-r")

        try await first.store(access: "new", refresh: "new-r", expiresIn: 7200)
        #expect(await second.accessToken() == "new")
        #expect(await second.refreshToken() == "new-r")

        await first.clear()
        #expect(await second.tokens() == nil)
    }

    @Test("clear wipes stored tokens")
    func clear() async throws {
        let store = makeStore()
        try await store.store(access: "a", refresh: "b", expiresIn: 60)
        await store.clear()
        #expect(await store.accessToken() == nil)
    }

    @Test("expiresAt is derived from issuedAt + expiresIn")
    func expiresAtMath() {
        let issued = Date(timeIntervalSince1970: 1_700_000_000)
        let tokens = AuthTokens(accessToken: "a", refreshToken: "b", issuedAt: issued, expiresIn: 3600)
        #expect(tokens.expiresAt == issued.addingTimeInterval(3600))
    }
}
