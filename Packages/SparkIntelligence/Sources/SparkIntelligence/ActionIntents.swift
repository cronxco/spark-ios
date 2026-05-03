import AppIntents
import Foundation
import SparkKit

// MARK: - Log Check-In

public struct LogCheckInIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Check-In"
    public static let description = IntentDescription("Log a mood check-in in Spark.")
    public static let openAppWhenRun: Bool = true

    @Parameter(title: "Mood", optionsProvider: MoodOptionsProvider())
    public var mood: String

    @Parameter(title: "Note")
    public var note: String?

    public init() {}
    public init(mood: String, note: String? = nil) {
        self.mood = mood
        self.note = note
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = await IntentService()
        let checkIn = CheckIn(
            slot: currentSlot(),
            mood: mood,
            tags: [],
            note: note
        )
        _ = try? await service.apiClient.request(CheckInsEndpoint.create(checkIn))
        return .result(dialog: "Check-in logged. Feeling \(mood).")
    }

    private func currentSlot() -> String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }
}

private struct MoodOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        ["great", "good", "okay", "low", "stressed", "tired", "energised", "calm", "anxious", "grateful"]
    }
}

// MARK: - Add Bookmark

public struct AddBookmarkIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add Bookmark"
    public static let description = IntentDescription("Bookmark a URL in Spark.")

    @Parameter(title: "URL")
    public var url: URL

    public init() {}
    public init(url: URL) { self.url = url }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = await IntentService()
        let body = try? JSONEncoder().encode(["url": url.absoluteString])
        let endpoint = Endpoint<EmptyResponse>(
            method: .post,
            path: "/bookmarks",
            body: body,
            contentType: "application/json"
        )
        _ = try? await service.apiClient.request(endpoint)
        return .result(dialog: "Bookmarked \(url.host ?? url.absoluteString).")
    }
}

// MARK: - Start / End Sleep

public struct StartSleepIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start Sleep"
    public static let description = IntentDescription("Start tracking sleep in Spark.")
    public static let openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            IntentService.setPendingRoute("action:startSleep")
        }
        return .result(dialog: "Starting sleep tracking. Good night!")
    }
}

public struct EndSleepIntent: AppIntent {
    public static let title: LocalizedStringResource = "End Sleep"
    public static let description = IntentDescription("Stop sleep tracking and see your score.")
    public static let openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            IntentService.setPendingRoute("action:endSleep")
        }
        return .result(dialog: "Sleep tracking stopped. Check your score in Spark.")
    }
}

// MARK: - Open intents (navigate to specific screens)

public struct OpenTodayIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Spark Today"
    public static let description = IntentDescription("Open the Spark Today view.")
    public static let openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            IntentService.setPendingRoute("today")
        }
        return .result()
    }
}

public struct OpenEventIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Event"
    public static let description = IntentDescription("Open a specific Spark event.")
    public static let openAppWhenRun: Bool = true

    @Parameter(title: "Event ID")
    public var eventID: String

    public init() {}
    public init(eventID: String) { self.eventID = eventID }

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            IntentService.setPendingRoute("event:\(eventID)")
        }
        return .result()
    }
}

public struct OpenMetricIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Metric"
    public static let description = IntentDescription("Open a Spark metric detail view.")
    public static let openAppWhenRun: Bool = true

    @Parameter(title: "Metric")
    public var identifier: String

    public init() {}
    public init(identifier: String) { self.identifier = identifier }

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            IntentService.setPendingRoute("metric:\(identifier)")
        }
        return .result()
    }
}

// MARK: - Search Spark

public struct SearchSparkIntent: AppIntent {
    public static let title: LocalizedStringResource = "Search Spark"
    public static let description = IntentDescription("Search your Spark data.")
    public static let openAppWhenRun: Bool = true

    @Parameter(title: "Query")
    public var query: String

    public init() {}
    public init(query: String) { self.query = query }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            IntentService.setPendingRoute("search:\(query)")
        }
        return .result(dialog: "Opening Spark with search for \(query).")
    }
}

// MARK: - Acknowledge Anomaly

public struct AcknowledgeAnomalyIntent: AppIntent {
    public static let title: LocalizedStringResource = "Acknowledge Anomaly"
    public static let description = IntentDescription("Acknowledge a Spark anomaly.")

    @Parameter(title: "Anomaly ID")
    public var anomalyID: String

    public init() {}
    public init(anomalyID: String) { self.anomalyID = anomalyID }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Phase 3 D12: wire to AnomaliesEndpoint.acknowledge(id:) once endpoint exists.
        return .result(dialog: "Anomaly acknowledged.")
    }
}

// MARK: - Shared types

private struct EmptyResponse: Decodable, Sendable {}
