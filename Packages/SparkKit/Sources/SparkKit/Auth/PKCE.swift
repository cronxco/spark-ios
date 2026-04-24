import CryptoKit
import Foundation

/// Generates PKCE verifier/challenge pairs for the OAuth authorisation-code
/// grant used by the Spark backend. Follows RFC 7636 — S256 challenges only.
public enum PKCE {
    /// 32 bytes → 43-char URL-safe string (well within the 43–128 range).
    public static func generateVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Failed to generate PKCE verifier")
        return Data(bytes).base64URLEncodedString()
    }

    /// S256 challenge = `base64url(sha256(verifier))`.
    public static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    public static func generateState() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
