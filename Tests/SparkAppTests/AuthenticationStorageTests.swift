import Foundation
import Security
import SparkKit
import Testing

@Suite("Simulator authentication storage")
struct AuthenticationStorageTests {
    @Test("signed app can persist and reread tokens across store instances")
    func signedHostRoundTrip() async throws {
        let service = "co.cronx.sparkapp.tests.signed.\(UUID().uuidString)"
        let store = KeychainTokenStore(service: service)
        try await store.store(access: "test-access", refresh: "test-refresh", expiresIn: 3600)
        let reader = KeychainTokenStore(service: service)
        let tokens = try await reader.checkedTokens()
        #expect(tokens?.accessToken == "test-access")
        #expect(tokens?.refreshToken == "test-refresh")
        await store.clear()
        #expect(try await reader.checkedTokens() == nil)
    }

    @Test("unauthorized Keychain group throws instead of claiming sign-in succeeded")
    func missingEntitlementFailsSaveAndRead() async {
        let store = KeychainTokenStore(
            service: "co.cronx.sparkapp.tests.denied.\(UUID().uuidString)",
            accessGroup: "INVALID.spark.tests.denied"
        )
        do {
            try await store.store(access: "test-access", refresh: "test-refresh", expiresIn: 3600)
            Issue.record("Saving without the required entitlement must fail")
        } catch TokenStorageError.keychain(_, let status) {
            #expect(status == errSecMissingEntitlement)
        } catch {
            Issue.record(error)
        }
        await #expect(throws: TokenStorageError.self) {
            _ = try await store.checkedTokens()
        }
        #expect(await store.tokens() == nil)
    }
}
