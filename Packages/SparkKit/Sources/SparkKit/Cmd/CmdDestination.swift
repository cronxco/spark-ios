import Foundation

/// A screen a navigation command can open. Raw values are the registry's
/// `destination.native` ids, so the server decides what is offered and the app
/// only maps ids it knows; an unknown id is simply not openable.
public enum CmdDestination: String, Sendable, Equatable, CaseIterable {
    case day
    case flint
    case knowledge
    case exploreHealth = "explore.health"
    case exploreMoney = "explore.money"
    case exploreMetrics = "explore.metrics"
    case exploreTags = "explore.tags"
    case exploreMap = "explore.map"

    public init?(native: String?) {
        guard let native, let destination = CmdDestination(rawValue: native) else { return nil }
        self = destination
    }

    public var isExplore: Bool { rawValue.hasPrefix("explore.") }
}

/// Reads a typed command line the way the CMD tab does before it asks the
/// server: lower-cased, with a leading "open", "show" or "go to" removed so
/// "open money" finds the Money action.
public enum CmdCommandText {
    private static let navigationLeads = ["open ", "show ", "go to ", "goto "]

    public static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    /// The line without a leading navigation verb. Unchanged when it has none.
    public static func withoutNavigationLead(_ normalized: String) -> String {
        for lead in navigationLeads where normalized.hasPrefix(lead) {
            let rest = String(normalized.dropFirst(lead.count))
            return rest.isEmpty ? normalized : rest
        }
        return normalized
    }
}
