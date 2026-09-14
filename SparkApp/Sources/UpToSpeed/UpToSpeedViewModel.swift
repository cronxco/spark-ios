import Foundation
import Observation
import OSLog
import SparkKit
import SparkUI
import SwiftUI
import SwiftData

@MainActor
@Observable
final class UpToSpeedViewModel {
    var expandedDisclosures: Set<String> = []
    func disclosureBinding(_ key: String) -> Binding<Bool> {
        Binding(get: { self.expandedDisclosures.contains(key) }, set: {
            if $0 { self.expandedDisclosures.insert(key) }
            else { self.expandedDisclosures.remove(key) }
        })
    }
    private(set) var screens: [UpToSpeedScreen] = []
    private(set) var chapters: [UpToSpeedChapter] = []
    var currentIndex: Int = 0
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var newItemsAvailable: Int = 0

    // Derived content for the opener + wrap screens.
    private(set) var openerGreeting: String = ""
    /// Calendar, birthdays and weather for the opener. The day used to be a
    /// chapter of its own, several swipes in, while the opener led with two
    /// paragraphs lifted off the digest — which left the briefing chapter with
    /// nothing to say. The day is what the reader actually opens this for.
    private(set) var openerDayContext: FlintDayContext?
    /// One line on yesterday, shown only when the day context describes today.
    /// Beside tomorrow's plans it reads as a non-sequitur.
    private(set) var openerYesterday: String?
    /// Every pick from today's reading list. Was a single optional, which
    /// silently dropped the second pick whenever Flint offered two.
    private(set) var readingItems: [UpToSpeedParsing.ReadingItem] = []
    private(set) var openQuestions: [OpenQuestion] = []
    /// Items already caught up on today, newest first. Offered after the wrap
    /// so something dismissed by accident can be found and restored.
    private(set) var recapItems: [UpToSpeedItem] = []
    private(set) var unmarkingIDs: Set<String> = []
    /// Digests whose detail fetch failed on the last load. The flow degrades to
    /// the feed summary for these, so the count exists to say so rather than
    /// present a half-empty story as the whole day.
    private(set) var digestsFailedToLoad: Int = 0
    private(set) var restoredIDs: Set<String> = []
    private var sessionSeenDates: [String: Date] = [:]
    private(set) var digestCache: [String: FlintDigest] = [:]
    private var needsReconciliation = false
    private var restorationVersions: [String: Int] = [:]

    func supplementalItems(for screen: UpToSpeedScreen) -> [UpToSpeedItem] {
        if case .wrap = screen {
            return allItems.filter { foldedDigestIDs.contains($0.id) }
        }
        guard let item = screen.item, item.type == .flintDigest,
              screens.last(where: { $0.item?.id == item.id })?.id == screen.id else { return [] }
        return [item]
    }

    func restorationVersion(for itemID: String?) -> Int {
        itemID.flatMap { restorationVersions[$0] } ?? 0
    }

    func recapDate(for item: UpToSpeedItem) -> Date {
        if case .checkIn(let summary) = item.payload, item.caughtUpAt == nil {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: summary.date) ?? .distantPast
        }
        return sessionSeenDates[item.id]
            ?? UpToSpeedVisibility(now: .now, calendar: .current).seenAt(item)
            ?? .distantPast
    }

    func recapDigest(for item: UpToSpeedItem) async throws -> FlintDigest {
        if let cached = digestCache[item.id] { return cached }
        let digest = try await apiClient.request(FlintEndpoint.digest(id: item.id))
        digestCache[item.id] = digest
        return digest
    }

    func reconcileAfterRecap() async {
        guard needsReconciliation else { return }
        await flushAndWait()
        await fetchAndBuild(resetIndex: false, surfaceErrors: false)
    }

    private func updateRecap() {
        var seen = Set<String>()
        let retained = recapItems.filter { restoredIDs.contains($0.id) || sessionSeenDates[$0.id] != nil }
        recapItems = (allItems + retained).filter { item in
            let eligible = sessionSeenDates[item.id] != nil
                || restoredIDs.contains(item.id)
                || UpToSpeedVisibility(now: .now, calendar: .current).caughtUpItems(from: [item]).isEmpty == false
            return eligible && seen.insert(item.id).inserted
        }.sorted { recapDate(for: $0) > recapDate(for: $1) }
    }

    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "UpToSpeed")

    private var allItems: [UpToSpeedItem] = []
    private var snapshotCount: Int = 0
    /// Reads queued for the next flush. Readable so tests can assert on what a
    /// signal did or didn't mark, which is the whole subject of this type.
    private(set) var pendingReadRefs: [UpToSpeedReadRef] = []
    private var isFlushing = false
    private var activeFlushTask: Task<Bool, Never>?
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
        digestsFailedToLoad = 0
        loadGeneration &+= 1
        if surfaceErrors { error = nil }
        do {
            let response = try await apiClient.request(UpToSpeedEndpoint.feed(includeAcknowledged: true))
            let items = response.items
            // Day context remains useful after its briefing has been read.
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy-MM-dd"
            let today = formatter.string(from: .now)
            let candidates = items.filter {
                if case .flintDigest(let summary) = $0.payload {
                    return $0.caughtUpAt == nil || summary.date == today
                }
                return false
            }
            let digests = await preloadDigests(for: candidates)
            digestCache.merge(digests) { _, new in new }
            allItems = items
            for id in restoredIDs {
                restorationVersions[id, default: 0] += 1
                sessionSeenDates.removeValue(forKey: id)
            }
            buildScreenQueue(items: items, digests: digests, resetIndex: resetIndex)
            needsReconciliation = false
            restoredIDs.removeAll()
            updateRecap()
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
            updateRecap()
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
        guard !isLoading else { return }
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
        case .opener, .wrap, .recap, .checkIn, .anomaly:
            // opener/wrap/recap are derived; check-in and anomaly mark via
            // their own signals. The recap in particular must never mark
            // anything: everything on it is already read, and reading it again
            // is not what puts it back.
            return nil

        case .flintHeader, .flintParagraph, .flintInsight, .flintQuestion:
            // "Last page" scans forward rather than comparing index + 1. A
            // digest's screens are contiguous today, so the two agree, but the
            // scan is what makes that an observation rather than a requirement
            // the next reordering can quietly break.
            guard let itemID = screen.item?.id else { return nil }
            guard isLastScreen(forItemID: itemID, at: index, in: screens) else { return nil }
            guard allScreensAreConsumed(forItemID: itemID, in: screens, consumed: consumed) else { return nil }
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
            guard allScreensAreConsumed(forItemID: itemID, in: screens, consumed: consumed) else { return nil }
            return UpToSpeedReadRef(type: .flintDigest, id: itemID)

        case .newsSummary(let item):
            return UpToSpeedReadRef(type: .newsSummary, id: item.id)
        }
    }

    /// Digests that still have at least one unanswered question, and so are not
    /// finished no matter how much of their prose has been read.
    private var digestsAwaitingAnswers: Set<String> {
        var awaiting = Set(digestQuestionMap.compactMap { itemID, questionIDs in
            questionIDs.allSatisfy { answeredQuestionIDs.contains($0) } ? nil : itemID
        })

        // `preloadDigests` fetches detail with `try?`, so a failed request
        // leaves no question ids for that digest at all — and without this the
        // map's silence would read as "nothing outstanding" and the digest
        // would be marked caught up after its prose, with the feed itself
        // saying a question is still waiting. Trust the feed's count whenever
        // the detail never arrived; once it has, the map is the better answer
        // because it tracks answers given in this session.
        for item in allItems where digestQuestionMap[item.id] == nil {
            if case .flintDigest(let summary) = item.payload, summary.unansweredQuestionCount > 0 {
                awaiting.insert(item.id)
            }
        }

        return awaiting
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

    private nonisolated static func allScreensAreConsumed(
        forItemID itemID: String,
        in screens: [UpToSpeedScreen],
        consumed: Set<Int>
    ) -> Bool {
        screens.indices
            .filter { screens[$0].item?.id == itemID }
            .allSatisfy { consumed.contains($0) }
    }

    /// Called when the wrap screen appears — marks read the (at most one)
    /// reading-list digest whose picks became `readingItems`, which the wrap
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
    @discardableResult
    func unmark(_ item: UpToSpeedItem) async -> Bool {
        if case .checkIn = item.payload { return false }
        guard !unmarkingIDs.contains(item.id), !restoredIDs.contains(item.id) else { return false }
        unmarkingIDs.insert(item.id)
        defer { unmarkingIDs.remove(item.id) }

        let wasPending = pendingReadRefs.contains { $0.id == item.id }
        pendingReadRefs.removeAll { $0.id == item.id }
        await flushAndWait()

        let ref = UpToSpeedReadRef(type: item.type, id: item.id)
        guard let result = try? await apiClient.request(UpToSpeedEndpoint.unmark([ref])), result.unmarked > 0 else {
            if wasPending && !pendingReadRefs.contains(where: { $0.id == item.id }) { pendingReadRefs.append(ref) }
            return false
        }
        restoredIDs.insert(item.id)
        needsReconciliation = true
        return true
    }

    /// The domain of an anomaly item, when the payload carries one.
    nonisolated static func anomalyDomain(_ item: UpToSpeedItem) -> String? {
        guard case .anomaly(let anomaly) = item.payload else { return nil }
        return anomaly.domain
    }

    /// Called by FlintQuestionPage after a successful answer submission.
    ///
    /// Answering the last question lifts the `digestsAwaitingAnswers` block but
    /// is not itself evidence the digest was read — a reader can open the flow,
    /// swipe straight to the question and answer it without meeting a word of
    /// the prose. So this re-runs the ordinary read test against the digest's
    /// final screen rather than marking it directly; the consumption gate still
    /// has to be satisfied. If the answer lands before the dwell elapses, the
    /// dwell fires moments later and the test runs again.
    func onQuestionAnswered(blockID: String, itemID: String) {
        answeredQuestionIDs.insert(blockID)
        openQuestions.removeAll { $0.block.id == blockID }
        let allIDs = digestQuestionMap[itemID] ?? []
        guard !allIDs.isEmpty else { return }
        if allIDs.allSatisfy({ answeredQuestionIDs.contains($0) }) {
            guard let lastIndex = screens.lastIndex(where: { $0.item?.id == itemID }) else { return }
            evaluateRead(at: lastIndex)
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
        if isFlushing, let activeFlushTask {
            _ = await activeFlushTask.value
            return
        }
        guard !pendingReadRefs.isEmpty else { return }

        let refs = pendingReadRefs
        let client = apiClient
        let task = Task {
            do {
                _ = try await client.request(UpToSpeedEndpoint.markRead(refs))
                return true
            } catch {
                return false
            }
        }

        isFlushing = true
        activeFlushTask = task
        let succeeded = await task.value
        if succeeded {
            pendingReadRefs.removeAll { ref in refs.contains { $0.id == ref.id } }
        }
        activeFlushTask = nil
        isFlushing = false
    }

    // MARK: - Unread count

    var unreadCount: Int {
        visibleUnreadItems(from: allItems).count
    }

    // MARK: - Private

    /// Fetches the full digest behind each feed item.
    ///
    /// A failure here is not fatal — the flow still builds from the feed's own
    /// summary — but it is not nothing either: the digest loses its blocks, so
    /// its stories, picks, day context and questions all silently disappear and
    /// the result looks like a thin day rather than a failed fetch. Previously
    /// `try?` swallowed that entirely. Now it is logged, and the count is kept
    /// so the flow can say so.
    private func preloadDigests(for items: [UpToSpeedItem]) async -> [String: FlintDigest] {
        let flintItems = items.filter { $0.type == .flintDigest }
        guard !flintItems.isEmpty else { return [:] }
        let client = apiClient
        let log = logger
        var result: [String: FlintDigest] = [:]
        var failures = 0
        await withTaskGroup(of: (String, FlintDigest?).self) { group in
            for item in flintItems {
                let itemID = item.id
                group.addTask {
                    do {
                        return (itemID, try await client.request(FlintEndpoint.digest(id: itemID)))
                    } catch {
                        log.error("Failed to preload digest \(itemID, privacy: .public): \(error.localizedDescription, privacy: .private)")
                        return (itemID, nil)
                    }
                }
            }
            for await (id, digest) in group {
                if let digest {
                    result[id] = digest
                } else {
                    failures += 1
                }
            }
        }
        digestsFailedToLoad = failures
        return result
    }

    private func buildScreenQueue(
        items: [UpToSpeedItem],
        digests: [String: FlintDigest] = [:],
        resetIndex: Bool = true
    ) {
        digestCache.merge(digests) { _, new in new }
        let previousID = screens[safe: currentIndex]?.id
        let previouslyConsumed = Set(consumedIndices.compactMap { index -> String? in
            guard let screen = screens[safe: index], !restoredIDs.contains(screen.item?.id ?? "") else { return nil }
            return screen.id
        })
        digestQuestionMap = [:]
        answeredQuestionIDs = []
        consumedIndices = []
        foldedDigestIDs = []
        openQuestions = []
        readingItems = []
        openerDayContext = nil
        openerYesterday = nil

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
        // In the evening that is the digest describing tomorrow, which is what
        // the opener should lead with once today is over.
        let dayContextCandidate = Self.dayContext(from: Array(digests.values), now: .now, calendar: .current)

        for item in digestItems {
            let full = digests[item.id]
            let title = digestTitle(item: item, digest: full)

            // Fold a reading-list digest's picks into the wrap screen — but only
            // when there is something to show. A duplicate reading-list digest,
            // or one that yields no picks, falls through to normal digest
            // expansion below instead of being silently folded as "read" with
            // nothing shown.
            if isReadingListDigest(item: item, title: title, digest: full), readingItems.isEmpty {
                let picks = UpToSpeedParsing.readingItems(
                    blocks: full?.blocks ?? [],
                    summary: full?.summary ?? digestSummary(item) ?? ""
                )
                if !picks.isEmpty {
                    readingItems = picks
                    foldedDigestIDs.append(item.id)
                    continue
                }
            }

            if isNewsRoundupDigest(item: item, title: title, digest: full) {
                let summary = full?.summary ?? digestSummary(item) ?? ""
                let sections = UpToSpeedParsing.newsRoundupSections(
                    blocks: full?.blocks ?? [],
                    summary: summary
                )
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

            // Primary digest — prose + insights + questions. The opener takes
            // nothing from it: every paragraph belongs to the briefing chapter,
            // which is the only place the reader is promised them.
            if primaryDigestSummary == nil {
                primaryDigestSummary = full?.summary ?? digestSummary(item)
            }

            for screen in expandFlintItem(item: item, digest: full) {
                built.append((screen, .digest(title: title)))
            }
        }

        // 3 — day context onto the opener, then news
        openerDayContext = dayContextCandidate
        if dayContextCandidate?.describesToday(now: .now, calendar: .current) ?? true {
            openerYesterday = primaryDigestSummary.flatMap(UpToSpeedParsing.yesterdayRecap(from:))
        }
        built.append(contentsOf: newsScreens)
        for item in unread where item.type == .newsSummary {
            built.append((.newsSummary(item), .news))
        }

        // 4 — check-in (incomplete), then wrap
        var wrapChapterHasContent = !readingItems.isEmpty || !openQuestions.isEmpty
        for item in unread where item.type == .checkIn {
            if case .checkIn(let summary) = item.payload, !summary.completed {
                built.append((.checkIn(item), .wrap))
                wrapChapterHasContent = true
            }
        }

        // Compute recap before the empty-queue guard: today's already-seen
        // items can be the only content available. Also, a solo folded
        // reading-list digest leaves `built` with no .wrap-keyed entries, so
        // wrap content must count as substance independently.
        updateRecap()
        let hasSubstance = !built.isEmpty || wrapChapterHasContent || !recapItems.isEmpty

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

        if resetIndex {
            currentIndex = 0
        } else {
            currentIndex = screens.firstIndex(where: { $0.id == previousID }) ?? min(currentIndex, screens.count - 1)
            consumedIndices = Set(screens.indices.filter { previouslyConsumed.contains(screens[$0].id) })
        }
        newItemsAvailable = 0
    }

    nonisolated static func dayContext(from digests: [FlintDigest], now: Date, calendar: Calendar) -> FlintDayContext? {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return digests.sorted {
            if $0.createdAt != $1.createdAt { return ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.id < $1.id
        }.flatMap { digest in
            digest.blocks.compactMap { block -> FlintDayContext? in
                guard block.blockType == "flint_day_context", let context = block.dayContext else { return nil }
                let dated = FlintDayContext(date: context.date ?? digest.date, calendar: context.calendar, birthdays: context.birthdays, weather: context.weather)
                guard let day = dated.day(in: calendar),
                      calendar.isDate(day, inSameDayAs: now) || calendar.isDate(day, inSameDayAs: tomorrow) else { return nil }
                return dated
            }
        }.last
    }

    private func visibleUnreadItems(from items: [UpToSpeedItem]) -> [UpToSpeedItem] {
        UpToSpeedVisibility(now: .now, calendar: .current).visibleUnreadItems(from: items)
    }

    private func caughtUpItems(from items: [UpToSpeedItem]) -> [UpToSpeedItem] {
        UpToSpeedVisibility(now: .now, calendar: .current).caughtUpItems(from: items)
    }

    private func expandFlintItem(item: UpToSpeedItem, digest: FlintDigest?) -> [UpToSpeedScreen] {
        // Detail before feed, matching `primaryDigestSummary` and `digestTitle`.
        // They are separately decoded fields and can differ, and the detail
        // fetch is the fuller record — building the cards from one and the
        // yesterday recap from the other is how they drift apart.
        let sections = UpToSpeedParsing.digestCards(
            from: digest?.summary ?? digestSummary(item) ?? ""
        )

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

    /// The server resolves this now. The title and block heuristics remain as
    /// a fallback for responses that predate the `kind` field — presentation
    /// should not depend on how a digest happened to be named.
    private func declaredKind(_ item: UpToSpeedItem) -> FlintDigestKind? {
        guard case .flintDigest(let summary) = item.payload else { return nil }
        return summary.kind
    }

    private func isNewsRoundupDigest(item: UpToSpeedItem, title: String, digest: FlintDigest?) -> Bool {
        if let kind = declaredKind(item) { return kind == .newsRoundup }

        let lowered = title.lowercased()
        if lowered.contains("news") || lowered.contains("roundup") { return true }
        guard let digest else { return false }
        let contentBlocks = digest.blocks.filter {
            !$0.isQuestion
                && $0.blockType != "flint_editorial_note"
                && $0.blockType != "flint_day_context"
        }
        return !contentBlocks.isEmpty && contentBlocks.allSatisfy { $0.blockType == "flint_news" }
    }

    private func isReadingListDigest(item: UpToSpeedItem, title: String, digest: FlintDigest?) -> Bool {
        if let kind = declaredKind(item) { return kind == .readingList }

        let lowered = title.lowercased()
        if lowered.contains("reading list") || lowered.contains("saved to read") { return true }
        if let digest, digest.blocks.contains(where: { $0.blockType == "flint_reading_pick" }) { return true }
        return lowered.contains("reading") && (digest?.blocks.isEmpty ?? true)
    }

    private func makeGreeting() -> String {
        let slot = SparkTimeOfDay.from(date: .now)
        let weekday = Date.now.formatted(.dateTime.weekday(.wide))
        let base: String
        switch slot {
        case .morning: base = "Good \(weekday) morning"
        case .day: base = "Good \(weekday) afternoon"
        case .evening: base = "Good \(weekday) evening"
        case .night: base = "Still up"
        }
        if let name = profileName, !name.isEmpty {
            return "\(base), \(name)."
        }
        return "\(base)."
    }

    private func enqueueMarkRead(itemID: String, type: UpToSpeedItemType) {
        enqueueMarkRead(UpToSpeedReadRef(type: type, id: itemID))
    }

    private func enqueueMarkRead(_ ref: UpToSpeedReadRef) {
        guard !restoredIDs.contains(ref.id) else { return }
        if sessionSeenDates[ref.id] == nil { sessionSeenDates[ref.id] = .now }
        updateRecap()
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
        if case .checkIn(let summary) = item.payload { return summary.completed }
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
