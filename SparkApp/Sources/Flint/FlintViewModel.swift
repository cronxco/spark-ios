import Foundation
import Observation
import OSLog
import SparkKit
import SwiftData

@MainActor
@Observable
final class FlintViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    private static let promptVersion = "flint-daily-note-v1"
    private static let cachePrefix = "spark.flint.dailyNote"

    private(set) var state: LoadState = .idle
    private(set) var note: FlintDailyNote?
    private(set) var facts: FlintBriefingFacts?
    private(set) var generationAvailability: FlintGenerationAvailability = .unavailable
    private(set) var usedAppleIntelligence = false

    private let date: Date
    private let apiClient: APIClient
    private let container: ModelContainer
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "Flint")
    private var generationTask: Task<Void, Never>?

    init(
        date: Date = .now,
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
        guard state == .idle else { return }
        state = .loading
        loadCachedSummary()
        await revalidate()
    }

    func refresh() async {
        state = .loading
        await revalidate(force: true)
    }

    var generationStatusMessage: String {
        switch generationAvailability {
        case .available where usedAppleIntelligence:
            return "Generated on device with Apple Intelligence"
        case .deviceNotEligible:
            return "Apple Intelligence is not available on this device"
        case .appleIntelligenceNotEnabled:
            return "Using Spark's briefing because Apple Intelligence is off"
        case .modelNotReady:
            return "Using Spark's briefing while Apple Intelligence gets ready"
        case .available, .unavailable:
            return "Using Spark's briefing"
        }
    }

    private func loadCachedSummary() {
        guard let summary = cachedSummary() else { return }
        apply(summary: summary)
    }

    private func revalidate(force: Bool = false) async {
        do {
            let summary = try await apiClient.request(
                BriefingEndpoint.today(date: Self.isoKey(for: date))
            )
            await persist(summary)
            apply(summary: summary)
        } catch APIError.notModified {
            if note == nil, let summary = cachedSummary() {
                apply(summary: summary)
            }
        } catch where error.isAPICancellation {
            if note == nil {
                state = .idle
            }
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Flint briefing failed: \(String(describing: error))")
            if note == nil {
                state = .error(force ? userFacingError(error) : "Couldn't load today's briefing.")
            }
        }
    }

    private func apply(summary: DaySummary) {
        generationTask?.cancel()

        let facts = FlintBriefingFacts(summary: summary)
        self.facts = facts

        let cacheKey = noteCacheKey(for: summary)
        if let cached = cachedNote(forKey: cacheKey) {
            note = cached
            generationAvailability = .available
            usedAppleIntelligence = true
            state = .loaded
            return
        }

        note = facts.fallbackNote
        generationAvailability = .unavailable
        usedAppleIntelligence = false
        state = .loaded

        generationTask = Task {
            do {
                let result = try await FlintGenerationService.generateNote(from: facts)
                guard !Task.isCancelled else { return }
                note = result.note
                generationAvailability = result.availability
                usedAppleIntelligence = result.usedAppleIntelligence
                state = .loaded
                if result.usedAppleIntelligence {
                    cache(note: result.note, forKey: cacheKey)
                }
            } catch where error.isAPICancellation {
            } catch {
                SparkObservability.captureHandled(error)
                logger.error("Flint note generation failed: \(String(describing: error))")
                generationAvailability = .unavailable
                usedAppleIntelligence = false
                state = .loaded
            }
        }
    }

    private func cachedSummary() -> DaySummary? {
        let key = Self.isoKey(for: date)
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedDaySummary>(predicate: #Predicate { $0.date == key })
        guard let cached = (try? context.fetch(descriptor))?.first else { return nil }
        return try? cached.decoded()
    }

    private func persist(_ summary: DaySummary) async {
        let context = ModelContext(container)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(summary) else { return }
        let key = Self.isoKey(for: date)
        let descriptor = FetchDescriptor<CachedDaySummary>(predicate: #Predicate { $0.date == key })
        if let existing = (try? context.fetch(descriptor))?.first {
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
        try? context.save()
    }

    private func cachedNote(forKey key: String) -> FlintDailyNote? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FlintDailyNote.self, from: data)
    }

    private func cache(note: FlintDailyNote, forKey key: String) {
        guard let data = try? JSONEncoder().encode(note) else { return }
        defaults.set(data, forKey: key)
    }

    private func noteCacheKey(for summary: DaySummary) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(summary)) ?? Data(summary.date.utf8)
        return "\(Self.cachePrefix).\(Self.promptVersion).\(summary.date).\(Self.stableHash(data))"
    }

    private static func stableHash(_ data: Data) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private func userFacingError(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Couldn't load today's briefing."
    }

    static func isoKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
