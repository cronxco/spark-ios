import Foundation
import Observation
import SparkKit
import SwiftData

@MainActor
@Observable
final class UpToSpeedViewModel {
    private(set) var screens: [UpToSpeedScreen] = []
    var currentIndex: Int = 0
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var newItemsAvailable: Int = 0

    private var allItems: [UpToSpeedItem] = []
    private var snapshotCount: Int = 0
    private var pendingReadRefs: [UpToSpeedReadRef] = []
    private(set) var scrolledToBottomIndices: Set<Int> = []

    // itemID → ordered list of question blockIDs for that digest
    private var digestQuestionMap: [String: [String]] = [:]
    // blockIDs already answered (server-side on load, or in-session)
    private var answeredQuestionIDs: Set<String> = []

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        error = nil
        do {
            let response = try await apiClient.request(UpToSpeedEndpoint.feed())
            allItems = response.items
            let digests = await preloadDigests(for: visibleUnreadItems(from: allItems))
            buildScreenQueue(digests: digests)
        } catch is CancellationError {
        } catch APIError.transport(let underlying)
            where (underlying as? URLError)?.code == .cancelled {
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    /// Reloads the queue from scratch — re-fetches, resets to index 0, clears badge.
    func reloadQueue() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            let response = try await apiClient.request(UpToSpeedEndpoint.feed())
            allItems = response.items
            let digests = await preloadDigests(for: visibleUnreadItems(from: allItems))
            buildScreenQueue(digests: digests)
        } catch {}
        isLoading = false
    }

    /// Re-fetches the feed to detect newly arrived items; updates newItemsAvailable badge.
    func refreshFeed() async {
        guard !isLoading else { return }
        do {
            let response = try await apiClient.request(UpToSpeedEndpoint.feed())
            let freshUnread = visibleUnreadItems(from: response.items).count
            newItemsAvailable = max(0, freshUnread - snapshotCount)
            allItems = response.items
        } catch {}
    }

    // MARK: - Navigation

    func advance() {
        markCurrentRead()
        if currentIndex < screens.count - 1 {
            currentIndex += 1
        }
    }

    func goBack() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }

    func markCurrentRead() {
        markRead(at: currentIndex)
    }

    func markRead(at index: Int) {
        guard let screen = screens[safe: index] else { return }
        switch screen {
        case .flintHeader, .flintParagraph, .flintInsight, .flintQuestion:
            let itemID = screen.item.id
            let isLastPageForItem = screens[safe: index + 1]?.item.id != itemID
            if isLastPageForItem && digestCanBeMarkedRead(itemID: itemID) {
                enqueueMarkRead(itemID: itemID, type: .flintDigest)
            }
        case .checkIn:
            break // uses CheckInsEndpoint.submit as its read signal
        case .anomaly:
            break // marked via markAnomalyRead when user acknowledges
        case .newsSummary(let item):
            guard scrolledToBottomIndices.contains(index) else { return }
            enqueueMarkRead(itemID: item.id, type: .newsSummary)
        }
    }

    /// Called by AnomalyScreen when the user acknowledges or suppresses an anomaly.
    func markAnomalyRead(itemID: String) {
        enqueueMarkRead(itemID: itemID, type: .anomaly)
    }

    func markScrolledToBottom(at index: Int) {
        scrolledToBottomIndices.insert(index)
    }

    /// Called by FlintQuestionPage after a successful answer submission.
    /// Marks the digest as caught-up once all its questions are answered.
    func onQuestionAnswered(blockID: String, itemID: String) {
        answeredQuestionIDs.insert(blockID)
        let allIDs = digestQuestionMap[itemID] ?? []
        guard !allIDs.isEmpty else { return }
        if allIDs.allSatisfy({ answeredQuestionIDs.contains($0) }) {
            enqueueMarkRead(itemID: itemID, type: .flintDigest)
        }
    }

    /// Flush pending markRead refs on dismiss. Call from the stories view on close.
    func flush() {
        guard !pendingReadRefs.isEmpty else { return }
        let refs = pendingReadRefs
        Task {
            try? await apiClient.request(UpToSpeedEndpoint.markRead(refs))
        }
        pendingReadRefs = []
    }

    // MARK: - Unread count

    var unreadCount: Int {
        visibleUnreadItems(from: allItems).count
    }

    // MARK: - Private

    private func preloadDigests(for items: [UpToSpeedItem]) async -> [String: FlintDigest] {
        let flintItems = items.filter { $0.type == .flintDigest }
        guard !flintItems.isEmpty else { return [:] }
        let client = apiClient
        var result: [String: FlintDigest] = [:]
        await withTaskGroup(of: (String, FlintDigest?).self) { group in
            for item in flintItems {
                let itemID = item.id
                group.addTask {
                    let digest = try? await client.request(FlintEndpoint.digest(id: itemID))
                    return (itemID, digest)
                }
            }
            for await (id, digest) in group {
                if let digest { result[id] = digest }
            }
        }
        return result
    }

    private func buildScreenQueue(digests: [String: FlintDigest] = [:]) {
        digestQuestionMap = [:]
        answeredQuestionIDs = []
        scrolledToBottomIndices = []
        let unread = visibleUnreadItems(from: allItems)
        snapshotCount = unread.count
        screens = unread.flatMap { item -> [UpToSpeedScreen] in
            switch item.payload {
            case .flintDigest(let summary):
                return expandFlintItem(item: item, summary: summary, digest: digests[item.id])
            case .checkIn:
                return [.checkIn(item)]
            case .anomaly:
                return [.anomaly(item)]
            case .newsSummary:
                return [.newsSummary(item)]
            }
        }
        currentIndex = 0
        newItemsAvailable = 0
    }

    private func visibleUnreadItems(from items: [UpToSpeedItem]) -> [UpToSpeedItem] {
        UpToSpeedVisibility(now: .now, calendar: .current).visibleUnreadItems(from: items)
    }

    func expandFlintItem(
        item: UpToSpeedItem,
        summary: UpToSpeedFlintDigestSummary,
        digest: FlintDigest?
    ) -> [UpToSpeedScreen] {
        let sections = parseSections(summary.summary ?? "")
        var pages: [UpToSpeedScreen] = []

        if meaningfulText(summary.title) != nil
            || sections.first != nil
            || summary.blockCount > 0
            || summary.unansweredQuestionCount > 0 {
            pages.append(.flintHeader(item, firstSection: sections.first))
        }

        for (i, section) in sections.dropFirst().enumerated() {
            pages.append(.flintParagraph(item, text: section, index: i + 1))
        }

        if let digest {
            let insights = digest.blocks.filter {
                !$0.isQuestion
                    && $0.blockType != "flint_editorial_note"
                    && (meaningfulText($0.title) != nil || meaningfulText($0.content) != nil)
            }
            let questions = digest.blocks.filter {
                $0.isQuestion
                    && (meaningfulText($0.question) != nil || meaningfulText($0.title) != nil)
            }
            for block in insights { pages.append(.flintInsight(item, block)) }
            for block in questions { pages.append(.flintQuestion(item, block)) }

            // Seed answered state from server data
            let questionIDs = questions.map(\.id)
            digestQuestionMap[item.id] = questionIDs
            for block in questions where block.answered {
                answeredQuestionIDs.insert(block.id)
            }
        }
        return pages
    }

    // MARK: - Section parsing

    /// Groups double-newline-separated chunks into display sections.
    /// Heading chunks (all-uppercase, < 80 chars) are merged with the body
    /// paragraph that follows them so they appear together on one card.
    private func parseSections(_ text: String) -> [String] {
        let chunks = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { meaningfulText($0) != nil }

        var sections: [String] = []
        var pending: [String] = []

        for chunk in chunks {
            pending.append(chunk)
            if !isHeading(chunk) {
                sections.append(pending.joined(separator: "\n\n"))
                pending = []
            }
        }
        if !pending.isEmpty {
            sections.append(pending.joined(separator: "\n\n"))
        }
        return sections
    }

    private func isHeading(_ chunk: String) -> Bool {
        guard chunk.count < 80 else { return false }
        let letters = chunk.filter { $0.isLetter }
        guard !letters.isEmpty else { return false }
        return letters.allSatisfy { $0.isUppercase }
    }

    private func meaningfulText(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains(where: { $0.isLetter || $0.isNumber }) else { return nil }
        return trimmed
    }

    private func enqueueMarkRead(itemID: String, type: UpToSpeedItemType) {
        guard !pendingReadRefs.contains(where: { $0.id == itemID }) else { return }
        pendingReadRefs.append(UpToSpeedReadRef(type: type, id: itemID))
    }

    private func digestCanBeMarkedRead(itemID: String) -> Bool {
        let questionIDs = digestQuestionMap[itemID] ?? []
        return questionIDs.isEmpty || questionIDs.allSatisfy { answeredQuestionIDs.contains($0) }
    }
}

struct UpToSpeedVisibility {
    private static let afternoonStartHour = 12

    let now: Date
    let calendar: Calendar

    func visibleUnreadItems(from items: [UpToSpeedItem]) -> [UpToSpeedItem] {
        let unread = items.filter(isVisibleUnreadCandidate)
        guard let mostRecentDigestID = mostRecentDigest(in: unread)?.id else {
            return unread
        }
        return unread.filter { item in
            item.type != .flintDigest || item.id == mostRecentDigestID
        }
    }

    private func isVisibleUnreadCandidate(_ item: UpToSpeedItem) -> Bool {
        guard item.caughtUpAt == nil else { return false }
        guard case .checkIn(let summary) = item.payload else { return true }
        return !summary.completed && isCheckInPeriodAvailable(summary.period)
    }

    private func isCheckInPeriodAvailable(_ period: CheckInPeriod) -> Bool {
        switch period {
        case .morning:
            return true
        case .afternoon:
            return calendar.component(.hour, from: now) >= Self.afternoonStartHour
        }
    }

    private func mostRecentDigest(in items: [UpToSpeedItem]) -> UpToSpeedItem? {
        items
            .filter { $0.type == .flintDigest }
            .max { lhs, rhs in
                digestSortKey(lhs) < digestSortKey(rhs)
            }
    }

    private func digestSortKey(_ item: UpToSpeedItem) -> String {
        if case .flintDigest(let summary) = item.payload {
            return "\(summary.date)-\(periodRank(summary.period))"
        }
        return ""
    }

    private func periodRank(_ period: FlintDigestPeriod?) -> Int {
        switch period {
        case .morning: 1
        case .afternoon: 2
        case .evening: 3
        case nil: 0
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
