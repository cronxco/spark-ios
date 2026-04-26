import Foundation
import Observation
import Sentry
import SparkKit
import SwiftData

enum SessionState: Equatable {
    case unknown
    case loggedOut
    case loggedIn
}

enum AppRoute: Hashable {
    case today(date: Date?)
    case day(Date)
    case event(id: String)
    case object(id: String)
    case block(id: String)
    case metric(identifier: String)
    case place(id: String)
    case integration(service: String)
}

@MainActor
@Observable
final class AppModel {
    static let shared: AppModel = {
        // `AppModel.shared` throws in a non-runtime context would be worse than
        // falling back to an in-memory container — the container only matters
        // on a real device where the App Group is reachable. Simulator test
        // runs without entitlements should still render.
        let container: ModelContainer
        do {
            container = try SparkDataStore.makeContainer()
        } catch {
            container = (try? SparkDataStore.makeInMemoryContainer()) ?? {
                fatalError("Unable to bootstrap any SwiftData container: \(error)")
            }()
        }
        return AppModel(container: container)
    }()

    let container: ModelContainer
    let tokenStore: KeychainTokenStore
    let etagCache: ETagCache
    let apiClient: APIClient
    let authService: AuthenticationService

    var session: SessionState = .unknown
    var lastError: String?
    var pendingRoute: AppRoute?

    init(container: ModelContainer) {
        self.container = container
        let tokenStore = KeychainTokenStore()
        let etagCache = ETagCache()
        let client = APIClient(tokenStore: tokenStore, etagCache: etagCache)
        self.tokenStore = tokenStore
        self.etagCache = etagCache
        self.apiClient = client
        self.authService = AuthenticationService(tokenStore: tokenStore, apiClient: client)
    }

    func bootstrap() async {
        if await tokenStore.accessToken() != nil {
            session = .loggedIn
        } else {
            session = .loggedOut
        }
    }

    func signIn(anchor: ASPresentationAnchorHandle) async {
        do {
            try await authService.signIn(presentationAnchor: anchor.value)
            session = .loggedIn
            lastError = nil
        } catch AuthenticationError.cancelled {
            lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            if case let APIError.httpStatus(status, _, url) = error {
                SentrySDK.capture(message: "Auth sign-in HTTP error \(status) at \(url.absoluteString)")
            }
            SentrySDK.capture(error: error)
        }
    }

    func signOut() async {
        await authService.signOut()
        await etagCache.clearAll()
        session = .loggedOut
    }
}

#if canImport(UIKit)
import AuthenticationServices
import UIKit

/// Thin wrapper around `ASPresentationAnchor` so the model stays UIKit-agnostic
/// for testability while still giving `AuthenticationService` the window it
/// needs.
struct ASPresentationAnchorHandle {
    let value: ASPresentationAnchor

    @MainActor
    static func current() -> ASPresentationAnchorHandle? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard
            let anchor = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
                ?? scenes.first.map(UIWindow.init(windowScene:))
        else { return nil }
        return .init(value: anchor)
    }
}
#endif
