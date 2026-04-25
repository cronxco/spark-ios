import Foundation
@preconcurrency import AuthenticationServices
import UIKit

public enum AuthenticationError: Error, Sendable {
    case cancelled
    case missingCode
    case stateMismatch
    case invalidCallback
    case underlying(Error)
}

/// Runs the `ASWebAuthenticationSession` flow against Laravel's OAuth endpoints,
/// exchanges the resulting authorisation code for a Sanctum token, and persists
/// the tokens to the shared `KeychainTokenStore`.
public final class AuthenticationService: NSObject, Sendable {
    private let environment: APIEnvironment
    private let tokenStore: KeychainTokenStore
    private let apiClient: APIClient
    private let callbackScheme = "spark"
    // Retained for the duration of the OAuth web session; released on completion.
    nonisolated(unsafe) private var activeSession: ASWebAuthenticationSession?

    public init(
        environment: APIEnvironment = .current(),
        tokenStore: KeychainTokenStore,
        apiClient: APIClient
    ) {
        self.environment = environment
        self.tokenStore = tokenStore
        self.apiClient = apiClient
    }

    @MainActor
    public func signIn(presentationAnchor: ASPresentationAnchor) async throws {
        let verifier = PKCE.generateVerifier()
        let challenge = PKCE.challenge(for: verifier)
        let state = PKCE.generateState()
        let deviceName = UIDevice.current.name
        let authorizeURL = buildAuthorizeURL(challenge: challenge, state: state, deviceName: deviceName)

        let callbackURL: URL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authorizeURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] url, error in
                self?.activeSession = nil
                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthenticationError.cancelled)
                    } else {
                        continuation.resume(throwing: AuthenticationError.underlying(error))
                    }
                    return
                }
                guard let url else {
                    continuation.resume(throwing: AuthenticationError.invalidCallback)
                    return
                }
                continuation.resume(returning: url)
            }
            session.presentationContextProvider = AnchorProvider(anchor: presentationAnchor)
            session.prefersEphemeralWebBrowserSession = false
            activeSession = session
            session.start()
        }

        let (code, returnedState) = try parseCallback(callbackURL)
        guard returnedState == state else {
            throw AuthenticationError.stateMismatch
        }
        let tokens = try await apiClient.requestSiteRoot(
            AuthEndpoint.exchange(code: code, verifier: verifier)
        )
        await tokenStore.store(
            access: tokens.accessToken,
            refresh: tokens.refreshToken,
            expiresIn: tokens.expiresIn
        )
    }

    public func signOut() async {
        await tokenStore.clear()
    }

    // MARK: - Helpers

    private func buildAuthorizeURL(challenge: String, state: String, deviceName: String) -> URL {
        var components = URLComponents(url: environment.oauthAuthorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "client_id", value: "ios"),
            .init(name: "redirect_uri", value: "spark://auth/callback"),
            .init(name: "response_type", value: "code"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "device_name", value: deviceName),
        ]
        return components.url!
    }

    private func parseCallback(_ url: URL) throws -> (code: String, state: String?) {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw AuthenticationError.missingCode
        }
        let state = components.queryItems?.first(where: { $0.name == "state" })?.value
        return (code, state)
    }
}

private final class AnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}
