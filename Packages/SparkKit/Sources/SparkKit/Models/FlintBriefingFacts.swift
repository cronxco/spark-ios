import Foundation

public struct FlintBriefingFacts: Sendable, Hashable {
    public enum SummaryLineContext: Sendable, Hashable {
        case daySoFar
        case dayInReview
    }

    public let date: String
    public let timezone: String
    public let lines: [String]
    public let staleSources: [String]
    public let anomalies: [String]

    public init(summary: DaySummary) {
        date = summary.date
        timezone = summary.timezone
        staleSources = summary.syncStatus.stale ?? []
        anomalies = summary.anomalies.prefix(5).map(Self.describe(anomaly:))

        var facts: [String] = [
            "Date: \(summary.date)",
            "Timezone: \(summary.timezone)",
        ]

        if let upToDate = summary.syncStatus.upToDate {
            facts.append("Sync status: \(upToDate ? "up to date" : "not fully up to date")")
        }
        if let lastEventAt = summary.syncStatus.lastEventAt {
            facts.append("Last synced event: \(ISO8601DateFormatter().string(from: lastEventAt))")
        }
        if !staleSources.isEmpty {
            facts.append("Stale sources: \(staleSources.joined(separator: ", "))")
        }

        facts.append(contentsOf: Self.describeSection("Health", summary.sections.health))
        facts.append(contentsOf: Self.describeSection("Activity", summary.sections.activity))
        facts.append(contentsOf: Self.describeSection("Money", summary.sections.money))
        facts.append(contentsOf: Self.describeSection("Media", summary.sections.media))
        facts.append(contentsOf: Self.describeSection("Knowledge", summary.sections.knowledge))

        if anomalies.isEmpty {
            facts.append("Anomalies: none reported")
        } else {
            facts.append("Anomalies: \(anomalies.joined(separator: "; "))")
        }

        lines = facts
    }

    public var promptText: String {
        lines.joined(separator: "\n")
    }

    public var fallbackNote: FlintDailyNote {
        let highlights = Array(lines.filter { line in
            !line.hasPrefix("Date:")
                && !line.hasPrefix("Timezone:")
                && !line.hasPrefix("Sync status:")
                && !line.hasPrefix("Last synced event:")
                && !line.hasPrefix("Stale sources:")
                && !line.hasPrefix("Anomalies:")
        }.prefix(4))

        let watchouts: [String]
        if !anomalies.isEmpty {
            watchouts = anomalies
        } else if !staleSources.isEmpty {
            watchouts = ["Some sources are stale: \(staleSources.joined(separator: ", "))."]
        } else {
            watchouts = []
        }

        return FlintDailyNote(
            title: "Your day so far",
            summary: highlights.first ?? "Flint has your briefing data, but there is not enough signal yet for a richer note.",
            highlights: highlights,
            watchouts: watchouts,
            suggestedActions: watchouts.isEmpty ? ["Check back after your next sync."] : ["Review the watchouts before planning the rest of your day."]
        )
    }

    public func fallbackSummaryLine(context: SummaryLineContext) -> String? {
        let signal = lines.first { line in
            !line.hasPrefix("Date:")
                && !line.hasPrefix("Timezone:")
                && !line.hasPrefix("Sync status:")
                && !line.hasPrefix("Last synced event:")
                && !line.hasPrefix("Stale sources:")
                && !line.hasPrefix("Anomalies:")
                && !line.hasSuffix(": no data")
        }

        if let anomaly = anomalies.first {
            return switch context {
            case .daySoFar:
                "\(anomaly) is the main signal to keep an eye on so far."
            case .dayInReview:
                "\(anomaly) stood out in the day's signals."
            }
        }

        guard let signal else { return nil }
        let cleanedSignal = cleanedSignalLine(signal)
        return switch context {
        case .daySoFar:
            "\(cleanedSignal) is shaping the day so far."
        case .dayInReview:
            "\(cleanedSignal) shaped the day in review."
        }
    }

    private static func describeSection(_ title: String, _ section: AnyCodable?) -> [String] {
        guard let object = section?.objectValue, !object.isEmpty else {
            return ["\(title): no data"]
        }

        let facts = object
            .sorted { $0.key < $1.key }
            .compactMap { key, value -> String? in
                guard let text = conciseDescription(for: value), !text.isEmpty else { return nil }
                return "\(humanize(key)): \(text)"
            }
            .prefix(6)

        let joined = facts.joined(separator: "; ")
        return joined.isEmpty ? ["\(title): data present"] : ["\(title): \(joined)"]
    }

    private static func conciseDescription(for value: AnyCodable) -> String? {
        switch value.value {
        case .null:
            return nil
        case let .bool(value):
            return value ? "yes" : "no"
        case let .int(value):
            return NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
        case let .double(value):
            return NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
        case let .string(value):
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let .array(values):
            let items = values.compactMap(conciseDescription(for:)).prefix(3)
            return items.isEmpty ? "\(values.count) items" : items.joined(separator: ", ")
        case let .object(object):
            if let display = firstString(in: object, keys: ["display", "display_name", "displayName", "title", "name", "summary", "label"]) {
                return display
            }
            let parts = object
                .sorted { $0.key < $1.key }
                .compactMap { key, value -> String? in
                    guard let text = conciseDescription(for: value), !text.isEmpty else { return nil }
                    return "\(humanize(key)) \(text)"
                }
                .prefix(3)
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        }
    }

    private static func firstString(in object: [String: AnyCodable], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func describe(anomaly: Anomaly) -> String {
        var parts: [String] = []
        parts.append(anomaly.displayName ?? anomaly.metric ?? "Anomaly")
        if let direction = anomaly.direction {
            parts.append(direction)
        }
        if let streakDays = anomaly.streakDays {
            parts.append("\(streakDays)-day streak")
        }
        return parts.joined(separator: " ")
    }

    private static func humanize(_ key: String) -> String {
        key
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }

    private func cleanedSignalLine(_ line: String) -> String {
        let prefixes = ["Health: ", "Activity: ", "Money: ", "Media: ", "Knowledge: "]
        var cleaned = line
        for prefix in prefixes where cleaned.hasPrefix(prefix) {
            cleaned.removeFirst(prefix.count)
            break
        }
        if let semicolon = cleaned.firstIndex(of: ";") {
            cleaned = String(cleaned[..<semicolon])
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
