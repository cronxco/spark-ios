import Foundation

/// A block's value as a card shows it (`docs/design-language.md` §9): the
/// hero text, the unit beside it, and the maximum when the value is a ratio
/// that earns a ring.
public struct BlockValue: Hashable, Sendable {
    /// The hero text: `88`, `7h 55m`, `1,250`.
    public let text: String
    /// Shown smaller beside the hero. `nil` when the hero already carries it,
    /// as durations do.
    public let unit: String?
    /// The numeric value, when there is one.
    public let number: Double?
    /// The ratio's maximum, for values that read as "out of" something:
    /// percentages and the 1–5 energy scores. Never set without a maximum.
    public let maximum: Double?

    public init(text: String, unit: String?, number: Double?, maximum: Double?) {
        self.text = text
        self.unit = unit
        self.number = number
        self.maximum = maximum
    }

    /// The share of `maximum` reached, clamped to 0...1.
    public var fraction: Double? {
        guard let number, let maximum, maximum > 0 else { return nil }
        return min(max(number / maximum, 0), 1)
    }

    /// `7h 55m`, `42m`, `1m 05s`, `45s`.
    public static func duration(seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        if minutes >= 10 || (minutes > 0 && secs == 0) {
            return "\(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m " + String(format: "%02ds", secs)
        }
        return "\(secs)s"
    }

    private static let secondUnits: Set<String> = ["s", "sec", "secs", "second", "seconds"]
    private static let minuteUnits: Set<String> = ["min", "mins", "minute", "minutes"]
    private static let percentUnits: Set<String> = ["%", "percent", "pct"]

    static func make(value: String?, unit: String?, kind: BlockKind) -> BlockValue? {
        guard let raw = value?.sparkPlainTextFromHTMLFragment
            .trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty
        else { return nil }

        let unit = unit?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalisedUnit = unit?.lowercased() ?? ""
        let number = Double(raw.replacingOccurrences(of: ",", with: ""))

        if let number {
            if secondUnits.contains(normalisedUnit) {
                return BlockValue(text: duration(seconds: number), unit: nil, number: number, maximum: nil)
            }
            if minuteUnits.contains(normalisedUnit) {
                return BlockValue(text: duration(seconds: number * 60), unit: nil, number: number, maximum: nil)
            }
            if percentUnits.contains(normalisedUnit) {
                return BlockValue(text: grouped(number), unit: "%", number: number, maximum: 100)
            }
            if kind == .mentalEnergy || kind == .physicalEnergy {
                return BlockValue(text: grouped(number), unit: nonEmpty(unit), number: number, maximum: 5)
            }
            return BlockValue(text: grouped(number), unit: nonEmpty(unit), number: number, maximum: nil)
        }

        return BlockValue(text: raw, unit: nonEmpty(unit), number: nil, maximum: nil)
    }

    private static func grouped(_ number: Double) -> String {
        number.formatted(.number.precision(.fractionLength(0...2)).grouping(.automatic))
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
}

public extension Block {
    /// The value formatted for a card, or `nil` when the block has none.
    var displayValue: BlockValue? {
        BlockValue.make(value: value, unit: unit, kind: kind)
    }
}
