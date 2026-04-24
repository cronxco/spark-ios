import CryptoKit
import Foundation
import Testing
@testable import SparkKit

@Suite("PKCE")
struct PKCETests {
    @Test("verifier is URL-safe base64 without padding and 43+ chars")
    func verifierShape() {
        for _ in 0 ..< 16 {
            let verifier = PKCE.generateVerifier()
            #expect(verifier.count >= 43)
            #expect(!verifier.contains("+"))
            #expect(!verifier.contains("/"))
            #expect(!verifier.contains("="))
        }
    }

    @Test("verifiers are unique across calls")
    func verifiersAreUnique() {
        let batch = (0 ..< 64).map { _ in PKCE.generateVerifier() }
        #expect(Set(batch).count == batch.count)
    }

    @Test("challenge is base64url(SHA256(verifier))")
    func challengeMatchesS256() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let expected = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        #expect(PKCE.challenge(for: verifier) == expected)
    }

    @Test("state is non-empty and unique")
    func stateIsUnique() {
        let batch = (0 ..< 32).map { _ in PKCE.generateState() }
        #expect(batch.allSatisfy { !$0.isEmpty })
        #expect(Set(batch).count == batch.count)
    }
}
