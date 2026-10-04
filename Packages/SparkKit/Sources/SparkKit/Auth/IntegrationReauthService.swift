import Foundation
@preconcurrency import AuthenticationServices

public enum IntegrationReauthError: Error, Sendable {
    case cancelled
    case invalidCallback
    case providerRejected
    case couldNotStart
    case underlying(Error)
}

/// Wraps `ASWebAuthenticationSession` for per-integration OAuth re-authorisation.
/// Same strong-reference dance as `AuthenticationService` — the session and
/// presentation anchor provider must outlive the call to `start()`.
public final class IntegrationReauthService: NSObject, Sendable {
    private let callbackScheme = "spark"

    nonisolated(unsafe) private var activeSession: ASWebAuthenticationSession?
    nonisolated(unsafe) private var activeAnchorProvider: AnchorProvider?

    public override init() { super.init() }

    @MainActor
    public func reauthorise(
        startURL: URL,
        expectedAttemptID: String? = nil,
        presentationAnchor: ASPresentationAnchor
    ) async throws {
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: startURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] url, error in
                self?.activeSession = nil
                self?.activeAnchorProvider = nil
                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: IntegrationReauthError.cancelled)
                    } else {
                        continuation.resume(throwing: IntegrationReauthError.underlying(error))
                    }
                    return
                }
                guard let url else {
                    continuation.resume(throwing: IntegrationReauthError.invalidCallback)
                    return
                }
                continuation.resume(returning: url)
            }
            let anchorProvider = AnchorProvider(anchor: presentationAnchor)
            session.presentationContextProvider = anchorProvider
            session.prefersEphemeralWebBrowserSession = false
            activeAnchorProvider = anchorProvider
            activeSession = session
            guard session.start() else {
                activeSession = nil
                activeAnchorProvider = nil
                continuation.resume(throwing: IntegrationReauthError.couldNotStart)
                return
            }
        }
        try Self.validateCallback(callback, expectedAttemptID: expectedAttemptID)
    }

    public static func validateCallback(_ url: URL, expectedAttemptID: String? = nil) throws {
        guard url.scheme == "spark", url.host == "integrations", url.path == "/reauth-complete",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw IntegrationReauthError.invalidCallback
        }
        let items = components.queryItems ?? []
        let statuses = items.filter { $0.name == "status" }
        guard statuses.count == 1, let status = statuses.first?.value else {
            throw IntegrationReauthError.invalidCallback
        }
        if let expectedAttemptID {
            let attempts = items.filter { $0.name == "attempt_id" }
            guard attempts.count == 1, attempts.first?.value == expectedAttemptID else {
                throw IntegrationReauthError.invalidCallback
            }
        }
        guard status == "success" else {
            if status == "error" { throw IntegrationReauthError.providerRejected }
            throw IntegrationReauthError.invalidCallback
        }
    }
}

private final class AnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}
