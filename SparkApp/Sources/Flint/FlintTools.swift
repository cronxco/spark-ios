import Foundation
import FoundationModels
import SparkKit
import SparkIntelligence

// MARK: - Flint tool calling (iOS 27 Foundation Models)
//
// Wraps Spark's data access as FoundationModels `Tool`s so the digest path can
// fetch on demand instead of being handed a fixed fact blob. Tools prefer the
// live API (via `IntentService`'s keychain-wired `APIClient`) and fall back to
// cached SwiftData reads, so they degrade gracefully offline.
//
// These are attached to the "deep" reasoning profile only; the quick summary
// line uses a lean profile with no tools to conserve PCC budget and latency.

/// Returns the compact day summary for a given date (defaults to today).
struct GetDaySummaryTool: Tool {
    typealias Output = String

    let name = "getDaySummary"
    let description = "Get Spark's compact day summary (sleep, activity, spend, anomalies) for a date."

    @Generable
    struct Arguments {
        @Guide(description: "ISO date yyyy-MM-dd. Omit or use 'today' for today.")
        var date: String?
    }

    func call(arguments: Arguments) async throws -> String {
        let dateKey = Self.resolveDate(arguments.date)
        let service = await IntentService()
        if let summary = try? await service.apiClient.request(BriefingEndpoint.today(date: dateKey)) {
            return Self.describe(summary)
        }
        // Offline fallback: today's cached snapshot.
        if let snapshot = await service.todaySnapshot() {
            return Self.describe(snapshot)
        }
        return "No day summary available for \(dateKey)."
    }

    private static func resolveDate(_ raw: String?) -> String {
        guard let raw, raw.lowercased() != "today", !raw.isEmpty else {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: .now)
        }
        return raw
    }

    private static func describe(_ summary: DaySummary) -> String {
        let snapshot = TodayIntentSnapshot(summary: summary)
        return describe(snapshot, date: summary.date, anomalies: summary.anomalies.count)
    }

    private static func describe(_ snapshot: TodayIntentSnapshot) -> String {
        describe(snapshot, date: "today", anomalies: snapshot.anomalyCount)
    }

    private static func describe(_ s: TodayIntentSnapshot, date: String, anomalies: Int) -> String {
        var parts: [String] = ["Day \(date):"]
        if let score = s.sleepScore { parts.append("sleep score \(score), slept \(s.sleepDurationDisplay)") }
        if let steps = s.steps { parts.append("\(steps) steps (goal \(s.stepsGoal))") }
        if s.spentToday != nil { parts.append("spent \(s.spentDisplay)") }
        parts.append("\(anomalies) anomaly\(anomalies == 1 ? "" : "ies")")
        return parts.joined(separator: "; ")
    }
}

/// Returns the recent trend for a named metric.
struct GetMetricTrendTool: Tool {
    typealias Output = String

    let name = "getMetricTrend"
    let description = "Get the recent trend (latest value, mean) for a Spark metric by identifier or name."

    @Generable
    struct Arguments {
        @Guide(description: "Metric identifier like 'oura.sleep_score' or a display name like 'steps'.")
        var metric: String
    }

    func call(arguments: Arguments) async throws -> String {
        let query = arguments.metric.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = await MainActor.run {
            IntentService.metricEntities(limit: 500).filter { metric in
                metric.id.lowercased().contains(query)
                    || metric.displayName.lowercased().contains(query)
            }
        }
        guard let metric = matches.first else {
            return "No metric found matching '\(arguments.metric)'."
        }
        var line = metric.displayName
        if let value = metric.latestValueDescription { line += ": latest \(value)" }
        if let last = metric.lastEventAt {
            let f = RelativeDateTimeFormatter()
            line += " (updated \(f.localizedString(for: last, relativeTo: .now)))"
        }
        return line
    }
}

/// Searches recent events for a free-text query.
struct SearchEventsTool: Tool {
    typealias Output = String

    let name = "searchEvents"
    let description = "Search the user's recent Spark events by free text."

    @Generable
    struct Arguments {
        @Guide(description: "What to search for, e.g. 'coffee', 'run', 'github'.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let results = await MainActor.run { IntentService.eventEntities(query: arguments.query, limit: 8) }
        guard !results.isEmpty else {
            return "No events found for '\(arguments.query)'."
        }
        let f = DateFormatter(); f.dateFormat = "MMM d HH:mm"
        let lines = results.map { entity -> String in
            let when = entity.timestamp.map { f.string(from: $0) } ?? "-"
            return "- \(when): \(entity.title)"
        }
        return lines.joined(separator: "\n")
    }
}

/// Searches recent blocks for a free-text query.
struct SearchBlocksTool: Tool {
    typealias Output = String

    let name = "searchBlocks"
    let description = "Search the user's recent Spark text/content blocks by free text."

    @Generable
    struct Arguments {
        @Guide(description: "What to search for in text blocks or notes.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let needle = arguments.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let results = await MainActor.run {
            IntentService.blockEntities(limit: 500).filter { block in
                block.title.lowercased().contains(needle)
                    || (block.body?.lowercased().contains(needle) ?? false)
                    || block.keywords.contains { $0.lowercased().contains(needle) }
            }
        }
        guard !results.isEmpty else {
            return "No blocks found for '\(arguments.query)'."
        }
        return results.prefix(8).map { block in
            "- \(block.title): \(block.body ?? "No body")"
        }.joined(separator: "\n")
    }
}

/// Returns a metric's baseline/normal range where the backend has one.
struct GetMetricBaselineTool: Tool {
    typealias Output = String

    let name = "getMetricBaseline"
    let description = "Get the normal baseline range for a Spark metric by identifier."

    @Generable
    struct Arguments {
        @Guide(description: "Metric identifier like 'oura.sleep_score' or 'monzo.spend_daily'.")
        var metric: String
    }

    func call(arguments: Arguments) async throws -> String {
        let identifier = MetricsEndpoint.canonicalIdentifier(
            arguments.metric.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let service = await IntentService()
        if let detail = try? await service.apiClient.request(MetricsEndpoint.detail(identifier: identifier)),
           let baseline = detail.baseline {
            let unit = detail.unit.map { " \($0)" } ?? ""
            return "\(detail.title) normal range: \(baseline.low)-\(baseline.high)\(unit)."
        }

        let cached = await MainActor.run {
            IntentService.metricEntities(matching: [identifier]).first
        }
        if let cached {
            var line = "\(cached.displayName)"
            if let value = cached.latestValueDescription { line += " latest: \(value)." }
            line += " No baseline range is cached."
            return line
        }
        return "No baseline found for \(identifier)."
    }
}

enum FlintTools {
    /// Tools available to the deep/digest reasoning profile.
    static var digestTools: [any Tool] {
        [
            GetDaySummaryTool(),
            GetMetricTrendTool(),
            SearchEventsTool(),
            SearchBlocksTool(),
            GetMetricBaselineTool(),
        ]
    }
}
