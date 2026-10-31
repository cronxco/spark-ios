import SwiftUI

/// The per-type role colours of tags and references
/// (`docs/design-language.md` section 7.5), named as on the web so a tag is
/// the same colour on both platforms. Only pills and their peek cards use
/// these; cards, glyph chips and heroes keep domain tints.
public enum SparkRole: String, CaseIterable, Sendable {
    case primary, secondary, accent, info, success, warning, error

    /// The fill and border, in both modes.
    public var fill: Color {
        switch self {
        case .primary: .adaptive(light: .spark5, dark: .spark3)
        case .secondary: .adaptive(light: .ember5, dark: .flame3)
        case .accent: .adaptive(light: .ocean5, dark: .sky3)
        case .info: .adaptive(light: Color(red: 0.392, green: 0.620, blue: 0.753), dark: Color(red: 0.655, green: 0.780, blue: 0.859))
        case .success: .adaptive(light: .sparkSuccess, dark: Color(red: 0.702, green: 0.847, blue: 0.788))
        case .warning: .adaptive(light: .sparkWarning, dark: Color(red: 0.824, green: 0.671, blue: 0.733))
        case .error: .sparkError
        }
    }

    /// Text and glyph. In light mode the fill fails 4.5:1 for six of the seven
    /// roles, so text takes the ink step of the same hue; in dark mode the
    /// fill already clears 5:1 and is used as is.
    public var ink: Color {
        switch self {
        case .primary: .adaptive(light: .spark8, dark: .spark3)
        case .secondary: .adaptive(light: .ember8, dark: .flame3)
        case .accent: .adaptive(light: .ocean5, dark: .sky3)
        case .info: .adaptive(light: .sky7, dark: fill)
        case .success: .adaptive(light: Color(red: 0.000, green: 0.172, blue: 0.131), dark: fill)
        case .warning: .adaptive(light: Color(red: 0.047, green: 0.016, blue: 0.027), dark: fill)
        case .error: .adaptive(light: .flame7, dark: .sparkError)
        }
    }

    /// A tag's role from its type, as `<x-tag-ref>` maps it on the web.
    public static func forTagType(_ type: String?) -> SparkRole {
        let type = (type ?? "").lowercased()
        switch type {
        case "transaction_category", "transaction_type", "transaction_status", "transaction_scheme",
             "transaction_currency", "balance_type", "card_pan", "emoji":
            return .warning
        case "decline_reason":
            return .error
        case "merchant_country", "merchant_category":
            return .info
        case "spark":
            return .primary
        default:
            break
        }
        if type.contains("artist") || type.contains("person") { return .secondary }
        if type.contains("album") { return .accent }
        if type.contains("spotify") || type.contains("context") { return .success }
        return .info
    }

    /// An object reference's role from its concept (section 7.5).
    public static func forObjectType(_ type: String?) -> SparkRole {
        let type = (type ?? "").lowercased()
        if type.contains("person") || type.contains("user") || type.contains("contact") { return .secondary }
        if type.contains("account") || type.contains("money") || type.contains("merchant") { return .warning }
        if type.contains("track") || type.contains("album") || type.contains("media")
            || type.contains("song") || type.contains("episode") { return .info }
        if type.contains("bookmark") || type.contains("document") || type.contains("article")
            || type.contains("book") { return .primary }
        if type.contains("day") { return .accent }
        return .secondary
    }
}
