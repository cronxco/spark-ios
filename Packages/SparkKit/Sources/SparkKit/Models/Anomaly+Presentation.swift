import Foundation

/// How an anomaly reads on screen: its name in sentence case, the hero value
/// split from its unit, and one comparison line in the design language's
/// shape (§3.4): arrow, amount, direction word, baseline window.
public extension Anomaly {
    /// The baseline window the backend uses when it doesn't say.
    static let defaultBaselineWindowDays = 90

    /// "Heart Rate" → "Heart rate" (§4, sentence case everywhere). Words in
    /// capitals ("HRV", "SpO2") keep their case.
    var sentenceCaseName: String {
        let name = (displayName ?? metric ?? "A metric").trimmingCharacters(in: .whitespaces)
        let words = name.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let first = words.first else { return name }
        let rest = words.dropFirst().map { word -> String in
            let letters = word.filter(\.isLetter)
            let isAcronym = letters.count > 1 && letters.dropFirst().contains(where: \.isUppercase)
            return isAcronym ? word : word.lowercased()
        }
        return ([first] + rest).joined(separator: " ")
    }

    /// The hero value and its unit, drawn at two sizes (§4). The server's
    /// own formatting is preferred: "77 bpm" splits into "77" and "bpm";
    /// "£2,082.23" and "Adequate" have no separate unit.
    var heroParts: (value: String, unit: String?) {
        let display = currentDisplay?.sparkPlainTextFromHTMLFragment
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !display.isEmpty {
            if let match = display.wholeMatch(of: #/([^\s]*\d[^\s]*)\s+([^\d\s][^\d]*)/#) {
                return (String(match.1), String(match.2))
            }
            return (display, nil)
        }

        guard let currentValue, currentValue.isFinite else { return ("—", nil) }
        return (Self.amount(currentValue), unit.flatMap(Self.readableUnit))
    }

    enum Movement: Sendable {
        case above, below, level
    }

    /// Which side of the baseline the reading sits on.
    var movement: Movement {
        guard let currentValue, let baselineValue, currentValue.isFinite, baselineValue.isFinite else {
            switch direction?.lowercased() {
            case "up", "high": return .above
            case "down", "low": return .below
            default: return .level
            }
        }
        if currentValue > baselineValue { return .above }
        if currentValue < baselineValue { return .below }
        return .level
    }

    /// "21bpm below 90d trend", "£38 above 90d trend", "2 bands below 90d
    /// trend". The arrow is drawn beside it and coloured by valence.
    var comparisonText: String? {
        guard let currentValue, let baselineValue, currentValue.isFinite, baselineValue.isFinite else {
            return nil
        }
        let window = "\(baselineWindowDays ?? Self.defaultBaselineWindowDays)d trend"
        let difference = abs(currentValue - baselineValue)

        let word: String
        switch movement {
        case .above: word = "above"
        case .below: word = "below"
        case .level: return "In line with \(window)"
        }

        let amount: String
        if isOrdinal {
            let bands = Int(difference.rounded())
            guard bands >= 1 else { return "Just \(word) \(window)" }
            amount = bands == 1 ? "1 band" : "\(bands) bands"
        } else {
            amount = Self.withUnit(Self.amount(difference), unit: unit)
        }
        return "\(amount) \(word) \(window)"
    }

    /// Whole numbers from 10 up, one decimal below.
    private static func amount(_ value: Double) -> String {
        let magnitude = abs(value)
        let digits = magnitude >= 10 || magnitude.rounded() == magnitude ? 0 : 1
        return value.formatted(.number.precision(.fractionLength(digits)))
    }

    /// The unit joined the way §3.4 writes it: unspaced after the number
    /// ("21bpm"), a currency symbol before it ("£38"), nothing for counts.
    private static func withUnit(_ amount: String, unit: String?) -> String {
        guard let unit, !unit.isEmpty else { return amount }
        switch unit.uppercased() {
        case "GBP": return "£\(amount)"
        case "USD": return "$\(amount)"
        case "EUR": return "€\(amount)"
        default: break
        }
        guard let readable = readableUnit(unit) else { return amount }
        return amount + readable
    }

    /// Units a reader recognises. Raw API units ("count/min", "count")
    /// become "bpm" or nothing.
    private static func readableUnit(_ unit: String) -> String? {
        switch unit.lowercased() {
        case "count/min", "bpm": return "bpm"
        case "count", "": return nil
        case "percent", "%": return "%"
        case "seconds", "s": return "s"
        case "minutes", "min": return "m"
        default: return unit
        }
    }
}
