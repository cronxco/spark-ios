import AppIntents
import Foundation
import SparkKit

// MARK: - Log Check-In

public struct LogCheckInIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Check-In"
    public static let description = IntentDescription("Open Spark to log a check-in.")
    public static let openAppWhenRun: Bool = true

    @Parameter(title: "Physical Energy (1–5)")
    public var physical: Int

    @Parameter(title: "Mental Energy (1–5)")
    public var mental: Int

    @Parameter(title: "Note")
    public var note: String?

    public init() {
        self.physical = 3
        self.mental = 3
    }
    public init(physical: Int, mental: Int, note: String? = nil) {
        self.physical = max(1, min(5, physical))
        self.mental = max(1, min(5, mental))
        self.note = note
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = await IntentService()
        let hour = Calendar.current.component(.hour, from: .now)
        let period: CheckInPeriod = hour < 12 ? .morning : .afternoon
        let dateKey = Self.isoDate(.now)
        let request = CheckInRequest(
            period: period,
            physical: max(1, min(5, physical)),
            mental: max(1, min(5, mental)),
            date: dateKey,
            notes: note
        )
        _ = try? await service.apiClient.request(CheckInsEndpoint.submit(request))
        await IntentDonations.donate(self)
        return .result(dialog: "Check-in logged. Physical \(physical)/5, mental \(mental)/5.")
    }

    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
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
        await IntentDonations.donate(self)
        return .result()
    }
}

public struct OpenEventIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Event"
    public static let description = IntentDescription("Open a specific Spark event.")
    public static let openAppWhenRun: Bool = true

    @Parameter(title: "Event")
    public var event: EventEntity

    public init() {}
    public init(event: EventEntity) { self.event = event }

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            IntentService.setPendingRoute("event:\(event.id)")
        }
        await IntentDonations.donate(self)
        return .result()
    }
}

public struct OpenMetricIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Metric"
    public static let description = IntentDescription("Open a Spark metric detail view.")
    public static let openAppWhenRun: Bool = true

    @Parameter(title: "Metric")
    public var metric: MetricEntity

    public init() {}
    public init(metric: MetricEntity) { self.metric = metric }

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            IntentService.setPendingRoute("metric:\(metric.id)")
        }
        await IntentDonations.donate(self)
        return .result()
    }
}

public struct OpenPlaceIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Place"
    public static let description = IntentDescription("Open a Spark place detail view.")
    public static let openAppWhenRun: Bool = true

    @Parameter(title: "Place")
    public var place: PlaceEntity

    public init() {}
    public init(place: PlaceEntity) { self.place = place }

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            IntentService.setPendingRoute("place:\(place.id)")
        }
        await IntentDonations.donate(self)
        return .result()
    }
}

public struct OpenAnomalyIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Anomaly"
    public static let description = IntentDescription("Open a Spark anomaly to see the details.")
    public static let openAppWhenRun: Bool = true

    @Parameter(title: "Anomaly")
    public var anomaly: AnomalyEntity

    public init() {}
    public init(anomaly: AnomalyEntity) { self.anomaly = anomaly }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            IntentService.setPendingRoute("anomaly:\(anomaly.id)")
        }
        await IntentDonations.donate(self)
        return .result(dialog: "\(anomaly.summary)")
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
    public static let description = IntentDescription("Acknowledge a Spark anomaly so it stops being flagged.")

    @Parameter(title: "Anomaly")
    public var anomaly: AnomalyEntity

    public init() {}
    public init(anomaly: AnomalyEntity) { self.anomaly = anomaly }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = await IntentService()
        _ = try await service.apiClient.request(AnomaliesEndpoint.acknowledge(id: anomaly.id))
        await MainActor.run { IntentService.markAnomalyAcknowledged(id: anomaly.id) }
        await IntentDonations.donate(self)
        return .result(dialog: "Acknowledged: \(anomaly.summary)")
    }
}

// MARK: - Intent donations

/// Centralises the iOS 27 `IntentDonationManager` calls so Siri can learn the
/// user's patterns after each successful perform. Donation failures are
/// non-fatal — they only degrade Siri's suggestions, never the action.
enum IntentDonations {
    static func donate(_ intent: some AppIntent) async {
        _ = try? await IntentDonationManager.shared.donate(intent: intent)
    }
}
