import Foundation
import Observation
import OSLog
import SparkKit

@MainActor
@Observable
final class IntegrationsListViewModel {
    enum LoadState: Sendable {
        case loading
        case loaded([Integration])
        case error(String)
    }

    private(set) var state: LoadState = .loading
    private(set) var syncingService: String?
    private(set) var syncMessage: String?

    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "Integrations")

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let response = try await apiClient.request(IntegrationsEndpoint.list())
            state = .loaded(response.data)
        } catch APIError.notModified {
            return
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Integrations list failed: \(String(describing: error))")
            let msg = (error as? LocalizedError)?.errorDescription ?? "Couldn't load integrations."
            state = .error(msg)
        }
    }

    func syncAll(service: String) async {
        syncingService = service
        defer { syncingService = nil }
        do {
            let result = try await apiClient.request(IntegrationsEndpoint.syncService(service))
            syncMessage = "\(result.totalJobsDispatched) \(result.totalJobsDispatched == 1 ? "job" : "jobs") dispatched for \(result.service)."
            await load()
        } catch {
            let detail = (error as? LocalizedError)?.errorDescription ?? "Couldn't start the sync."
            syncMessage = detail
        }
    }

    func clearSyncMessage() { syncMessage = nil }

    /// Group rows by domain bucket inferred from service slug. Lets the
    /// list view render `Form` sections per domain.
    func grouped(_ list: [Integration]) -> [(String, [Integration])] {
        let byDomain = Dictionary(grouping: list, by: { Self.domain(forService: $0.service) })
        let order = ["Health", "Money", "Media", "Knowledge", "Online", "Other"]
        return order.compactMap { domain in
            guard let items = byDomain[domain]?.sorted(by: { $0.name < $1.name }) else { return nil }
            return (domain, items)
        }
    }

    private static func domain(forService service: String) -> String {
        switch service.lowercased() {
        case "apple_health", "fitbit", "oura", "whoop", "garmin", "withings": "Health"
        case "monzo", "starling", "plaid", "amex", "stripe": "Money"
        case "spotify", "apple_music", "lastfm", "youtube", "trakt", "letterboxd": "Media"
        case "readwise", "instapaper", "raindrop", "github", "linear", "notion", "obsidian": "Knowledge"
        case "google", "fastmail", "calendar", "gmail", "icloud": "Online"
        default: "Other"
        }
    }
}
