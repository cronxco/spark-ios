import Foundation
import Observation
import SparkKit

@MainActor
@Observable
final class ApiTokensViewModel {
    private(set) var state: DetailLoadState<[ApiToken]> = .loading
    var newTokenName: String = ""
    var newTokenAbilities: [String] = ["mcp:read"]
    var createdToken: CreatedApiToken?
    var isCreating: Bool = false
    var createError: String?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let tokens = try await apiClient.request(ApiTokensEndpoint.list())
            state = .loaded(tokens)
        } catch APIError.notModified {
            return
        } catch {
            SparkObservability.captureHandled(error)
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            state = .error(message)
        }
    }

    func create() async {
        guard !newTokenName.isEmpty else { return }
        isCreating = true
        createError = nil
        defer { isCreating = false }
        do {
            let token = try await apiClient.request(
                ApiTokensEndpoint.create(name: newTokenName, abilities: newTokenAbilities)
            )
            createdToken = token
            newTokenName = ""
            newTokenAbilities = ["mcp:read"]
            await load()
        } catch {
            SparkObservability.captureHandled(error)
            createError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}
