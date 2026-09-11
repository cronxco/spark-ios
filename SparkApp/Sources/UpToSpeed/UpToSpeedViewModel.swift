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
    /// Items already caught up on today, newest first. Offered after the wrap
    /// so something dismissed by accident can be found and restored.
    private(set) var recapItems: [UpToSpeedItem] = []
    private(set) var unmarkingIDs: Set<String> = []

    private var allItems: [UpToSpeedItem] = []
    private var snapshotCount: Int = 0
    private var pendingReadRefs: [UpToSpeedReadRef] = []
    private var isFlushing = false
    /// Screens the reader has genuinely finished — reached the end of and
    /// stayed there for the dwell. See `StoryScreenScaffold`.
    private(set) var consumedIndices: Set<Int> = []

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
            let response = try await apiClient.request(UpToSpeedEndpoint.feed(includeAcknowledged: true))
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
            let response = try await apiClient.request(UpToSpeedEndpoint.feed(includeAcknowledged: true))
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

    /// Called when the pager moves forward off `index`. Nothing is decided here
    /// beyond re-running the read test — a card the reader skipped past without
    /// finishing stays unread.
    func markRead(at index: Int) {
        evaluateRead(at: index)
    }

    /// Called by a screen once the reader has reached the end of it and stayed
    /// there for the dwell. This is the only route by which a screen becomes
    /// eligible to be marked read.
    func markScreenConsumed(at index: Int) {
        guard !consumedIndices.contains(index) else { return }
        consumedIndices.insert(index)
        evaluateRead(at: index)
    }

    /// Decides whether the item behind the screen at `index` is now caught up.
    /// Runs on both signals — consumption and forward navigation — so the last
    /// card in the queue can be marked without needing a swipe that has nowhere
    /// to go, while a card swiped past unfinished is still not marked.
    private func evaluateRead(at index: Int) {
        guard let ref = Self.readTarget(
            at: index,
            in: screens,
            consumed: consumedIndices,
            digestsAwaitingAnswers: digestsAwaitingAnswers
        ) else { return }

        enqueueMarkRead(ref)
    }

    /// The item that finishing the screen at `index` marks caught up, if any.
    ///
    /// Pure so the rule can be tested directly: reaching the end of a card is a
    /// precondition for every type that carries content. Without that gate,
    /// opening the flow and swiping through marks the whole day read without
    /// any of it having been looked at — which is what the old scaffold did.
    nonisolated static func readTarget(
        at index: Int,
        in screens: [UpToSpeedScreen],
        consumed: Set<Int>,
        digestsAwaitingAnswers: Set<String>
    ) -> UpToSpeedReadRef? {
        guard let screen = screens[safe: index] else { return nil }
        guard consumed.contains(index) else { return nil }

        switch screen {
        case .opener, .wrap, .checkIn, .anomaly:
            // opener/wrap are derived; check-in and anomaly mark via their own signals
            return nil

        case .flintHeader, .flintParagraph, .flintInsight, .flintQuestion, .dayContext:
            // A day-context screen isn't always adjacent to the rest of its
            // digest's screens (it's appended once, after every digest chapter),
            // so "last page" has to scan forward rather than compare index+1 —
            // otherwise a digest whose day-context screen trails its own
            // content never gets marked read at all, or gets marked read
            // before that screen is shown, depending on queue order.
            guard let itemID = screen.item?.id else { return nil }
            guard isLastScreen(forItemID: itemID, at: index, in: screens) else { return nil }
            guard !digestsAwaitingAnswers.contains(itemID) else { return nil }
            return UpToSpeedReadRef(type: .flintDigest, id: itemID)

        case .newsStory:
            // Only the digest's own screens are ever adjacent here (news
            // stories for one item are always built contiguously), so the whole
            // roundup counts as read once its final story does.
            guard let itemID = screen.item?.id else { return nil }
            if case .newsStory(let next, _, _, _)? = screens[safe: index + 1], next.id == itemID {
                return nil
            }
            return UpToSpeedReadRef(type: .flintDigest, id: itemID)

        case .newsSummary(let item):
            return UpToSpeedReadRef(type: .newsSummary, id: item.id)
        }
    }

    /// Digests that still have at least one unanswered question, and so are not
    /// finished no matter how much of their prose has been read.
    private var digestsAwaitingAnswers: Set<String> {
        Set(digestQuestionMap.compactMap { itemID, questionIDs in
            questionIDs.allSatisfy { answeredQuestionIDs.contains($0) } ? nil : itemID
        })
    }

    /// Whether no later screen in `screens` shares `itemID` with the one at
    /// `index` — i.e. whether this is genuinely the last time that item's
    /// content appears in the queue. Screens for one item aren't always
    /// contiguous (a day-context screen is appended once, separately from
    /// the digest chapter it belongs to), so this scans forward rather than
    /// only comparing against `index + 1`.
    nonisolated static func isLastScreen(forItemID itemID: String, at index: Int, in screens: [UpToSpeedScreen]) -> Bool {
        guard index + 1 < screens.count else { return true }
        return !screens[(index + 1)...].contains { $0.item?.id == itemID }
    }

    /// Called when the wrap screen appears — marks read the (at most one)
    /// reading-list digest whose content became `readingItem`, which the wrap
    /// screen itself displays. Safe to call unconditionally, including via a
    /// direct chapter jump: `foldedDigestIDs` only ever names a digest whose
    /// content is shown on this very screen, never one the jump skipped past.
    func markReachedWrap() {
        for id in foldedDigestIDs {
            enqueueMarkRead(itemID: id, type: .flintDigest)
        }
    }

    /// Called by AnomalyScreen when the user acknowledges or suppresses an anomaly.
    func markAnomalyRead(itemID: String) {
        enqueueMarkRead(itemID: itemID, type: .anomaly)
    }

    /// Return a recap item to the unread queue.
    ///
    /// Flushes first: a pending mark for the same item would otherwise land
    /// after the unmark and quietly re-hide it.
    func unmark(_ item: UpToSpeedItem) async {
        guard !unmarkingIDs.contains(item.id) else { return }
        unmarkingIDs.insert(item.id)
        defer { unmarkingIDs.remove(item.id) }

        pendingReadRefs.removeAll { $0.id == item.id }
        await flushAndWait()

        let ref = UpToSpeedReadRef(type: item.type, id: item.id)
        guard (try? await apiClient.request(UpToSpeedEndpoint.unmark([ref]))) != nil else { return }

        await reloadQueue()
    }

    /// The domain of an anomaly item, when the payload carries one.
    nonisolated static func anomalyDomain(_ item: UpToSpeedItem) -> String? {
        guard case .anomaly(let anomaly) = item.payload else { return nil }
        return anomaly.domain
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
    /// Fire-and-forget; use `flushAndWait()` where the result matters.
    func flush() {
        guard !pendingReadRefs.isEmpty else { return }
        Task { await flushAndWait() }
    }

    /// Posts the pending refs and keeps them if the request fails, so a flush
    /// that goes out on a dead network is retried on the next one rather than
    /// silently dropping the reader's progress. The endpoint is idempotent, so
    /// re-sending a ref that did land is harmless.
    func flushAndWait() async {
        guard !pendingReadRefs.isEmpty, !isFlushing else { return }
        let refs = pendingReadRefs
        isFlushing = true
        defer { isFlushing = false }

        do {
            _ = try await apiClient.request(UpToSpeedEndpoint.markRead(refs))
            pendingReadRefs.removeAll { ref in refs.contains { $0.id == ref.id } }
        } catch {
            // Keep the refs queued for the next flush.
        }
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
        consumedIndices = []
        foldedDigestIDs = []
        openQuestions = []
        readingItem = nil
        openerParagraphs = []

        let unread = visibleUnreadItems(from: items)
        snapshotCount = unread.count

        var built: [(screen: UpToSpeedScreen, key: UpToSpeedChapter.Kind)] = []

        // 1 — anomalies, grouped by domain. The chapter grouping collapses
        // consecutive equal keys, so same-domain anomalies have to be adjacent
        // for "Your body" and "Your money" to come out as separate chapters.
        let anomalies = unread
            .filter { $0.type == .anomaly }
            .sorted { (Self.anomalyDomain($0) ?? "~") < (Self.anomalyDomain($1) ?? "~") }

        for item in anomalies {
            built.append((.anomaly(item), .anomaly(domain: Self.anomalyDomain(item))))
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

            // Fold a reading-list digest's content into the wrap screen's
            // readingItem — but only the first one whose summary actually
            // parses. A duplicate reading-list digest, or one whose summary
            // doesn't parse, falls through to normal digest expansion below
            // instead of being silently folded as "read" with nothing shown.
            if isReadingListDigest(title: title, digest: full), readingItem == nil,
               let summary = full?.summary ?? digestSummary(item),
               let parsed = UpToSpeedParsing.readingItem(from: summary) {
                readingItem = parsed
                foldedDigestIDs.append(item.id)
                continue
            }

            if isNewsRoundupDigest(title: title, digest: full) {
                let summary = full?.summary ?? digestSummary(item) ?? ""
                let sections = UpToSpeedParsing.newsRoundupSections(from: summary)
                if !sections.isEmpty {
                    for section in sections {
                        newsScreens.append((
                            .newsStory(item, section: section, index: section.id, total: sections.count),
                            .news
                        ))
                    }
                    continue
                }
                // No parseable "## " sections — fall through to normal digest
                // expansion rather than folding it as "read" with nothing shown.
            }

            // Primary digest — prose + insights + questions
            if primaryDigestSummary == nil {
                primaryDigestSummary = full?.summary ?? digestSummary(item)
                openerParagraphs = primaryDigestSummary.map {
                    UpToSpeedParsing.openerParagraphs(from: $0)
                } ?? []
            }
            for screen in expandFlintItem(item: item, digest: full, shownInOpener: openerParagraphs) {
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

        // Not `built.contains { ... .wrap: wrapChapterHasContent }` — a solo
        // folded reading-list digest leaves `built` with zero .wrap-keyed
        // entries (no incomplete check-in), so `.contains` over an empty
        // match set would wrongly report no substance even though
        // wrapChapterHasContent is true.
        let hasSubstance = !built.isEmpty || wrapChapterHasContent

        guard hasSubstance else {
            screens = []
            chapters = []
            currentIndex = 0
            newItemsAvailable = 0
            return
        }

        recapItems = caughtUpItems(from: items)

        built.insert((.opener, .intro), at: 0)
        built.append((.wrap, .wrap))

        // The recap is an appendix, not part of the catch-up proper: it sits
        // past the wrap so swiping on reaches it, and the wrap offers a way in.
        if !recapItems.isEmpty {
            built.append((.recap, .recap))
        }

        screens = built.map(\.screen)
        chapters = UpToSpeedChapter.chapters(for: built.map(\.key))

        openerGreeting = makeGreeting()

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

    private func caughtUpItems(from items: [UpToSpeedItem]) -> [UpToSpeedItem] {
        UpToSpeedVisibility(now: .now, calendar: .current).caughtUpItems(from: items)
    }

    private func expandFlintItem(
        item: UpToSpeedItem,
        digest: FlintDigest?,
        shownInOpener: [String] = []
    ) -> [UpToSpeedScreen] {
        // Drop what the opener already carries. Without this the briefing
        // repeated the opener's paragraphs verbatim, and its first card held
        // only the greeting — a full screen for two words.
        let sections = parseSections(digestSummary(item) ?? digest?.summary ?? "")
            .filter { !UpToSpeedParsing.sectionIsShownInOpener($0, openerParagraphs: shownInOpener) }

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
        enqueueMarkRead(UpToSpeedReadRef(type: type, id: itemID))
    }

    private func enqueueMarkRead(_ ref: UpToSpeedReadRef) {
        guard !pendingReadRefs.contains(where: { $0.id == ref.id }) else { return }
        pendingReadRefs.append(ref)
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

    /// Everything already dealt with today, newest first — the recap.
    ///
    /// Check-ins are excluded: a submitted check-in is a thing that happened,
    /// not something that can be un-seen, and the feed has no way to reopen one.
    func caughtUpItems(from items: [UpToSpeedItem]) -> [UpToSpeedItem] {
        items
            .filter(isRecapCandidate)
            .sorted { lhs, rhs in
                (seenAt(lhs) ?? .distantPast) > (seenAt(rhs) ?? .distantPast)
            }
    }

    /// When the reader last dealt with an item, however they dealt with it.
    func seenAt(_ item: UpToSpeedItem) -> Date? {
        if case .anomaly(let anomaly) = item.payload, let acknowledged = anomaly.acknowledgedAt {
            return max(acknowledged, item.caughtUpAt ?? acknowledged)
        }
        return item.caughtUpAt
    }

    private func isVisibleUnreadCandidate(_ item: UpToSpeedItem) -> Bool {
        guard item.caughtUpAt == nil else { return false }

        switch item.payload {
        case .checkIn(let summary):
            return !summary.completed && isCheckInPeriodAvailable(summary.period)
        case .anomaly(let anomaly):
            // The feed is asked for dismissed anomalies so the recap can offer
            // them back, so they arrive here too — with caughtUpAt null,
            // because acknowledgement is tracked separately. Without this they
            // would reappear in the flow the moment they were dismissed.
            return anomaly.acknowledgedAt == nil
        default:
            return true
        }
    }

    private func isRecapCandidate(_ item: UpToSpeedItem) -> Bool {
        if case .checkIn = item.payload { return false }
        return seenAt(item) != nil
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
