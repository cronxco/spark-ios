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
                upsertRawAPIEntry(title: "GET /today?date=\(Self.isoKey(for: date))", body: response.utf8Body)
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
                    let response = try await apiClient.requestWithRawResponse(FeedEndpoint.feed(cursor: cursor, limit: 100, date: dateKey))
                    page = response.decoded
                    let cursorSuffix = cursor.map { "&cursor=\($0)" } ?? ""
                    upsertRawAPIEntry(title: "GET /feed?date=\(dateKey)&limit=100\(cursorSuffix)", body: response.utf8Body)
                #else
                    page = try await apiClient.request(FeedEndpoint.feed(cursor: cursor, limit: 100, date: dateKey))
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

    private func revalidateUpToSpeed() async {
        #if DEBUG
        do {
            let response = try await apiClient.requestWithRawResponse(UpToSpeedEndpoint.feed())
            upsertRawAPIEntry(title: "GET /up-to-speed/feed", body: response.utf8Body)
        } catch APIError.httpStatus(let code, let data, _) {
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "(no body)"
            upsertRawAPIEntry(title: "GET /up-to-speed/feed [HTTP \(code)]", body: body)
        } catch {
            upsertRawAPIEntry(title: "GET /up-to-speed/feed [error]", body: error.localizedDescription)
        }
        #else
            _ = try? await apiClient.request(UpToSpeedEndpoint.feed())
        #endif
    }

    /// Records a raw response body for the debug inspector.
    ///
    /// A no-op in release: the bodies are unfiltered transport payloads, and
    /// keeping them out of memory entirely is stronger than only declining to
    /// render them. RawFeedJSONView is likewise debug-only.
    #if DEBUG
        private func upsertRawAPIEntry(title: String, body: String) {
            rawAPIEntries.removeAll { $0.title == title }
            rawAPIEntries.append(RawFeedJSONEntry(title: title, body: body))
        }
    #endif

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
