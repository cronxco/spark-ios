import Foundation
import Observation
import SparkKit

@MainActor
@Observable
final class ProfileViewModel {
    private(set) var state: DetailLoadState<UserProfile> = .loading

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let profile = try await apiClient.request(MeEndpoint.get())
            state = .loaded(profile)
        } catch APIError.notModified {
            return
        } catch {
            SparkObservability.captureHandled(error)
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            state = .error(message)
        }
    }
}
