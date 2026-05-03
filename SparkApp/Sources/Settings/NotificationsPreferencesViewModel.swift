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

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let prefs = try await apiClient.request(NotificationsPreferencesEndpoint.get())
            state = .loaded(prefs)
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

    private func save(_ prefs: NotificationPreferences) async {
        saveStatus = .saving
        do {
            _ = try await apiClient.request(NotificationsPreferencesEndpoint.update(prefs))
            saveStatus = .saved
            try? await Task.sleep(for: .seconds(2))
            if case .saved = saveStatus { saveStatus = .idle }
        } catch {
            SparkObservability.captureHandled(error)
            saveStatus = .error((error as? LocalizedError)?.errorDescription ?? String(describing: error))
        }
    }
}
