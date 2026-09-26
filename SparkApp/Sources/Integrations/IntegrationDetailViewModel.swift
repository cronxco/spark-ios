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
    private(set) var rawPayload: String?
    private(set) var actionInProgress: Action?
    private(set) var lastActionMessage: String?

    enum Action: Sendable, Equatable {
        case syncing
        case pausing
        case reauthing
    }

    /// The detail read's version, sent as `If-Match` on sync and pause; the
    /// backend answers 428 to either without it.
    private var etag: String?

    private let apiClient: APIClient
    private let reauthService = IntegrationReauthService()
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "IntegrationDetail")

    init(integrationId: String, apiClient: APIClient) {
        self.integrationId = integrationId
        self.apiClient = apiClient
    }

    /// Keeps a loaded detail on screen while it revalidates. With nothing
    /// loaded yet there is no body for a 304 to stand for, so that first read
    /// bypasses the ETag cache rather than risk stranding the shimmer.
    func load() async {
        let hasDetail: Bool
        if case .loaded = state { hasDetail = true } else { hasDetail = false }
        if !hasDetail { state = .loading }
        do {
            let endpoint = hasDetail
                ? IntegrationsEndpoint.detail(id: integrationId)
                : IntegrationsEndpoint.detailForWrite(id: integrationId)
            let response = try await apiClient.requestWithRawResponse(endpoint)
            rawPayload = response.utf8Body
            etag = response.etag
            state = .loaded(response.decoded)
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
            _ = try await withFreshVersionOnConflict {
                try await self.apiClient.request(IntegrationsEndpoint.syncNow(id: self.integrationId, etag: self.etag))
            }
            lastActionMessage = "Update started."
            await load()
        } catch APIError.httpStatus(422, _, _) {
            lastActionMessage = "Resume this integration to update it."
        } catch {
            logger.error("Sync failed: \(String(describing: error))")
            lastActionMessage = "Couldn't start the update."
            SentrySDK.capture(error: error)
        }
    }

    func setPaused(_ paused: Bool) async {
        actionInProgress = .pausing
        defer { actionInProgress = nil }
        do {
            _ = try await withFreshVersionOnConflict {
                try await self.apiClient.request(IntegrationsEndpoint.setPaused(id: self.integrationId, paused: paused, etag: self.etag))
            }
            lastActionMessage = paused ? "Paused. Spark won't fetch until you resume it." : "Resumed."
            await load()
        } catch {
            logger.error("Pause failed: \(String(describing: error))")
            lastActionMessage = paused ? "Couldn't pause." : "Couldn't resume."
            SentrySDK.capture(error: error)
        }
    }

    /// Runs a conditional write, and if the version was missing or stale,
    /// re-reads once to pick up the current ETag and tries again. The detail
    /// stays on screen throughout; if the re-read fails, that error is
    /// thrown and the write is not retried.
    private func withFreshVersionOnConflict<T: Sendable>(_ write: @MainActor () async throws -> T) async throws -> T {
        do {
            return try await write()
        } catch let error as APIError where error.isPreconditionFailure {
            let response = try await apiClient.requestWithRawResponse(IntegrationsEndpoint.detailForWrite(id: integrationId))
            rawPayload = response.utf8Body
            etag = response.etag
            state = .loaded(response.decoded)
            return try await write()
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
