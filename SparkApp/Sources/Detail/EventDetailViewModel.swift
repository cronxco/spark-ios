import Foundation
import Observation
import SparkKit

enum DetailLoadState<T: Sendable>: Sendable {
    case loading
    case loaded(T)
    case error(String)
}

@MainActor
@Observable
final class EventDetailViewModel {
    let eventId: String
    private(set) var state: DetailLoadState<EventDetail> = .loading

    private let apiClient: APIClient

    init(eventId: String, apiClient: APIClient) {
        self.eventId = eventId
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let detail = try await apiClient.request(EventsEndpoint.detail(id: eventId))
            state = .loaded(detail)
        } catch APIError.notModified {
            // Already loaded — keep current state.
            return
        } catch {
            SparkObservability.captureHandled(error)
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            state = .error(message)
        }
    }

    func retry() async {
        await load()
    }
}
