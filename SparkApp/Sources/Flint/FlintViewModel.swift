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
        case today
        case questions
        case threads
        case archive

        var id: String { rawValue }

        var title: String {
            switch self {
            case .today: "Today"
            case .questions: "Questions"
            case .threads: "Threads"
            case .archive: "Archive"
            }
        }
    }

    /// One open question, with the digest it came from so an answer can be
    /// routed back and a time/period label shown.
    struct OpenQuestion: Identifiable {
        let digest: FlintDigest
        let block: FlintDigestBlock
        var id: String { block.id }
    }

    private(set) var state: LoadState = .idle
    /// Every digest created today, newest first.
    private(set) var digests: [FlintDigest] = []
    private(set) var answeringBlockIDs: Set<String> = []
    private(set) var answerErrorByBlockID: [String: String] = [:]
    var selectedTab: FlintTab = .today

    private(set) var topicsState: LoadState = .idle
    private(set) var topics: [FlintTopic] = []

    var archiveDate: Date = .now
    private(set) var archiveState: LoadState = .idle
    private(set) var archiveDigests: [FlintDigest] = []

    private let date: Date
    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "Flint")

    init(date: Date = .now, apiClient: APIClient) {
        self.date = date
        self.apiClient = apiClient
    }

    var openQuestions: [OpenQuestion] {
        digests.flatMap { digest in
            digest.blocks
                .filter { $0.isQuestion && !$0.answered }
                .map { OpenQuestion(digest: digest, block: $0) }
        }
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
            if digests.isEmpty { state = .idle }
        } catch where error.isNotFound {
            digests = []
            state = .empty(emptyMessage)
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Flint digest load failed: \(String(describing: error))")
            state = digests.isEmpty ? .error(userFacingError(error)) : .loaded
        }

        await loadTopicsIfNeeded()
    }

    // MARK: - Threads

    func loadTopicsIfNeeded() async {
        guard topicsState == .idle else { return }
        await loadTopics()
    }

    func loadTopics() async {
        topicsState = .loading
        do {
            let response = try await apiClient.request(FlintTopicsEndpoint.list())
            topics = response.data.sorted { ($0.lastTouchedAt ?? .distantPast) > ($1.lastTouchedAt ?? .distantPast) }
            topicsState = topics.isEmpty ? .empty("No threads yet.") : .loaded
        } catch where error.isAPICancellation {
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Flint topics load failed: \(String(describing: error))")
            topicsState = .error(userFacingError(error))
        }
    }

    // MARK: - Archive

    /// Picking a new date while a previous fetch is still in flight can let
    /// the two resume out of order — guard every mutation after the `await`
    /// on `date` still being the one currently selected, so a slow response
    /// for an old pick can't clobber a faster one for a newer pick.
    func selectArchiveDate(_ date: Date) async {
        archiveDate = date
        archiveState = .loading
        do {
            let loaded = try await fetchDigests(date: date).map(Self.orderedDigest)
            guard date == archiveDate else { return }
            archiveDigests = Self.sortedNewestFirst(loaded)
            archiveState = archiveDigests.isEmpty ? .empty(emptyMessage(for: date)) : .loaded
        } catch where error.isAPICancellation {
        } catch where error.isNotFound {
            guard date == archiveDate else { return }
            archiveDigests = []
            archiveState = .empty(emptyMessage(for: date))
        } catch {
            guard date == archiveDate else { return }
            SparkObservability.captureHandled(error)
            archiveState = .error(userFacingError(error))
        }
    }

    // MARK: - Answering

    func answerQuestion(block: FlintDigestBlock, answer: String, note: String? = nil) async {
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAnswer.isEmpty else {
            answerErrorByBlockID[block.id] = "Enter an answer before submitting."
            return
        }

        answeringBlockIDs.insert(block.id)
        answerErrorByBlockID[block.id] = nil

        do {
            _ = try await apiClient.request(FlintEndpoint.answerQuestion(
                blockID: block.id,
                FlintQuestionAnswerRequest(
                    answer: trimmedAnswer,
                    answerNote: trimmedNote?.isEmpty == false ? trimmedNote : nil
                )
            ))
            answeringBlockIDs.remove(block.id)
            await refresh()
        } catch where error.isAPICancellation {
            answeringBlockIDs.remove(block.id)
        } catch {
            answeringBlockIDs.remove(block.id)
            SparkObservability.captureHandled(error)
            logger.error("Flint question answer failed: \(String(describing: error))")
            answerErrorByBlockID[block.id] = userFacingAnswerError(error)
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
            title: digest.title,
            summary: digest.summary,
            createdAt: digest.createdAt,
            blockCount: digest.blockCount,
            unansweredQuestionCount: digest.unansweredQuestionCount,
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

        switch block.blockType {
        case "flint_urgent_alert", "flint_prioritized_action":
            return 10
        case "flint_health_insight",
             "flint_money_insight",
             "flint_media_insight",
             "flint_knowledge_insight",
             "flint_online_insight",
             "flint_cross_domain_insight",
             "flint_pattern_detected",
             "flint_correlation",
             "flint_coaching_insight":
            return 20
        case "flint_digest", "flint_news_briefing", "flint_articles_waiting":
            return 30
        case "flint_coaching_check_in":
            return 40
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
