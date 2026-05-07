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
    private(set) var metricBaselineStatus: MetricBaselineStatus?

    private let apiClient: APIClient

    init(eventId: String, apiClient: APIClient) {
        self.eventId = eventId
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        metricBaselineStatus = nil
        do {
            let detail = try await apiClient.request(EventsEndpoint.detail(id: eventId))
            state = .loaded(detail)
            await loadMetricBaselineStatus(for: detail)
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

    func saveNote(_ note: String) async throws {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = try await apiClient.request(
            EventsEndpoint.updateNote(id: eventId, note: trimmed.isEmpty ? nil : trimmed)
        )
        state = .loaded(updated)
        await loadMetricBaselineStatus(for: updated)
    }

    private func loadMetricBaselineStatus(for detail: EventDetail) async {
        let identifier = MetricIdentifier.from(event: detail.event)
        guard MetricIdentifier.split(identifier) != nil else { return }
        do {
            let metric = try await apiClient.request(MetricsEndpoint.detail(identifier: identifier))
            metricBaselineStatus = MetricBaselineStatus.make(
                event: detail.event,
                metric: metric,
                metricIdentifier: identifier
            )
        } catch APIError.notModified {
            return
        } catch APIError.httpStatus(404, _, _) {
            metricBaselineStatus = nil
        } catch {
            SparkObservability.captureHandled(error)
            metricBaselineStatus = nil
        }
    }
}
