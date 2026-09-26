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

    /// Stale-while-revalidate: once a list is on screen it stays there while
    /// the refresh runs, and a failed refresh keeps it rather than blanking it.
    func load() async {
        let previousState = state
        if case .loaded = previousState {} else { state = .loading }
        do {
            let response = try await apiClient.request(IntegrationsEndpoint.list())
            state = .loaded(response.data)
        } catch APIError.notModified {
            state = previousState
            return
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Integrations list failed: \(String(describing: error))")
            if case .loaded = previousState {
                state = previousState
                return
            }
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

    /// How many integrations need someone to act, for the list's summary line.
    func attentionCount(_ list: [Integration]) -> Int {
        list.filter { $0.statusKind.needsAttention }.count
    }

    /// Group rows by the plugin domain the backend reports, falling back to a
    /// slug guess for older backends that don't send one. Within a group,
    /// integrations needing attention come first.
    func grouped(_ list: [Integration]) -> [(String, [Integration])] {
        let byDomain = Dictionary(grouping: list, by: { Self.domainTitle(for: $0) })
        let order = ["Health", "Activity", "Money", "Media", "Knowledge", "Online", "Other"]
        return order.compactMap { domain in
            guard let items = byDomain[domain] else { return nil }
            let sorted = items.sorted { lhs, rhs in
                if lhs.statusKind.needsAttention != rhs.statusKind.needsAttention {
                    return lhs.statusKind.needsAttention
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return (domain, sorted)
        }
    }

    private static func domainTitle(for integration: Integration) -> String {
        let domain = (integration.domain ?? legacyDomain(forService: integration.service)).lowercased()
        switch domain {
        case "health": return "Health"
        case "activity": return "Activity"
        case "money": return "Money"
        case "media": return "Media"
        case "knowledge": return "Knowledge"
        case "online": return "Online"
        default: return "Other"
        }
    }

    private static func legacyDomain(forService service: String) -> String {
        switch service.lowercased() {
        case "apple_health", "fitbit", "oura", "whoop", "garmin", "withings": "health"
        case "monzo", "starling", "plaid", "amex", "stripe": "money"
        case "spotify", "apple_music", "lastfm", "youtube", "trakt", "letterboxd": "media"
        case "readwise", "instapaper", "raindrop", "github", "linear", "notion", "obsidian": "knowledge"
        case "google", "fastmail", "calendar", "gmail", "icloud": "online"
        default: "other"
        }
    }
}
