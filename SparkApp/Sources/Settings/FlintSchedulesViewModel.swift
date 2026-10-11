import Foundation
import Observation
import SparkKit

@MainActor
@Observable
final class FlintSchedulesViewModel {
    private(set) var state: DetailLoadState<[FlintRoutineSchedule]> = .loading
    /// The routine currently being saved, if any.
    private(set) var savingRoutine: String?
    /// The last server refusal per routine, shown beside its editor. A malformed time or cron is
    /// refused by the backend, so nothing invalid is stored.
    private(set) var errors: [String: String] = [:]
    private(set) var savedRoutine: String?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        do {
            let response = try await apiClient.request(FlintSchedulesEndpoint.list())
            state = .loaded(response.routines)
        } catch APIError.notModified {
            return
        } catch {
            SparkObservability.captureHandled(error)
            state = .error((error as? LocalizedError)?.errorDescription ?? String(describing: error))
        }
    }

    func save(routine: FlintRoutineSchedule, enabled: Bool, schedule: FlintSchedule) async {
        savingRoutine = routine.routine
        errors[routine.routine] = nil
        savedRoutine = nil
        defer { savingRoutine = nil }
        do {
            let response = try await apiClient.request(
                FlintSchedulesEndpoint.update(routine: routine.routine, enabled: enabled, schedule: schedule)
            )
            if case .loaded(var routines) = state, let index = routines.firstIndex(where: { $0.routine == routine.routine }) {
                routines[index] = response.routine
                state = .loaded(routines)
            }
            savedRoutine = routine.routine
        } catch {
            SparkObservability.captureHandled(error)
            errors[routine.routine] = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}
