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

    /// How far back "recent" reaches for the question stack, in the server's
    /// relative-window syntax.
    private static let questionWindow = "48h"

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
        // One request, on any day at any hour: before the morning brief has
        // run, the server's "latest" is last night's evening digest.
        do {
            latestDigest = try await apiClient.request(FlintEndpoint.latest(kind: .briefing))
        } catch where error.isAPICancellation {
            return
        } catch APIError.httpStatus(404, _, _) {
            // No briefing has ever been written for this account. Not an
            // error worth reporting — the card simply is not there.
            latestDigest = nil
        } catch {
            SparkObservability.captureHandled(error)
        }
    }

    private func loadRecentQuestions() async {
        do {
            // Status and window are both applied by the server now, in one
            // request, where this used to be two unbounded fetches filtered
            // on the device.
            let window = Self.questionWindow
            let questions = try await apiClient.collectAllPages(maxPages: 3) { cursor in
                FlintEndpoint.questions(
                    statuses: [.open, .answered],
                    since: window,
                    cursor: cursor
                )
            }
            recentQuestions = Self.orderForStack(questions)
        } catch where error.isAPICancellation {
            return
        } catch {
            SparkObservability.captureHandled(error)
        }
    }

    /// Open questions first, then answered ones, newest first within each —
    /// the stack leads with what is wanted and keeps what was already said.
    /// Presentation order, so it stays here.
    static func orderForStack(_ questions: [FlintQuestion]) -> [FlintQuestion] {
        let newestFirst: (FlintQuestion, FlintQuestion) -> Bool = {
            ($0.askedAt ?? .distantPast) > ($1.askedAt ?? .distantPast)
        }
        let open = questions.filter { $0.status == .open }.sorted(by: newestFirst)
        let answered = questions.filter { $0.status == .answered }.sorted(by: newestFirst)
        return open + answered
    }

    private func loadTopics() async {
        do {
            // Two small filtered lists rather than every thread ever: the
            // strip shows active threads and a line for dormant ones, never
            // the resolved or expired ones.
            async let active = apiClient.collectAllPages { cursor in
                FlintTopicsEndpoint.list(status: .active, cursor: cursor)
            }
            async let dormant = apiClient.collectAllPages { cursor in
                FlintTopicsEndpoint.list(status: .dormant, cursor: cursor)
            }
            topics = try await active + dormant
        } catch where error.isAPICancellation {
            return
        } catch {
            SparkObservability.captureHandled(error)
        }
    }

    private func loadMoneyContext() async {
        do {
            async let accountsRequest = apiClient.collectAllPages { cursor in
                MoneyEndpoint.accounts(cursor: cursor)
            }
            async let netWorthRequest = apiClient.request(MoneyEndpoint.netWorth(compare: .oneMonth))
            let (accounts, netWorth) = try await (accountsRequest, netWorthRequest)
            moneyContext = Self.moneyContext(accounts: accounts, netWorth: netWorth.data)
        } catch where error.isAPICancellation {
            return
        } catch {
            SparkObservability.captureHandled(error)
        }
    }

    /// The account the user pinned; failing that, the first current account,
    /// so the card is useful before anyone has chosen. Net worth's change is
    /// the server's comparison, which already leaves out accounts whose
    /// history does not span the month on both sides.
    static func moneyContext(accounts: [MoneyAccount], netWorth: NetWorth) -> MoneyContext {
        var context = MoneyContext()

        let pinned = accounts.first(where: \.pinned)
            ?? accounts.first { ($0.accountType ?? $0.kind).lowercased().contains("current") }
        if let pinned, let balance = pinned.latestBalance {
            context.pinnedAccountLabel = pinned.title
            context.pinnedAccountBalance = DayMetrics.currency(
                pinned.isNegativeBalance ? -abs(balance.balance) : balance.balance,
                code: balance.currency
            )
        }

        if let comparison = netWorth.comparison {
            let change = comparison.change
            if abs(change) < 1 {
                context.netWorthChange = "level"
            } else {
                let formatted = DayMetrics.currency(abs(change), code: netWorth.currency)
                context.netWorthChange = (change > 0 ? "+" : "\u{2212}") + formatted
            }
        }
        return context
    }

    /// Answers through `POST /flint/questions/{id}/actions`, which checks the
    /// question's version and carries an idempotency key, and returns the
    /// updated question so the stack updates in place. The older `/answer`
    /// endpoint this used is deprecated server-side.
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
            recentQuestions = Self.orderForStack(
                recentQuestions.map { $0.id == updated.id ? updated : $0 }
            )
        } catch where error.isAPICancellation {
            return
        } catch let error as APIError where error.isPreconditionFailure {
            // Answered or changed elsewhere since the stack loaded: take the
            // server's current state rather than overwrite it.
            await loadRecentQuestions()
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
            existing.groupKey = event.groupKey
            existing.direction = event.direction?.rawValue
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
                targetMediaUrl: event.target?.mediaUrl,
                groupKey: event.groupKey,
                direction: event.direction?.rawValue
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
