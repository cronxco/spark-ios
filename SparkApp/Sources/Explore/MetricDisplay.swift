import Foundation
import SparkKit
import SparkUI

/// How the Metrics list names, formats and judges a metric. Kept out of the
/// view so the rules in `docs/design-language.md` (3.4 comparisons, 4 units,
/// 9 writing data) can be tested without drawing anything.
enum MetricDisplay {
    // MARK: - Names

    /// The backend's display names are action phrases in title case ("Had
    /// Heart Rate Variability", "Apple Stand Hour"). The list wants the thing
    /// measured, in sentence case: "Heart rate variability", "Stand hour".
    static func title(_ displayName: String, service: String) -> String {
        var words = displayName
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        while let first = words.first, words.count > 1, ["Had", "Did", "Has"].contains(first) {
            words.removeFirst()
        }
        if service == "apple_health", words.count > 1, words.first == "Apple" {
            words.removeFirst()
        }
        return words.enumerated().map { index, word in
            if let acronym = acronyms[word.lowercased()] { return acronym }
            if index == 0 { return word.prefix(1).uppercased() + word.dropFirst() }
            // Lower a title-cased word ("Rate"), but leave anything with
            // capitals after the first letter ("SpO2", "HRV") as written.
            let rest = word.dropFirst()
            return rest == rest.lowercased() ? word.lowercased() : word
        }
        .joined(separator: " ")
    }

    private static let acronyms: [String: String] = [
        "vo2": "VO2",
        "spo2": "SpO2",
        "hrv": "HRV",
    ]

    /// One name per integration. `google_calendar` and `google-calendar` are
    /// both live, so they share a name and a section.
    static func serviceName(_ service: String) -> String {
        switch service {
        case "oura": "Oura"
        case "apple_health": "Apple Health"
        case "monzo": "Monzo"
        case "gocardless": "GoCardless"
        case "untappd": "Untappd"
        case "daily_checkin": "Daily check-in"
        case "goodreads": "Goodreads"
        case "google_calendar", "google-calendar": "Google Calendar"
        case "receipt": "Receipts"
        case "hevy": "Hevy"
        case "manual_account": "Manual accounts"
        default:
            service
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .sparkSentenceCased
        }
    }

    // MARK: - Glyphs

    /// The concept's glyph from the manifest, falling back to the domain's.
    static func icon(action: String, unit: String?, domain: String) -> SparkIcon {
        let action = action.lowercased()
        let rules: [(String, SparkIcon)] = [
            ("heart_rate_variability", .hrv),
            ("heart_rate", .heartRate),
            ("temperature", .health),
            ("sleep", .sleep),
            ("slept", .sleep),
            ("score", .score),
            ("step", .steps),
            ("energy", .energy),
            ("workout", .workout),
            ("distance", .distance),
            ("exercise", .duration),
            ("stand", .duration),
            ("daylight", .duration),
            ("card_payment", .paymentCard),
            ("payment", .payment),
            ("direct_debit", .payment),
            ("transfer", .transfer),
            ("balance", .balance),
            ("pot_", .savingsPot),
            ("interest", .income),
            ("salary", .income),
            ("receipt", .invoice),
            ("reading", .book),
            ("event", .calendarEvent),
        ]
        if let match = rules.first(where: { action.contains($0.0) }) { return match.1 }
        return .domain(domain)
    }

    // MARK: - Values

    struct Value: Equatable, Sendable {
        let text: String
        let unit: String?
    }

    /// Ordinal readings arrive as numbers but mean a word. Oura's stress and
    /// resilience levels are the two in Spark today.
    static func band(for value: Double, unit: String?) -> String? {
        let level = Int(value.rounded())
        switch unit {
        case "stress_level":
            return [1: "Restored", 2: "Normal", 3: "Stressful"][level]
        case "resilience_level":
            return [1: "Limited", 2: "Adequate", 3: "Solid", 4: "Strong", 5: "Exceptional"][level]
        default:
            return nil
        }
    }

    static func isScore(action: String, unit: String?) -> Bool {
        unit == "percent" && action.lowercased().contains("score")
    }

    static func format(_ value: Double, unit: String?, action: String = "") -> Value {
        if let band = band(for: value, unit: unit) { return Value(text: band, unit: nil) }
        if isScore(action: action, unit: unit) { return Value(text: integer(value), unit: nil) }

        switch unit {
        case "seconds":
            return Value(text: duration(minutes: value / 60), unit: nil)
        case "min", "minutes":
            return Value(text: duration(minutes: value), unit: nil)
        case "count/min", "bpm":
            return Value(text: integer(value), unit: "bpm")
        case "ms":
            return Value(text: integer(value), unit: "ms")
        case "degC":
            return Value(text: decimal(value, digits: 1), unit: "°C")
        case "percent", "%":
            return Value(text: decimal(value, digits: abs(value) < 10 ? 1 : 0), unit: "%")
        case "GBP", "USD", "EUR":
            return Value(text: currency(value, code: unit ?? "GBP"), unit: nil)
        case "count":
            return Value(text: integer(value), unit: action.lowercased().contains("step") ? "steps" : nil)
        case "kcal":
            return Value(text: integer(value), unit: "kcal")
        case "km":
            return Value(text: decimal(value, digits: 1), unit: "km")
        case "km/hr":
            return Value(text: decimal(value, digits: 1), unit: "km/h")
        case "kg":
            return Value(text: decimal(value, digits: 1), unit: "kg")
        case "m":
            return Value(text: integer(value), unit: "m")
        case "cm":
            return Value(text: integer(value), unit: "cm")
        case "m/s":
            return Value(text: decimal(value, digits: 2), unit: "m/s")
        case "out of 10":
            return Value(text: decimal(value, digits: 1), unit: "/10")
        case "/5":
            return Value(text: decimal(value, digits: 2), unit: "/5")
        case "years":
            return Value(text: integer(value), unit: "years")
        case nil, "":
            return Value(text: decimal(value, digits: 1), unit: nil)
        default:
            return Value(text: decimal(value, digits: 1), unit: unit)
        }
    }

    /// An amount with its unit run on, as comparisons write it (3.4):
    /// "6bpm", "24m", "£33.34", "0.7°C", "4,179 steps".
    static func amount(_ value: Double, unit: String?, action: String = "") -> String {
        let formatted = format(value, unit: unit, action: action)
        guard let unit = formatted.unit else { return formatted.text }
        return wordUnits.contains(unit) ? "\(formatted.text) \(unit)" : formatted.text + unit
    }

    private static let wordUnits: Set<String> = ["steps", "years"]

    static func duration(minutes: Double) -> String {
        let total = Int(minutes.rounded())
        let hours = total / 60
        let mins = total % 60
        if hours == 0 { return "\(mins)m" }
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }

    private static func integer(_ value: Double) -> String {
        decimal(value, digits: 0)
    }

    private static func decimal(_ value: Double, digits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_GB")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func currency(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_GB")
        formatter.currencyCode = code
        let large = abs(value) >= 10_000
        formatter.minimumFractionDigits = large ? 0 : 2
        formatter.maximumFractionDigits = large ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    // MARK: - Comparison

    /// Which way is good (3.4). The backend doesn't publish polarity yet, so
    /// it lives here; a metric not listed reads neutral rather than guessed.
    enum Polarity: Sendable, Equatable {
        case higherIsBetter, lowerIsBetter, neutral

        static func of(action: String) -> Polarity {
            let action = action.lowercased()
            if lowerKeys.contains(where: { action.contains($0) }) { return .lowerIsBetter }
            if higherKeys.contains(where: { action.contains($0) }) { return .higherIsBetter }
            return .neutral
        }

        private static let lowerKeys = [
            "resting_heart_rate", "stress", "cardiovascular_age", "walking_asymmetry",
            "double_support", "audio_exposure", "payment_to", "card_payment",
            "direct_debit", "bank_transfer_to", "receipt",
        ]

        private static let higherKeys = [
            "sleep_score", "readiness", "activity_score", "resilience", "slept_for",
            "step_count", "active_energy", "exercise_time", "stand_hour", "stand_time",
            "heart_rate_variability", "vo2_max", "flights_climbed", "walking_running_distance",
            "time_in_daylight", "checkin", "spo2", "blood_oxygen", "walking_speed",
            "cardio_recovery", "interest_earned",
        ]
    }

    /// The comparison line against the 30-day mean: "↑ 6bpm above 30d trend".
    /// The arrow takes the polarity colour; ordinal readings, which have no
    /// meaningful difference, get none.
    static func comparison(
        value: Double,
        mean: Double?,
        unit: String?,
        action: String,
        window: String = "30d"
    ) -> MetricComparison? {
        guard let mean, band(for: value, unit: unit) == nil else { return nil }
        let difference = value - mean
        let text = amount(abs(difference), unit: unit, action: action)
        let digits = text.filter(\.isNumber)
        if difference == 0 || (!digits.isEmpty && digits.allSatisfy { $0 == "0" }) {
            return MetricComparison(direction: .steady, text: "On \(window) trend", isGood: nil)
        }
        let isUp = difference > 0
        let polarity = Polarity.of(action: action)
        let isGood: Bool? = switch polarity {
        case .neutral: nil
        case .higherIsBetter: isUp
        case .lowerIsBetter: !isUp
        }
        return MetricComparison(
            direction: isUp ? .up : .down,
            text: "\(text) \(isUp ? "above" : "below") \(window) trend",
            isGood: isGood
        )
    }

    // MARK: - Staleness

    /// Whole days between the reading's date and today. The series carries
    /// dates as `yyyy-MM-dd` parsed at UTC midnight, so today is built the
    /// same way from the local calendar day.
    static func daysAgo(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Int {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        guard let todayUTC = utc.date(from: today) else { return 0 }
        return max(0, utc.dateComponents([.day], from: date, to: todayUTC).day ?? 0)
    }

    /// "from yesterday", "from 3 days ago", or nil for today's reading.
    static func staleness(daysAgo: Int) -> String? {
        switch daysAgo {
        case ...0: nil
        case 1: "from yesterday"
        default: "from \(daysAgo) days ago"
        }
    }

    /// The eyebrow's trailing time on a compact card.
    static func dayLabel(daysAgo: Int) -> String {
        switch daysAgo {
        case ...0: "Today"
        case 1: "Yesterday"
        default: "\(daysAgo) days ago"
        }
    }
}

private extension String {
    var sparkSentenceCased: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
