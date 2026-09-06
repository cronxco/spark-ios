import Foundation
import Observation
import SparkKit

@MainActor
@Observable
final class NotificationsPreferencesViewModel {
    private(set) var state: DetailLoadState<NotificationPreferences> = .loading
    var saveStatus: SaveStatus = .idle

    enum SaveStatus: Equatable {
        case idle
        case saving
        case saved
        case error(String)
    }

    private let apiClient: APIClient
    private var debounceTask: Task<Void, Never>?

    /// Strong user version from the last read.
    ///
    /// `PATCH /settings/notifications` is guarded by `if-match:user` and answers
    /// `428` without it — which is why every save from a shipped client failed.
    private var version: String?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let response = try await apiClient.requestWithRawResponse(
                NotificationsPreferencesEndpoint.get()
            )
            version = response.etag
            state = .loaded(response.decoded)
        } catch APIError.notModified {
            return
        } catch {
            SparkObservability.captureHandled(error)
            state = .error((error as? LocalizedError)?.errorDescription ?? String(describing: error))
        }
    }

    func updateLocal(_ prefs: NotificationPreferences) {
        state = .loaded(prefs)
        scheduleUpdate(prefs)
    }

    func scheduleUpdate(_ prefs: NotificationPreferences) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await save(prefs)
        }
    }

    private func save(_ prefs: NotificationPreferences, isRetry: Bool = false) async {
        saveStatus = .saving
        do {
            let response = try await apiClient.requestWithRawResponse(
                NotificationsPreferencesEndpoint.update(prefs, version: version)
            )
            version = response.etag
            saveStatus = .saved
            try? await Task.sleep(for: .seconds(2))
            if case .saved = saveStatus { saveStatus = .idle }
        } catch let error as APIError where error.isPreconditionFailure && !isRetry {
            // Our version is stale or absent. Re-read to pick up the current
            // one and apply the edit once against what is actually there —
            // bounded to a single retry so a persistent mismatch surfaces
            // rather than looping.
            await refreshVersion()
            await save(prefs, isRetry: true)
        } catch {
            SparkObservability.captureHandled(error)
            saveStatus = .error((error as? LocalizedError)?.errorDescription ?? String(describing: error))
        }
    }

    /// Re-reads the resource purely to refresh the stored version, leaving the
    /// user's in-flight edit in `state` untouched.
    private func refreshVersion() async {
        guard let response = try? await apiClient.requestWithRawResponse(
            NotificationsPreferencesEndpoint.get()
        ) else { return }

        version = response.etag
    }
}
