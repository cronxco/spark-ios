import Foundation
import Observation
import OSLog
import Sentry
import SparkKit

@MainActor
@Observable
final class IntegrationDetailViewModel {
    let integrationId: String
    private(set) var state: DetailLoadState<IntegrationDetail> = .loading
    private(set) var actionInProgress: Action?
    private(set) var lastActionMessage: String?

    enum Action: Sendable, Equatable {
        case syncing
        case reauthing
    }

    private let apiClient: APIClient
    private let reauthService = IntegrationReauthService()
    private let logger = Logger(subsystem: "co.cronx.spark", category: "IntegrationDetail")

    init(integrationId: String, apiClient: APIClient) {
        self.integrationId = integrationId
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let detail = try await apiClient.request(IntegrationsEndpoint.detail(id: integrationId))
            state = .loaded(detail)
        } catch APIError.notModified {
            return
        } catch {
            SparkObservability.captureHandled(error)
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            state = .error(msg)
        }
    }

    func syncNow() async {
        actionInProgress = .syncing
        defer { actionInProgress = nil }
        do {
            _ = try await apiClient.request(IntegrationsEndpoint.syncNow(id: integrationId))
            lastActionMessage = "Sync requested."
            await load()
        } catch {
            logger.error("Sync failed: \(String(describing: error))")
            lastActionMessage = "Couldn't start sync."
            SentrySDK.capture(error: error)
        }
    }

    func reauthorise(presentationAnchor: ASPresentationAnchorHandle) async {
        actionInProgress = .reauthing
        defer { actionInProgress = nil }
        do {
            let response = try await apiClient.request(IntegrationsEndpoint.oauthStart(id: integrationId))
            try await reauthService.reauthorise(
                startURL: response.url,
                presentationAnchor: presentationAnchor.value
            )
            lastActionMessage = "Reauthorised."
            await load()
        } catch IntegrationReauthError.cancelled {
            // No-op — user closed the sheet.
        } catch {
            logger.error("Reauth failed: \(String(describing: error))")
            lastActionMessage = "Couldn't reauthorise."
            SentrySDK.capture(error: error)
        }
    }
}
