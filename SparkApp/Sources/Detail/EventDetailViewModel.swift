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
    private(set) var rawPayload: String?
    private var etag: String?

    private let apiClient: APIClient

    init(eventId: String, apiClient: APIClient) {
        self.eventId = eventId
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        metricBaselineStatus = nil
        do {
            let response = try await apiClient.requestWithRawResponse(EventsEndpoint.detail(id: eventId))
            let detail = response.decoded
            rawPayload = response.utf8Body
            etag = response.etag
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
        let response = try await apiClient.requestWithRawResponse(
            EventsEndpoint.updateNote(id: eventId, note: trimmed.isEmpty ? nil : trimmed)
        )
        let updated = response.decoded
        rawPayload = response.utf8Body
        etag = response.etag ?? etag
        state = .loaded(updated)
        await loadMetricBaselineStatus(for: updated)
    }

    func attachTag(_ request: TagMutationRequest) async throws {
        guard let etag else { throw TagMutationError.missingETag }
        let response = try await apiClient.requestWithRawResponse(
            TagsEndpoint.attach(kind: .events, id: eventId, request: request, etag: etag, response: EventDetail.self)
        )
        rawPayload = response.utf8Body
        self.etag = response.etag ?? etag
        state = .loaded(response.decoded)
    }

    func detachTag(_ tag: EventTag) async throws {
        guard let tagID = tag.tagID else { throw TagMutationError.missingTagID }
        guard let etag else { throw TagMutationError.missingETag }
        let response = try await apiClient.requestWithRawResponse(
            TagsEndpoint.detach(kind: .events, id: eventId, tagID: tagID, etag: etag, response: EventDetail.self)
        )
        rawPayload = response.utf8Body
        self.etag = response.etag ?? etag
        state = .loaded(response.decoded)
    }

    func createRelationship(_ request: RelationshipCreateRequest) async throws -> EntityRelationship {
        guard let etag else { throw TagMutationError.missingETag }
        let response = try await apiClient.requestWithRawResponse(
            EntityMutationsEndpoint.createRelationship(kind: .events, id: eventId, request: request, etag: etag)
        )
        self.etag = response.etag ?? etag
        return response.decoded
    }

    func deleteRelationship(_ relationshipID: String) async throws {
        guard let etag else { throw TagMutationError.missingETag }
        let response = try await apiClient.requestWithRawResponse(
            EntityMutationsEndpoint.deleteRelationship(id: relationshipID, etag: etag)
        )
        self.etag = response.etag ?? etag
    }

    func update(_ attributes: [String: AnyCodable]) async throws {
        guard let etag else { throw TagMutationError.missingETag }
        let response = try await apiClient.requestWithRawResponse(EntityMutationsEndpoint.update(kind: .events, id: eventId, attributes: attributes, etag: etag, response: EventDetail.self))
        rawPayload = response.utf8Body; self.etag = response.etag ?? etag; state = .loaded(response.decoded)
    }

    func geocode(address: String) async throws { try await updateLocation(EntityMutationsEndpoint.geocode(kind: .events, id: eventId, address: address, etag: try currentETag(), response: EventDetail.self)) }
    func setLocation(_ location: LocationRequest) async throws { try await updateLocation(EntityMutationsEndpoint.setLocation(kind: .events, id: eventId, location: location, etag: try currentETag(), response: EventDetail.self)) }
    func clearLocation() async throws { try await updateLocation(EntityMutationsEndpoint.clearLocation(kind: .events, id: eventId, etag: try currentETag(), response: EventDetail.self)) }
    private func currentETag() throws -> String { guard let etag else { throw TagMutationError.missingETag }; return etag }
    private func updateLocation(_ endpoint: Endpoint<EventDetail>) async throws { let response = try await apiClient.requestWithRawResponse(endpoint); rawPayload = response.utf8Body; etag = response.etag ?? etag; state = .loaded(response.decoded) }

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

enum TagMutationError: LocalizedError {
    case missingETag
    case missingTagID

    var errorDescription: String? {
        switch self {
        case .missingETag: "Refresh this detail before changing tags."
        case .missingTagID: "This older tag can't be removed until the detail is refreshed."
        }
    }
}
