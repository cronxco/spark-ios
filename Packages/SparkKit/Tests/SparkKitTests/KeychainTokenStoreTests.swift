import Foundation
import Testing
@testable import SparkKit

@Suite("KeychainTokenStore")
struct KeychainTokenStoreTests {
    /// Each test scopes itself to a unique service name so we don't stomp on
    /// the production Keychain item or bleed state between test cases. Using
    /// `accessGroup: nil` sidesteps the signed-entitlement requirement when
    /// running under `swift test` without a provisioning profile.
    private func makeStore() -> KeychainTokenStore {
        let service = "co.cronx.spark.tests.\(UUID().uuidString)"
        return KeychainTokenStore(service: service, account: "test", accessGroup: nil)
    }

    @Test("round-trips tokens through the Keychain")
    func roundTrip() async {
        let store = makeStore()
        await store.store(access: "access-1", refresh: "refresh-1", expiresIn: 3600)
        let tokens = await store.tokens()
        #expect(tokens?.accessToken == "access-1")
        #expect(tokens?.refreshToken == "refresh-1")
        #expect(tokens?.expiresIn == 3600)
        await store.clear()
    }

    @Test("returns nil when no token is stored")
    func emptyState() async {
        let store = makeStore()
        #expect(await store.accessToken() == nil)
        #expect(await store.refreshToken() == nil)
        #expect(await store.hasRefreshToken() == false)
    }

    @Test("replacing tokens overwrites the previous value")
    func overwrite() async {
        let store = makeStore()
        await store.store(access: "old", refresh: "old-r", expiresIn: 1)
        await store.store(access: "new", refresh: "new-r", expiresIn: 7200)
        #expect(await store.accessToken() == "new")
        #expect(await store.refreshToken() == "new-r")
        await store.clear()
    }

    @Test("clear wipes stored tokens")
    func clear() async {
        let store = makeStore()
        await store.store(access: "a", refresh: "b", expiresIn: 60)
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
