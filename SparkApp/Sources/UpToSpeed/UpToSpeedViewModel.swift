import Foundation
import Observation
import SparkKit
import SparkUI
import SwiftData

@MainActor
@Observable
final class UpToSpeedViewModel {
    private(set) var screens: [UpToSpeedScreen] = []
    private(set) var chapters: [UpToSpeedChapter] = []
    var currentIndex: Int = 0
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var newItemsAvailable: Int = 0

    // Derived content for the opener + wrap screens.
    private(set) var openerGreeting: String = ""
    private(set) var openerParagraphs: [String] = []
    private(set) var readingItem: UpToSpeedParsing.ReadingItem?
    private(set) var openQuestions: [OpenQuestion] = []

    private var allItems: [UpToSpeedItem] = []
    private var snapshotCount: Int = 0
    private var pendingReadRefs: [UpToSpeedReadRef] = []
    private(set) var scrolledToBottomIndices: Set<Int> = []

    // itemID → ordered list of question blockIDs for that digest
    private var digestQuestionMap: [String: [String]] = [:]
    // blockIDs already answered (server-side on load, or in-session)
    private var answeredQuestionIDs: Set<String> = []
    // digests folded into the wrap screen — marked read when the wrap is reached
    private var foldedDigestIDs: [String] = []
    // bumped on each fetchAndBuild so a stale refreshFeed can bail out
    private var loadGeneration = 0

    private let apiClient: APIClient
    private let profileName: String?

    struct OpenQuestion: Identifiable {
        let item: UpToSpeedItem
        let block: FlintDigestBlock
        var id: String { block.id }
    }

    init(apiClient: APIClient, profileName: String? = nil) {
        self.apiClient = apiClient
        self.profileName = profileName
    }

    // MARK: - Load

    func load() async {
        guard !isLoading else { return }
        await fetchAndBuild(resetIndex: true, surfaceErrors: true)
    }

    /// Reloads the queue from scratch — re-fetches, resets to index 0, clears badge.
    func reloadQueue() async {
        guard !isLoading else { return }
        await fetchAndBuild(resetIndex: true, surfaceErrors: false)
    }

    /// Fetch the feed, preload its digests, and rebuild the queue. `@MainActor`
    /// serialises the mutations, but the item set is threaded through as a value
    /// so an interleaved `refreshFeed` cannot swap it out between the digest
    /// preload and the queue build.
    private func fetchAndBuild(resetIndex: Bool, surfaceErrors: Bool) async {
        isLoading = true
        loadGeneration &+= 1
        if surfaceErrors { error = nil }
        do {
            let response = try await apiClient.request(UpToSpeedEndpoint.feed())
            let items = response.items
            let digests = await preloadDigests(for: visibleUnreadItems(from: items))
            allItems = items
            buildScreenQueue(items: items, digests: digests, resetIndex: resetIndex)
        } catch is CancellationError {
        } catch APIError.transport(let underlying)
            where (underlying as? URLError)?.code == .cancelled {
        } catch {
            if surfaceErrors {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
        isLoading = false
    }

    /// Re-fetches the feed to detect newly arrived items; updates the
    /// newItemsAvailable badge without disturbing the current queue.
    func refreshFeed() async {
        guard !isLoading else { return }
        let generation = loadGeneration
        do {
            let response = try await apiClient.request(UpToSpeedEndpoint.feed())
            // A load that started while we were suspended owns `allItems` now.
            guard generation == loadGeneration, !isLoading else { return }
            let freshUnread = visibleUnreadItems(from: response.items).count
            newItemsAvailable = max(0, freshUnread - snapshotCount)
            allItems = response.items
        } catch {}
    }

    // MARK: - Navigation

    var currentChapterIndex: Int {
        chapters.firstIndex { $0.range.contains(currentIndex) } ?? max(chapters.count - 1, 0)
    }

    var currentChapter: UpToSpeedChapter? {
        chapters.first { $0.range.contains(currentIndex) }
    }

    /// Screen counter for the current chapter, e.g. "2 / 3".
    var chapterCounter: String {
        guard let chapter = currentChapter else { return "" }
        let position = currentIndex - chapter.range.lowerBound + 1
        return "\(position) / \(chapter.cardCount)"
    }

    func jump(to index: Int) {
        guard screens.indices.contains(index) else { return }
        currentIndex = index
    }

    func markRead(at index: Int) {
        guard let screen = screens[safe: index] else { return }
        switch screen {
        case .opener, .wrap, .checkIn, .anomaly, .dayContext:
            // opener/wrap are derived; check-in and anomaly mark via their own signals;
            // dayContext rides along on a digest that's always separately represented
            // by at least one other screen (its header, or folded into news/wrap).
            break
        case .flintHeader, .flintParagraph, .flintInsight, .flintQuestion:
            guard let itemID = screen.item?.id else { return }
            let isLastPageForItem = screens[safe: index + 1]?.item?.id != itemID
            if isLastPageForItem && digestCanBeMarkedRead(itemID: itemID) {
                enqueueMarkRead(itemID: itemID, type: .flintDigest)
            }
        case .newsStory:
            guard let itemID = screen.item?.id else { return }
            let nextIsSameStory: Bool = {
                if case .newsStory(let next, _, _, _)? = screens[safe: index + 1] {
                    return next.id == itemID
                }
                return false
            }()
            if !nextIsSameStory {
                enqueueMarkRead(itemID: itemID, type: .flintDigest)
            }
        case .newsSummary(let item):
            guard scrolledToBottomIndices.contains(index) else { return }
            enqueueMarkRead(itemID: item.id, type: .newsSummary)
        }
    }

    /// Called when the wrap screen appears — folds the reading-list digest(s)
    /// into "caught up" and flushes any pending read state on this leg.
    func markReachedWrap() {
        for id in foldedDigestIDs {
            enqueueMarkRead(itemID: id, type: .flintDigest)
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
        openQuestions.removeAll { $0.block.id == blockID }
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

    private func buildScreenQueue(
        items: [UpToSpeedItem],
        digests: [String: FlintDigest] = [:],
        resetIndex: Bool = true
    ) {
        digestQuestionMap = [:]
        answeredQuestionIDs = []
        scrolledToBottomIndices = []
        foldedDigestIDs = []
        openQuestions = []
        readingItem = nil
        openerParagraphs = []

        let unread = visibleUnreadItems(from: items)
        snapshotCount = unread.count

        var built: [(screen: UpToSpeedScreen, key: UpToSpeedChapter.Kind)] = []

        // 1 — anomalies
        for item in unread where item.type == .anomaly {
            built.append((.anomaly(item), .anomaly))
        }

        // 2 — digests, oldest first, split by role
        let digestItems = unread
            .filter { $0.type == .flintDigest }
            .sorted { digestSortDate(for: $0, digests: digests) < digestSortDate(for: $1, digests: digests) }

        var primaryDigestSummary: String?
        var newsScreens: [(screen: UpToSpeedScreen, key: UpToSpeedChapter.Kind)] = []
        // digestItems is sorted oldest → newest, so the last match here is the
        // most-recently-created day-context block across all of today's digests.
        var dayContextCandidate: (item: UpToSpeedItem, context: FlintDayContext)?

        for item in digestItems {
            let full = digests[item.id]
            let title = digestTitle(item: item, digest: full)

            if let block = full?.blocks.first(where: { $0.blockType == "flint_day_context" }),
               let context = block.dayContext {
                dayContextCandidate = (item, context)
            }

            if isReadingListDigest(title: title, digest: full) {
                if let summary = full?.summary ?? digestSummary(item), readingItem == nil {
                    readingItem = UpToSpeedParsing.readingItem(from: summary)
                }
                foldedDigestIDs.append(item.id)
                continue
            }

            if isNewsRoundupDigest(title: title, digest: full) {
                let summary = full?.summary ?? digestSummary(item) ?? ""
                let sections = UpToSpeedParsing.newsRoundupSections(from: summary)
                for section in sections {
                    newsScreens.append((
                        .newsStory(item, section: section, index: section.id, total: sections.count),
                        .news
                    ))
                }
                if sections.isEmpty { foldedDigestIDs.append(item.id) }
                continue
            }

            // Primary digest — prose + insights + questions
            if primaryDigestSummary == nil {
                primaryDigestSummary = full?.summary ?? digestSummary(item)
            }
            for screen in expandFlintItem(item: item, digest: full) {
                built.append((screen, .digest(title: title)))
            }
        }

        // 3 — day context (if any digest carried one), then news
        if let candidate = dayContextCandidate {
            let yesterday = primaryDigestSummary.flatMap(UpToSpeedParsing.yesterdayRecap(from:))
            built.append((.dayContext(candidate.item, candidate.context, yesterday: yesterday), .day))
        }
        built.append(contentsOf: newsScreens)
        for item in unread where item.type == .newsSummary {
            built.append((.newsSummary(item), .news))
        }

        // 4 — check-in (incomplete), then wrap
        var wrapChapterHasContent = readingItem != nil || !openQuestions.isEmpty
        for item in unread where item.type == .checkIn {
            if case .checkIn(let summary) = item.payload, !summary.completed {
                built.append((.checkIn(item), .wrap))
                wrapChapterHasContent = true
            }
        }

        let hasSubstance = built.contains { pair in
            switch pair.key {
            case .anomaly, .digest, .day, .news: true
            case .wrap: wrapChapterHasContent
            case .intro: false
            }
        }

        guard hasSubstance else {
            screens = []
            chapters = []
            currentIndex = 0
            newItemsAvailable = 0
            return
        }

        built.insert((.opener, .intro), at: 0)
        built.append((.wrap, .wrap))

        screens = built.map(\.screen)
        chapters = UpToSpeedChapter.chapters(for: built.map(\.key))

        openerGreeting = makeGreeting()
        if let summary = primaryDigestSummary {
            openerParagraphs = UpToSpeedParsing.openerParagraphs(from: summary)
        }

        if resetIndex {
            currentIndex = 0
        } else {
            currentIndex = min(currentIndex, screens.count - 1)
        }
        newItemsAvailable = 0
    }

    private func visibleUnreadItems(from items: [UpToSpeedItem]) -> [UpToSpeedItem] {
        UpToSpeedVisibility(now: .now, calendar: .current).visibleUnreadItems(from: items)
    }

    private func expandFlintItem(item: UpToSpeedItem, digest: FlintDigest?) -> [UpToSpeedScreen] {
        let sections = parseSections(digestSummary(item) ?? digest?.summary ?? "")
        var pages: [UpToSpeedScreen] = [.flintHeader(item, firstSection: sections.first)]

        for (i, section) in sections.dropFirst().enumerated() {
            pages.append(.flintParagraph(item, text: section, index: i + 1))
        }

        if let digest {
            let insights = digest.blocks.filter {
                !$0.isQuestion && $0.blockType != "flint_editorial_note" && $0.blockType != "flint_day_context"
            }
            let questions = digest.blocks.filter { $0.isQuestion }
            for block in insights { pages.append(.flintInsight(item, block)) }
            for block in questions { pages.append(.flintQuestion(item, block)) }

            let questionIDs = questions.map(\.id)
            digestQuestionMap[item.id] = questionIDs
            for block in questions {
                if block.answered {
                    answeredQuestionIDs.insert(block.id)
                } else {
                    openQuestions.append(OpenQuestion(item: item, block: block))
                }
            }
        }
        return pages
    }

    // MARK: - Digest categorisation

    private func digestSummary(_ item: UpToSpeedItem) -> String? {
        if case .flintDigest(let summary) = item.payload { return summary.summary }
        return nil
    }

    private func digestTitle(item: UpToSpeedItem, digest: FlintDigest?) -> String {
        if let title = digest?.title, !title.isEmpty { return title }
        if case .flintDigest(let summary) = item.payload, let title = summary.title, !title.isEmpty {
            return title
        }
        return "Digest"
    }

    private func digestSortDate(for item: UpToSpeedItem, digests: [String: FlintDigest]) -> Date {
        if let created = digests[item.id]?.createdAt { return created }
        if case .flintDigest(let summary) = item.payload {
            let rank: TimeInterval
            switch summary.period {
            case .morning: rank = 1
            case .afternoon: rank = 2
            case .evening: rank = 3
            case nil: rank = 0
            }
            let day = ISO8601DateFormatter().date(from: "\(summary.date)T00:00:00Z") ?? .distantPast
            return day.addingTimeInterval(rank * 3600)
        }
        return .distantPast
    }

    private func isNewsRoundupDigest(title: String, digest: FlintDigest?) -> Bool {
        let lowered = title.lowercased()
        if lowered.contains("news") || lowered.contains("roundup") { return true }
        guard let digest else { return false }
        let contentBlocks = digest.blocks.filter { $0.blockType != "flint_editorial_note" && !$0.isQuestion }
        return !contentBlocks.isEmpty && contentBlocks.allSatisfy { $0.blockType == "flint_news" }
    }

    private func isReadingListDigest(title: String, digest: FlintDigest?) -> Bool {
        let lowered = title.lowercased()
        if lowered.contains("reading list") || lowered.contains("saved to read") { return true }
        return lowered.contains("reading") && (digest?.blocks.isEmpty ?? true)
    }

    private func makeGreeting() -> String {
        let slot = SparkTimeOfDay.from(date: .now)
        let weekday = Date.now.formatted(.dateTime.weekday(.wide))
        let base: String
        switch slot {
        case .morning: base = "Good \(weekday) morning"
        case .afternoon: base = "Good \(weekday) afternoon"
        case .evening: base = "Good \(weekday) evening"
        case .night: base = "Still up"
        }
        if let name = profileName, !name.isEmpty {
            return "\(base), \(name)."
        }
        return "\(base)."
    }

    // MARK: - Section parsing

    /// Groups double-newline-separated chunks into display sections.
    /// Heading chunks (all-uppercase, < 80 chars) are merged with the body
    /// paragraph that follows them so they appear together on one card.
    private func parseSections(_ text: String) -> [String] {
        let chunks = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

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

    /// Every unread item that should surface in the flow. Unlike the previous
    /// implementation this keeps *all* unread digests — the chaptered flow
    /// shows the morning brief, the news roundup and the reading list together.
    func visibleUnreadItems(from items: [UpToSpeedItem]) -> [UpToSpeedItem] {
        items.filter(isVisibleUnreadCandidate)
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
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
