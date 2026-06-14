import Foundation

public enum SparkValueFormatting {
    public static func value(
        _ value: Double,
        unit: String?,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        guard let unit else {
            return decimal(value, locale: locale)
        }

        if isCurrencyCode(unit) {
            return currency(value, code: unit, locale: locale)
        }

        switch unit.lowercased() {
        case "score", "bpm", "percent", "steps", "kcal", "ms":
            return integer(value, locale: locale)
        default:
            return decimal(value, locale: locale)
        }
    }

    public static func unitLabel(_ unit: String?) -> String? {
        guard let unit, !isCurrencyCode(unit) else { return nil }

        switch unit.lowercased() {
        case "score", "steps":
            return nil
        case "percent":
            return "percent"
        default:
            return unit
        }
    }

    public static func currency(
        _ value: Double,
        code: String,
        fractionDigits: Int = 2,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = code.uppercased()
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value))
            ?? "\(code.uppercased()) \(value)"
    }

    public static func isCurrencyCode(_ unit: String) -> Bool {
        Locale.commonISOCurrencyCodes.contains(unit.uppercased())
    }

    private static func integer(_ value: Double, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }

    private static func decimal(_ value: Double, locale: Locale) -> String {
        if abs(value) >= 1_000 {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 1
            let scaled = formatter.string(from: NSNumber(value: value / 1_000)) ?? "\(value / 1_000)"
            return "\(scaled)k"
        }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
