import Foundation
import Observation
import SparkKit
import SwiftData

/// Loads the forward-looking `ahead` section for a day that has not happened
/// yet, and the evening digest's open questions about it.
///
/// Same stale-while-revalidate shape as the Today page: render the cached day
/// summary at once, then revalidate against `GET /briefing/today?date=`. The
/// cache is the existing `CachedDaySummary` row for that date, so a future
/// day needs no schema of its own.
@MainActor
@Observable
final class LookingAheadViewModel {
    let date: Date
    private(set) var ahead: DayAhead?
    private(set) var questions: [FlintQuestion] = []
    private(set) var networkState: TodayNetworkState = .idle

    private let apiClient: APIClient
    private let container: ModelContainer

    init(date: Date, apiClient: APIClient, container: ModelContainer) {
        self.date = date
        self.apiClient = apiClient
        self.container = container
    }

    func load() async {
        loadCached()
        await revalidate()
        await loadQuestions()
    }

    func refresh() async {
        await revalidate(force: true)
        await loadQuestions()
    }

    func answer(question: FlintQuestion, with option: String) async {
        do {
            let response = try await apiClient.request(
                FlintEndpoint.questionAction(
                    blockID: question.id,
                    version: question.version,
                    idempotencyKey: UUID(),
                    FlintQuestionActionRequest(action: .answer, answer: option)
                )
            )
            let updated = response.data
            questions = questions.map { $0.id == updated.id ? updated : $0 }
        } catch where error.isAPICancellation {
            return
        } catch let error as APIError where error.isPreconditionFailure {
            await loadQuestions()
        } catch {
            SparkObservability.captureHandled(error)
        }
    }

    private var key: String { TodayViewModel.isoKey(for: date) }

    private func loadCached() {
        let key = key
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedDaySummary>(predicate: #Predicate { $0.date == key })
        if let cached = try? context.fetch(descriptor).first,
           let decoded = try? cached.decoded(),
           let ahead = decoded.ahead {
            self.ahead = ahead
        }
    }

    private func revalidate(force: Bool = false) async {
        if ahead == nil { networkState = .loading }
        do {
            let summary = try await apiClient.request(BriefingEndpoint.today(date: key, usesETag: ahead != nil))
            ahead = summary.ahead
            try persist(summary)
            networkState = .idle
        } catch APIError.notModified {
            networkState = .idle
        } catch where error.isAPICancellation {
            networkState = .idle
        } catch is CancellationError {
            networkState = .idle
        } catch {
            SparkObservability.captureHandled(error)
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            networkState = force || ahead == nil ? .error(message) : .idle
        }
    }

    /// The evening digest's open questions, which are the ones about this
    /// day. Nothing to ask until a digest has described the day.
    private func loadQuestions() async {
        guard let digestID = ahead?.digestEventId else {
            questions = []
            return
        }
        // A newer digest replaced the one these questions came from; don't
        // leave them answerable if the fetch below fails.
        if questions.contains(where: { $0.digestID != digestID }) {
            questions = []
        }
        do {
            let open = try await apiClient.collectAllPages(maxPages: 2) { cursor in
                FlintEndpoint.questions(statuses: [.open], since: "24h", cursor: cursor)
            }
            questions = open.filter { $0.digestID == digestID }
        } catch where error.isAPICancellation {
            return
        } catch {
            SparkObservability.captureHandled(error)
        }
    }

    private func persist(_ summary: DaySummary) throws {
        let key = key
        let context = ModelContext(container)
        let data = try JSONEncoder().encode(summary)
        let descriptor = FetchDescriptor<CachedDaySummary>(predicate: #Predicate { $0.date == key })
        if let existing = try context.fetch(descriptor).first {
            existing.payload = data
            existing.timezone = summary.timezone
            existing.lastSyncedAt = .now
        } else {
            context.insert(CachedDaySummary(date: key, timezone: summary.timezone, payload: data, lastSyncedAt: .now))
        }
        try context.save()
    }
}
