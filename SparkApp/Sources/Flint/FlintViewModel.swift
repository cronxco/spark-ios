import Foundation
import Observation
import OSLog
import SparkKit

@MainActor
@Observable
final class FlintViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case empty(String)
        case error(String)
    }

    enum FlintTab: String, Identifiable, CaseIterable {
        case overview
        case questions
        case threads
        case history

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview: "Overview"
            case .questions: "Questions"
            case .threads: "Threads"
            case .history: "History"
            }
        }
    }

    /// One open question, with the digest it came from so an answer can be
    /// routed back and a time/period label shown.
    struct OpenQuestion: Identifiable {
        let question: FlintQuestion
        var block: FlintDigestBlock { question.asDigestBlock }
        var id: String { question.id }
    }

    private(set) var state: LoadState = .idle
    /// Every digest created today, newest first.
    private(set) var digests: [FlintDigest] = []
    private(set) var answeringBlockIDs: Set<String> = []
    private(set) var answerErrorByBlockID: [String: String] = [:]
    var selectedTab: FlintTab = .overview

    private(set) var questionsState: LoadState = .idle
    private(set) var questions: [FlintQuestion] = []

    private(set) var topicsState: LoadState = .idle
    private(set) var topics: [FlintTopic] = []
    private(set) var topicDetails: [String: FlintTopic] = [:]
    private(set) var topicDetailState: [String: LoadState] = [:]

    private(set) var historyState: LoadState = .idle
    private(set) var historyDigests: [FlintDigestSummary] = []
    var historyFilterDate: Date?
    private(set) var digestDetails: [String: FlintDigest] = [:]
    private(set) var digestDetailState: [String: LoadState] = [:]

    private let date: Date
    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "Flint")

    init(date: Date = .now, apiClient: APIClient) {
        self.date = date
        self.apiClient = apiClient
    }

    var openQuestions: [OpenQuestion] {
        questions.map(OpenQuestion.init(question:))
    }

    var unansweredQuestionCount: Int { openQuestions.count }

    func load() async {
        guard state == .idle else { return }
        await refresh()
    }

    func refresh() async {
        guard state != .loading else { return }
        state = .loading
        answerErrorByBlockID.removeAll()

        do {
            digests = Self.sortedNewestFirst(try await fetchDigests(date: date).map(Self.orderedDigest))
            state = digests.isEmpty ? .empty(emptyMessage) : .loaded
        } catch APIError.notModified {
            state = digests.isEmpty ? .empty(emptyMessage) : .loaded
        } catch where error.isAPICancellation {
            // Restore whatever state existing data implies — leaving this at
            // .loading would permanently wedge refresh()'s reentrancy guard.
            state = digests.isEmpty ? .idle : .loaded
        } catch where error.isNotFound {
            digests = []
            state = .empty(emptyMessage)
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Flint digest load failed: \(String(describing: error))")
            state = digests.isEmpty ? .error(userFacingError(error)) : .loaded
        }

        await loadQuestions()
        await loadTopicsIfNeeded()
    }

    // MARK: - Questions

    func loadQuestionsIfNeeded() async {
        guard questionsState == .idle else { return }
        await loadQuestions()
    }

    func loadQuestions() async {
        guard questionsState != .loading else { return }
        questionsState = .loading

        do {
            var loaded: [FlintQuestion] = []
            var cursor: String?
            var seenCursors = Set<String>()
            repeat {
                let response = try await apiClient.request(FlintEndpoint.questions(cursor: cursor))
                loaded.append(contentsOf: response.data)
                // The cursor is top-level on this endpoint. This read
                // `meta.nextCursor`, which the server never sends here, so only
                // the first page of questions ever loaded.
                cursor = response.nextCursor
                if let cursor, !seenCursors.insert(cursor).inserted { break }
            } while cursor != nil

            questions = loaded
            questionsState = loaded.isEmpty ? .empty("No open questions.") : .loaded
        } catch APIError.notModified {
            questionsState = questions.isEmpty ? .empty("No open questions.") : .loaded
        } catch where error.isAPICancellation {
            questionsState = questions.isEmpty ? .idle : .loaded
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Flint questions load failed: \(String(describing: error))")
            questionsState = questions.isEmpty ? .error(userFacingError(error)) : .loaded
        }
    }

    func question(id: String) -> FlintQuestion? {
        questions.first { $0.id == id }
    }

    // MARK: - Threads

    func loadTopicsIfNeeded() async {
        guard topicsState == .idle else { return }
        await loadTopics()
    }

    func loadTopics() async {
        topicsState = .loading
        do {
            // Topics are cursor-paged now; follow the cursor rather than
            // trusting the first page to be every thread.
            let all = try await apiClient.collectAllPages { cursor in
                FlintTopicsEndpoint.list(cursor: cursor)
            }
            topics = all.sorted {
                if $0.status?.isActive != $1.status?.isActive {
                    return $0.status?.isActive == true
                }
                return ($0.lastTouchedAt ?? .distantPast) > ($1.lastTouchedAt ?? .distantPast)
            }
            topicsState = topics.isEmpty ? .empty("No threads yet.") : .loaded
        } catch where error.isAPICancellation {
            topicsState = topics.isEmpty ? .idle : .loaded
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Flint topics load failed: \(String(describing: error))")
            topicsState = .error(userFacingError(error))
        }
    }

    func loadTopicDetail(id: String) async {
        guard topicDetails[id] == nil, topicDetailState[id] != .loading else { return }
        topicDetailState[id] = .loading
        do {
            let response = try await apiClient.request(FlintTopicsEndpoint.detail(id: id))
            topicDetails[id] = response.data
            topicDetailState[id] = .loaded
        } catch APIError.notModified {
            topicDetailState[id] = topicDetails[id] == nil ? .idle : .loaded
        } catch where error.isAPICancellation {
            topicDetailState[id] = topicDetails[id] == nil ? .idle : .loaded
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Flint topic detail load failed: \(String(describing: error))")
            topicDetailState[id] = .error(userFacingError(error))
        }
    }

    // MARK: - History

    func loadHistoryIfNeeded() async {
        guard historyState == .idle else { return }
        await loadHistory()
    }

    func loadHistory() async {
        guard historyState != .loading else { return }
        historyState = .loading

        let calendar = Calendar.current
        let fromDate = calendar.date(byAdding: .day, value: -29, to: date) ?? date

        do {
            var loaded: [FlintDigestSummary] = []
            var cursor: String?
            var seenCursors = Set<String>()
            repeat {
                let response = try await apiClient.request(FlintEndpoint.history(
                    from: Self.isoKey(for: fromDate),
                    to: Self.isoKey(for: date),
                    cursor: cursor
                ))
                loaded.append(contentsOf: response.data)
                // Top-level on the wire, like the questions cursor; reading it
                // from `meta` stopped history after the first page.
                cursor = response.nextCursor
                if let cursor, !seenCursors.insert(cursor).inserted { break }
            } while cursor != nil

            historyDigests = loaded
            historyState = loaded.isEmpty ? .empty("No Flint digests were created in the last 30 days.") : .loaded
        } catch APIError.notModified {
            historyState = historyDigests.isEmpty ? .empty("No Flint digests were created in the last 30 days.") : .loaded
        } catch where error.isAPICancellation {
            historyState = historyDigests.isEmpty ? .idle : .loaded
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Flint history load failed: \(String(describing: error))")
            historyState = historyDigests.isEmpty ? .error(userFacingError(error)) : .loaded
        }
    }

    func digest(id: String) -> FlintDigest? {
        digests.first { $0.id == id } ?? digestDetails[id]
    }

    func loadDigest(id: String) async {
        guard digest(id: id) == nil, digestDetailState[id] != .loading else { return }
        digestDetailState[id] = .loading
        do {
            digestDetails[id] = Self.orderedDigest(try await apiClient.request(FlintEndpoint.digest(id: id)))
            digestDetailState[id] = .loaded
        } catch APIError.notModified {
            digestDetailState[id] = digestDetails[id] == nil ? .idle : .loaded
        } catch where error.isAPICancellation {
            digestDetailState[id] = digestDetails[id] == nil ? .idle : .loaded
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Flint digest detail load failed: \(String(describing: error))")
            digestDetailState[id] = .error(userFacingError(error))
        }
    }

    // MARK: - Answering

    func answerQuestion(question: FlintQuestion, answer: String, note: String? = nil) async {
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAnswer.isEmpty else {
            answerErrorByBlockID[question.id] = "Enter an answer before submitting."
            return
        }

        answeringBlockIDs.insert(question.id)
        answerErrorByBlockID[question.id] = nil

        do {
            _ = try await apiClient.request(FlintEndpoint.questionAction(
                blockID: question.id,
                version: question.version,
                idempotencyKey: UUID(),
                FlintQuestionActionRequest(
                    action: .answer,
                    answer: trimmedAnswer,
                    context: trimmedNote?.isEmpty == false ? trimmedNote : nil
                )
            ))
            answeringBlockIDs.remove(question.id)
            await refresh()
        } catch where error.isAPICancellation {
            answeringBlockIDs.remove(question.id)
        } catch {
            answeringBlockIDs.remove(question.id)
            SparkObservability.captureHandled(error)
            logger.error("Flint question answer failed: \(String(describing: error))")
            answerErrorByBlockID[question.id] = userFacingAnswerError(error)
        }
    }

    func skipQuestion(_ question: FlintQuestion) async {
        answeringBlockIDs.insert(question.id)
        answerErrorByBlockID[question.id] = nil
        do {
            _ = try await apiClient.request(FlintEndpoint.questionAction(
                blockID: question.id,
                version: question.version,
                idempotencyKey: UUID(),
                FlintQuestionActionRequest(action: .skip)
            ))
            answeringBlockIDs.remove(question.id)
            await refresh()
        } catch where error.isAPICancellation {
            answeringBlockIDs.remove(question.id)
        } catch {
            answeringBlockIDs.remove(question.id)
            SparkObservability.captureHandled(error)
            logger.error("Flint question skip failed: \(String(describing: error))")
            answerErrorByBlockID[question.id] = userFacingAnswerError(error)
        }
    }

    // MARK: - Private

    private func fetchDigests(date: Date) async throws -> [FlintDigest] {
        let dateKey = Self.isoKey(for: date)
        let response = try await apiClient.request(FlintEndpoint.digests(date: dateKey, all: true))
        return response.digests
    }

    private var emptyMessage: String { emptyMessage(for: date) }

    private func emptyMessage(for date: Date) -> String {
        "No Flint digest has been created for \(date.formatted(date: .abbreviated, time: .omitted)) yet."
    }

    private func userFacingError(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Couldn't load Flint."
    }

    private func userFacingAnswerError(_ error: Error) -> String {
        if case APIError.httpStatus(403, _, _) = error {
            return "This session cannot submit Flint answers."
        }
        if case APIError.httpStatus(422, _, _) = error {
            return "Flint could not save that answer."
        }
        if case APIError.httpStatus(409, _, _) = error {
            return "That question action conflicted with an earlier submission. Refresh and try again."
        }
        if let apiError = error as? APIError, apiError.isPreconditionFailure {
            return "That question changed elsewhere. Refresh and try again."
        }
        return (error as? LocalizedError)?.errorDescription ?? "Couldn't submit your answer."
    }

    static func isoKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    private static func sortedNewestFirst(_ digests: [FlintDigest]) -> [FlintDigest] {
        digests.sorted { lhs, rhs in
            switch (lhs.createdAt, rhs.createdAt) {
            case let (lhsDate?, rhsDate?): lhsDate > rhsDate
            case (nil, _?): false
            case (_?, nil): true
            case (nil, nil): false
            }
        }
    }

    private static func orderedDigest(_ digest: FlintDigest) -> FlintDigest {
        let orderedBlocks = digest.blocks
            .enumerated()
            .sorted { lhs, rhs in
                let lhsRank = blockRank(lhs.element)
                let rhsRank = blockRank(rhs.element)
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)

        return FlintDigest(
            eventID: digest.eventID,
            digestObjectID: digest.digestObjectID,
            date: digest.date,
            period: digest.period,
            kind: digest.kind,
            title: digest.title,
            summary: digest.summary,
            createdAt: digest.createdAt,
            blockCount: digest.blockCount,
            unansweredQuestionCount: digest.unansweredQuestionCount,
            version: digest.version,
            blocks: orderedBlocks
        )
    }

    private static func blockRank(_ block: FlintDigestBlock) -> Int {
        if block.isQuestion {
            return 0
        }
        if block.blockType == "flint_editorial_note" {
            return 50
        }

        // Registered types only. The previous table ranked a dozen blocks the
        // backend has never written and left the real ones on the default.
        switch block.blockType {
        case "flint_day_context":
            return 10
        case "flint_insight", "flint_health_insight":
            return 20
        case "flint_news", "flint_reading_pick", "flint_reading_drop":
            return 30
        default:
            return 30
        }
    }
}

private extension Error {
    var isNotFound: Bool {
        if let apiError = self as? APIError,
           case APIError.httpStatus(404, _, _) = apiError {
            return true
        }
        return false
    }
}
