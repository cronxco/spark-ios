import Foundation
import Observation
import SparkKit

@MainActor
@Observable
final class DevicesViewModel {
    private(set) var state: DetailLoadState<[RegisteredDevice]> = .loading

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let devices = try await apiClient.request(DevicesEndpoint.list())
            state = .loaded(devices)
        } catch APIError.notModified {
            return
        } catch {
            SparkObservability.captureHandled(error)
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            state = .error(message)
        }
    }

    func revoke(_ device: RegisteredDevice) async {
        guard case .loaded(var devices) = state else { return }
        devices.removeAll { $0.id == device.id }
        state = .loaded(devices)
        do {
            _ = try await apiClient.request(DevicesEndpoint.revoke(id: device.id))
        } catch {
            SparkObservability.captureHandled(error)
            await load()
        }
    }
}
