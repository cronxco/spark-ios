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
}
