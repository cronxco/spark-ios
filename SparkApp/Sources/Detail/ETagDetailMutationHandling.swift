import SparkKit

/// Shared conditional-mutation handling for entity detail view models.
@MainActor
protocol ETagDetailMutationHandling: AnyObject {
    associatedtype Detail: Decodable & Sendable

    var apiClient: APIClient { get }
    var rawPayload: String? { get set }
    var etag: String? { get set }
    var state: DetailLoadState<Detail> { get set }
}

extension ETagDetailMutationHandling {
    func currentETag() throws -> String {
        guard let etag else { throw TagMutationError.missingETag }
        return etag
    }

    func applyMutation(_ endpoint: Endpoint<Detail>) async throws {
        let currentETag = try currentETag()
        let response = try await apiClient.requestWithRawResponse(endpoint)
        rawPayload = response.utf8Body
        etag = response.etag ?? currentETag
        state = .loaded(response.decoded)
    }

    /// Re-read the entity after a write that changed its version without
    /// returning it, so the next conditional write is not made with a stale ETag.
    func refreshVersion(_ endpoint: Endpoint<Detail>) async throws {
        let response = try await apiClient.requestWithRawResponse(endpoint)
        rawPayload = response.utf8Body
        etag = response.etag
        state = .loaded(response.decoded)
    }

    /// Adopt the parent version a relationship create returned, or re-read it.
    func adoptVersion(after relationship: EntityRelationship, kind: SparkEntityKind, id: String) async throws {
        if let refreshed = relationship.versions?.etag(for: kind, id: id) {
            etag = refreshed
        } else {
            try await refreshVersion(EntityMutationsEndpoint.detailForWrite(kind: kind, id: id, response: Detail.self))
        }
    }

    /// Delete an edge with its own version, then refresh the parent's, which the delete changed.
    func deleteRelationship(_ relationship: EntityRelationship, kind: SparkEntityKind, id: String) async throws {
        guard let relationshipETag = relationship.etag else { throw TagMutationError.missingETag }
        _ = try await apiClient.requestWithRawResponse(
            EntityMutationsEndpoint.deleteRelationship(id: relationship.id, etag: relationshipETag)
        )
        try await refreshVersion(EntityMutationsEndpoint.detailForWrite(kind: kind, id: id, response: Detail.self))
    }
}
