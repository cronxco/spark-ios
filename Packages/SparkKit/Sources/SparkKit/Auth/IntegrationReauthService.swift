import Foundation
@preconcurrency import AuthenticationServices

public enum IntegrationReauthError: Error, Sendable {
    case cancelled
    case invalidCallback
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
        presentationAnchor: ASPresentationAnchor
    ) async throws {
        let _: URL = try await withCheckedThrowingContinuation { continuation in
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
            session.start()
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
