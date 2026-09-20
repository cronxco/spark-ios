import Foundation
import Observation
import SparkKit
import SwiftData
import WidgetKit

enum TodayNetworkState: Equatable {
    case idle
    case loading
    case error(String)
}

@MainActor
@Observable
final class TodayViewModel {
    let date: Date
    private(set) var cached: DaySummary?
    private(set) var briefingSummaryLine: String?
    #if DEBUG
        private(set) var rawAPIEntries: [RawFeedJSONEntry] = []
    #endif
    private(set) var networkState: TodayNetworkState = .idle
    private(set) var checkInDayStatus: CheckInDayStatus = .allPending

    /// The newest thing Flint has written, which before the morning brief has
    /// run is last night's evening digest rather than nothing.
    private(set) var latestDigest: FlintDigest?
    /// Open questions first, then ones answered inside the window, so the
    /// stack shows both what is wanted and what was already said.
    private(set) var recentQuestions: [FlintQuestion] = []
    private(set) var topics: [FlintTopic] = []
    private(set) var moneyContext: MoneyContext = .empty

    /// How far back "recent" reaches for the question stack.
    private static let questionWindow: TimeInterval = 48 * 3600

    var metrics: DayMetrics {
        DayMetrics(summary: cached, money: moneyContext)
    }

    private let apiClient: APIClient
    private let container: ModelContainer
    private let defaults: UserDefaults
    private var summaryLineTask: Task<Void, Never>?

    private static let summaryLinePromptVersion = "today-hero-summary-v2"
    private static let summaryLineCachePrefix = "spark.today.heroSummary"

    init(
        date: Date,
        apiClient: APIClient,
        container: ModelContainer,
        defaults: UserDefaults = .sparkAppGroup
    ) {
        self.date = date
        self.apiClient = apiClient
        self.container = container
        self.defaults = defaults
    }

    func load() async {
        loadCached()
        loadCachedCheckIns()
        await revalidate()
        await revalidateCheckIns()
        await loadFeed()
        await revalidateUpToSpeed()
        await loadFlintSurfaces()
    }

    /// The digest opener, the question stack, the threads and the money
    /// figures the day summary does not carry. Each is independent and each
    /// failure is survivable — a missing digest hides one card, it does not
    /// empty the screen — so they run concurrently and swallow their errors.
    func loadFlintSurfaces() async {
        async let digest: Void = loadLatestDigest()
        async let questions: Void = loadRecentQuestions()
        async let threads: Void = loadTopics()
        async let money: Void = loadMoneyContext()
        _ = await (digest, questions, threads, money)
    }

    private func loadLatestDigest() async {
        // Today's newest run first; before it has happened, yesterday's.
        // Calendar rather than a 86,400-second step: on the two days a year
        // the clocks move, subtracting a flat day lands on the wrong date.
        let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: date)
        let keys = [date, previousDay].compactMap { $0 }.map(Self.isoKey(for:))
        for key in keys {
            do {
                let response = try await apiClient.request(FlintEndpoint.digests(date: key, all: true))
                let newest = response.digests
                    .filter { $0.kind != .newsRoundup }
                    .max { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
                if let newest, newest.opener != nil {
                    latestDigest = newest
                    return
                }
            } catch where error.isAPICancellation {
                return
            } catch {
                SparkObservability.captureHandled(error)
            }
        }
    }

    private func loadRecentQuestions() async {
        do {
            async let openResponse = apiClient.request(FlintEndpoint.questions(status: .open))
            async let answeredResponse = apiClient.request(FlintEndpoint.questions(status: .answered))
            let (open, answered) = try await (openResponse, answeredResponse)

            let cutoff = Date.now.addingTimeInterval(-Self.questionWindow)
            func withinWindow(_ question: FlintQuestion) -> Bool {
                guard let asked = question.askedAt else { return false }
                return asked >= cutoff
            }

            let sortedOpen = open.data
                .filter(withinWindow)
                .sorted { ($0.askedAt ?? .distantPast) > ($1.askedAt ?? .distantPast) }
            let sortedAnswered = answered.data
                .filter(withinWindow)
                .sorted { ($0.askedAt ?? .distantPast) > ($1.askedAt ?? .distantPast) }

            recentQuestions = sortedOpen + sortedAnswered
        } catch where error.isAPICancellation {
            return
        } catch {
            SparkObservability.captureHandled(error)
        }
    }

    private func loadTopics() async {
        do {
            let response = try await apiClient.request(FlintTopicsEndpoint.list())
            topics = response.data.filter {
                $0.status?.isActive == true || $0.status == .dormant
            }
        } catch where error.isAPICancellation {
            return
        } catch {
            SparkObservability.captureHandled(error)
        }
    }

    /// Balances are their own resource, and there is no "pinned" flag on an
    /// account yet — the first current account stands in for one.
    private func loadMoneyContext() async {
        do {
            let response = try await apiClient.request(MoneyEndpoint.accounts())
            let accounts = response.data
            guard !accounts.isEmpty else { return }

            let pinned = accounts.first { ($0.accountType ?? $0.kind).lowercased().contains("current") }
                ?? accounts.first

            var context = MoneyContext()
            if let pinned, let balance = pinned.latestBalance {
                context.pinnedAccountLabel = pinned.title
                context.pinnedAccountBalance = DayMetrics.currency(
                    pinned.isNegativeBalance ? -abs(balance.balance) : balance.balance,
                    code: balance.currency
                )
            }
            context.netWorthChange = await netWorthChange(for: accounts)
            moneyContext = context
        } catch where error.isAPICancellation {
            return
        } catch {
            SparkObservability.captureHandled(error)
        }
    }

    /// Net worth now against the closest balance on or before a month ago.
    /// Accounts whose history does not reach back that far are left out of
    /// both sides, so the comparison stays like-for-like.
    private func netWorthChange(for accounts: [MoneyAccount]) async -> String? {
        guard let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: .now) else {
            return nil
        }

        var histories: [String: [BalanceEntry]] = [:]
        await withTaskGroup(of: (String, [BalanceEntry]).self) { group in
            for account in accounts {
                group.addTask { [apiClient] in
                    let response = try? await apiClient.request(
                        MoneyEndpoint.balances(accountId: account.id)
                    )
                    return (account.id, response?.data ?? [])
                }
            }
            for await (id, entries) in group {
                histories[id] = entries
            }
        }

        var now = 0.0
        var then = 0.0
        var currency = "GBP"
        var comparable = false

        for account in accounts {
            let entries = (histories[account.id] ?? []).sorted { $0.time < $1.time }
            guard let latest = entries.last,
                  let earlier = entries.last(where: { $0.time <= monthAgo })
            else { continue }
            // A debt account counts against net worth, the same rule the
            // money explore screen applies.
            func adjusted(_ balance: Double) -> Double {
                account.isNegativeBalance ? -abs(balance) : balance
            }
            now += adjusted(latest.balance)
            then += adjusted(earlier.balance)
            currency = latest.currency
            comparable = true
        }

        guard comparable else { return nil }
        let delta = now - then
        guard abs(delta) >= 1 else { return "level" }
        let formatted = DayMetrics.currency(abs(delta), code: currency)
        return (delta > 0 ? "+" : "\u{2212}") + formatted
    }

    func answer(question: FlintQuestion, with option: String) async {
        do {
            _ = try await apiClient.request(
                FlintEndpoint.answerQuestion(
                    blockID: question.id,
                    FlintQuestionAnswerRequest(answer: option)
                )
            )
            await loadRecentQuestions()
        } catch where error.isAPICancellation {
            return
        } catch {
            SparkObservability.captureHandled(error)
        }
    }

    func refresh() async {
        await revalidate(force: true)
        await revalidateCheckIns()
    }

    func backgroundRevalidate() async {
        await revalidate(force: false, silent: true)
        await revalidateCheckIns()
    }

    func loadCheckIns() async {
        loadCachedCheckIns()
        await revalidateCheckIns()
    }

    func submitCheckIn(request: CheckInRequest) async throws {
        let event = try await apiClient.request(CheckInsEndpoint.submit(request))
        let context = ModelContext(container)
        CachedCheckIn.upsert(
            date: request.date,
            period: request.period,
            completed: true,
            physical: request.physical,
            mental: request.mental,
            notes: request.notes.flatMap { $0.isEmpty ? nil : $0 },
            eventId: event.id,
            in: context
        )
        try? context.save()
        loadCachedCheckIns()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func loadCachedCheckIns() {
        let key = Self.isoKey(for: date)
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedCheckIn>(
            predicate: #Predicate { $0.date == key }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        let morningRow = rows.first { $0.period == "morning" }
        let afternoonRow = rows.first { $0.period == "afternoon" }

        func status(from row: CachedCheckIn?) -> PeriodStatus {
            guard let row, row.completed, let phy = row.physical, let men = row.mental else {
                return .pending
            }
            return .completed(physical: phy, mental: men, notes: row.notes)
        }

        checkInDayStatus = CheckInDayStatus(
            morning: status(from: morningRow),
            afternoon: status(from: afternoonRow)
        )
    }

    private func revalidateCheckIns() async {
        let key = Self.isoKey(for: date)
        do {
            let status: CheckInDayResponse
            #if DEBUG
                let response = try await apiClient.requestWithRawResponse(CheckInsEndpoint.today(date: key))
                status = response.decoded
                upsertRawAPIEntry(title: "GET /check-ins/today?date=\(key)", body: response.utf8Body)
            #else
                status = try await apiClient.request(CheckInsEndpoint.today(date: key))
            #endif

            let context = ModelContext(container)

            func upsertPeriod(_ detail: CheckInPeriodDetail, period: CheckInPeriod) {
                CachedCheckIn.upsert(
                    date: key,
                    period: period,
                    completed: detail.completed,
                    physical: detail.event?.physical(),
                    mental: detail.event?.mental(),
                    eventId: detail.event?.id,
                    in: context
                )
            }

            upsertPeriod(status.morning, period: .morning)
            upsertPeriod(status.afternoon, period: .afternoon)
            try? context.save()
            loadCachedCheckIns()
        } catch APIError.notModified {
        } catch is CancellationError {
        } catch APIError.transport(let underlying)
            where (underlying as? URLError)?.code == .cancelled {
        } catch {
            // Non-fatal: check-in status uses cached data if network fails
        }
    }

    private func loadCached() {
        let key = Self.isoKey(for: date)
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedDaySummary>(predicate: #Predicate { $0.date == key })
        if let cached = try? context.fetch(descriptor).first,
           let decoded = try? cached.decoded() {
            apply(summary: decoded)
        }
    }

    private func revalidate(force: Bool = false, silent: Bool = false) async {
        if !silent { networkState = .loading }
        do {
            let summary: DaySummary
            #if DEBUG
                let response = try await apiClient.requestWithRawResponse(
                    BriefingEndpoint.today(date: Self.isoKey(for: date))
                )
                summary = response.decoded
                upsertRawAPIEntry(title: "GET /briefing/today?date=\(Self.isoKey(for: date))", body: response.utf8Body)
            #else
                summary = try await apiClient.request(
                    BriefingEndpoint.today(date: Self.isoKey(for: date))
                )
            #endif

            apply(summary: summary)
            try await persist(summary)
            networkState = .idle
        } catch APIError.notModified {
            networkState = .idle
        } catch APIError.transport(let underlying)
            where (underlying as? URLError)?.code == .cancelled {
            // Task cancelled (e.g. page swiped away) — not a user-visible error
            networkState = .idle
        } catch is CancellationError {
            networkState = .idle
        } catch {
            SparkObservability.captureHandled(error)
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            networkState = force ? .error(message) : (cached == nil ? .error(message) : .idle)
        }
    }

    private func loadFeed() async {
        do {
            var cursor: String?
            let dateKey = Self.isoKey(for: date)
            let context = ModelContext(container)

            repeat {
                let page: Page<Event>
                #if DEBUG
                    let response = try await apiClient.requestWithRawResponse(
                        FeedEndpoint.feed(cursor: cursor, limit: 100, date: dateKey)
                    )
                    page = response.decoded
                    upsertRawAPIEntry(
                        title: "GET /feed?date=\(dateKey)&limit=100&cursor=\(cursor ?? "initial")",
                        body: response.utf8Body
                    )
                #else
                    page = try await apiClient.request(
                        FeedEndpoint.feed(cursor: cursor, limit: 100, date: dateKey)
                    )
                #endif

                for event in page.data {
                    upsert(event, in: context)
                }
                cursor = page.hasMore ? page.nextCursor : nil
            } while cursor != nil

            try? context.save()
        } catch APIError.notModified {
            // feed unchanged — no action needed
        } catch is CancellationError {
        } catch APIError.transport(let underlying)
            where (underlying as? URLError)?.code == .cancelled {
        } catch { /* non-fatal */ }
    }

    private func revalidateUpToSpeed() async {
        #if DEBUG
        do {
            let response = try await apiClient.requestWithRawResponse(UpToSpeedEndpoint.feed())
            upsertRawAPIEntry(title: "GET /up-to-speed", body: response.utf8Body)
        } catch APIError.httpStatus(let code, let data, _) {
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "(no body)"
            upsertRawAPIEntry(title: "GET /up-to-speed [HTTP \(code)]", body: body)
        } catch {
            upsertRawAPIEntry(title: "GET /up-to-speed [error]", body: error.localizedDescription)
        }
        #else
            _ = try? await apiClient.request(UpToSpeedEndpoint.feed())
        #endif
    }

    #if DEBUG
        private func upsertRawAPIEntry(title: String, body: String) {
            rawAPIEntries.removeAll { $0.title == title }
            rawAPIEntries.append(RawFeedJSONEntry(title: title, body: body))
        }
    #endif

    private func upsert(_ event: Event, in context: ModelContext) {
        let eventId = event.id
        let descriptor = FetchDescriptor<CachedEvent>(
            predicate: #Predicate { $0.id == eventId }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.time = event.time
            existing.service = event.service
            existing.domain = event.domain
            existing.action = event.action
            existing.value = event.value
            existing.unit = event.unit
            existing.url = event.url
            existing.displayName = event.displayName
            existing.hidden = event.hidden
            existing.displayWithObject = event.displayWithObject
            existing.displayValue = event.displayValue
            existing.tagNames = CachedEvent.encodeTagNames(event.tags)
            existing.blocksCount = event.blocksCount
            existing.actorTitle = event.actor?.title
            existing.actorType = event.actor?.type
            existing.actorMediaUrl = event.actor?.mediaUrl
            existing.targetTitle = event.target?.title
            existing.targetType = event.target?.type
            existing.targetMediaUrl = event.target?.mediaUrl
            existing.lastSyncedAt = .now
        } else {
            context.insert(CachedEvent(
                id: event.id,
                time: event.time,
                service: event.service,
                domain: event.domain,
                action: event.action,
                value: event.value,
                unit: event.unit,
                url: event.url,
                displayName: event.displayName,
                hidden: event.hidden,
                displayWithObject: event.displayWithObject,
                displayValue: event.displayValue,
                tagNames: CachedEvent.encodeTagNames(event.tags),
                blocksCount: event.blocksCount,
                actorTitle: event.actor?.title,
                actorType: event.actor?.type,
                actorMediaUrl: event.actor?.mediaUrl,
                targetTitle: event.target?.title,
                targetType: event.target?.type,
                targetMediaUrl: event.target?.mediaUrl
            ))
        }
    }

    private func persist(_ summary: DaySummary) async throws {
        let context = ModelContext(container)
        let data = try JSONEncoder().encode(summary)
        let key = Self.isoKey(for: date)

        let descriptor = FetchDescriptor<CachedDaySummary>(predicate: #Predicate { $0.date == key })
        if let existing = try context.fetch(descriptor).first {
            existing.payload = data
            existing.timezone = summary.timezone
            existing.lastSyncedAt = .now
        } else {
            context.insert(CachedDaySummary(
                date: key,
                timezone: summary.timezone,
                payload: data,
                lastSyncedAt: .now
            ))
        }
        try context.save()
    }

    private func apply(summary: DaySummary) {
        cached = summary
        generateSummaryLine(for: summary)
    }

    private func generateSummaryLine(for summary: DaySummary) {
        summaryLineTask?.cancel()

        guard let context = summaryLineContext else {
            briefingSummaryLine = nil
            return
        }

        let facts = FlintBriefingFacts(summary: summary)
        let cacheKey = summaryLineCacheKey(for: summary, context: context)
        if let cachedLine = defaults.string(forKey: cacheKey), !cachedLine.isEmpty {
            briefingSummaryLine = cachedLine
            return
        }

        briefingSummaryLine = facts.fallbackSummaryLine(context: context)

        summaryLineTask = Task {
            do {
                let result = try await FlintGenerationService.generateTodaySummaryLine(
                    from: facts,
                    context: context
                )
                guard !Task.isCancelled else { return }
                let line = sanitizedSummaryLine(result.note.summary)
                guard !line.isEmpty else { return }
                briefingSummaryLine = line
                if result.usedAppleIntelligence {
                    defaults.set(line, forKey: cacheKey)
                }
            } catch where error.isAPICancellation {
            } catch {
                SparkObservability.captureHandled(error)
            }
        }
    }

    private var summaryLineContext: FlintBriefingFacts.SummaryLineContext? {
        if Calendar.current.isDateInToday(date) {
            return .daySoFar
        }
        if date < Calendar.current.startOfDay(for: .now) {
            return .dayInReview
        }
        return nil
    }

    private func summaryLineCacheKey(
        for summary: DaySummary,
        context: FlintBriefingFacts.SummaryLineContext
    ) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(summary)) ?? Data(summary.date.utf8)
        let contextKey = switch context {
        case .daySoFar: "soFar"
        case .dayInReview: "review"
        }
        return "\(Self.summaryLineCachePrefix).\(Self.summaryLinePromptVersion).\(contextKey).\(summary.date).\(Self.stableHash(data))"
    }

    private func sanitizedSummaryLine(_ text: String) -> String {
        var line = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if line.hasPrefix("\""), line.hasSuffix("\""), line.count >= 2 {
            line.removeFirst()
            line.removeLast()
        }

        if line.count > 160 {
            let end = line.index(line.startIndex, offsetBy: 157)
            line = String(line[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }
        return line
    }

    private static func stableHash(_ data: Data) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    static func isoKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
