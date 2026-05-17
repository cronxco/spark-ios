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

    enum PeriodSelection: String, Identifiable {
        case latest
        case morning
        case afternoon
        case evening

        var id: String { rawValue }

        var title: String {
            switch self {
            case .latest: "Latest"
            case .morning: "Morning"
            case .afternoon: "Afternoon"
            case .evening: "Evening"
            }
        }

        var apiPeriod: FlintDigestPeriod? {
            switch self {
            case .morning: .morning
            case .afternoon: .afternoon
            case .evening: .evening
            case .latest: nil
            }
        }

        init?(period: FlintDigestPeriod) {
            switch period {
            case .morning:
                self = .morning
            case .afternoon:
                self = .afternoon
            case .evening:
                self = .evening
            }
        }
    }

    private(set) var state: LoadState = .idle
    private(set) var digests: [FlintDigest] = []
    private(set) var availablePeriodSelections: [PeriodSelection] = [.latest]
    private(set) var answeringBlockIDs: Set<String> = []
    private(set) var answerErrorByBlockID: [String: String] = [:]
    var selectedPeriod: PeriodSelection = .latest

    private let date: Date
    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "Flint")

    init(date: Date = .now, apiClient: APIClient) {
        self.date = date
        self.apiClient = apiClient
    }

    var unansweredQuestionCount: Int {
        digests.reduce(0) { total, digest in
            total + digest.blocks.filter { $0.isQuestion && !$0.answered }.count
        }
    }

    func load() async {
        guard state == .idle else { return }
        await refresh()
    }

    func refresh() async {
        state = .loading
        answerErrorByBlockID.removeAll()

        do {
            let loaded = try await fetchDigests()
            applyLoadedDigests(loaded)
        } catch APIError.notModified {
            state = digests.isEmpty ? .empty(emptyMessage) : .loaded
        } catch where error.isAPICancellation {
            if digests.isEmpty {
                state = .idle
            }
        } catch where error.isNotFound {
            digests = []
            availablePeriodSelections = [.latest]
            selectedPeriod = .latest
            state = .empty(emptyMessage)
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Flint digest load failed: \(String(describing: error))")
            if digests.isEmpty {
                state = .error(userFacingError(error))
            } else {
                state = .loaded
            }
        }
    }

    func selectPeriod(_ period: PeriodSelection) async {
        guard selectedPeriod != period else { return }
        guard availablePeriodSelections.contains(period) else { return }
        selectedPeriod = period
        await refresh()
    }

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

    private func fetchDigests() async throws -> [FlintDigest] {
        let dateKey = Self.isoKey(for: date)
        let response = try await apiClient.request(FlintEndpoint.digests(date: dateKey, all: true))
        return response.digests
    }

    private func applyLoadedDigests(_ loaded: [FlintDigest]) {
        let ordered = loaded.map(Self.orderedDigest)
        availablePeriodSelections = Self.availableSelections(for: ordered)

        if !availablePeriodSelections.contains(selectedPeriod) {
            selectedPeriod = .latest
        }

        digests = Self.visibleDigests(from: ordered, selectedPeriod: selectedPeriod)
        state = digests.isEmpty ? .empty(emptyMessage) : .loaded
    }

    private var emptyMessage: String {
        switch selectedPeriod {
        case .latest:
            "No Flint digest has been created for today yet."
        case .morning, .afternoon, .evening:
            "No \(selectedPeriod.title.lowercased()) digest has been created for today yet."
        }
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

    private static func availableSelections(for digests: [FlintDigest]) -> [PeriodSelection] {
        let availablePeriods = Set(digests.compactMap(\.period))
        let periodSelections = FlintDigestPeriod.allCases.compactMap { period -> PeriodSelection? in
            guard availablePeriods.contains(period) else { return nil }
            return PeriodSelection(period: period)
        }

        return [.latest] + periodSelections
    }

    private static func visibleDigests(
        from digests: [FlintDigest],
        selectedPeriod: PeriodSelection
    ) -> [FlintDigest] {
        switch selectedPeriod {
        case .latest:
            guard let latest = latestDigest(from: digests) else { return [] }
            return [latest]
        case .morning, .afternoon, .evening:
            guard let period = selectedPeriod.apiPeriod else { return [] }
            return digests.filter { $0.period == period }
        }
    }

    private static func latestDigest(from digests: [FlintDigest]) -> FlintDigest? {
        digests.max { lhs, rhs in
            switch (lhs.createdAt, rhs.createdAt) {
            case let (lhsDate?, rhsDate?):
                return lhsDate < rhsDate
            case (nil, _?):
                return true
            case (_?, nil):
                return false
            case (nil, nil):
                return false
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
