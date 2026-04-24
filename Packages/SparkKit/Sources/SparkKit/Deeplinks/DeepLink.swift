import Foundation

/// Routable links the Phase 1 app understands.
public enum DeepLink: Sendable, Equatable {
    /// OAuth callback from `ASWebAuthenticationSession`.
    case authCallback(code: String, state: String)
    /// Today view — optional date for deep-linking to a specific day.
    case today(date: Date?)
    /// Day pager for an arbitrary date (`/day/YYYY-MM-DD`).
    case day(Date)
    /// Event detail — resolved by id; Phase 2 fills in the detail view.
    case event(id: String)

    /// Parse an incoming URL against the Phase 1 routing table. Returns nil
    /// when the URL doesn't match anything we handle on device yet.
    public static func parse(
        _ url: URL,
        host: String = "spark.cronx.co",
        callbackScheme: String = "spark"
    ) -> DeepLink? {
        if url.scheme == callbackScheme {
            return parseCallback(url)
        }

        guard url.host == host else { return nil }

        let path = url.path
        let components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)

        switch components.first {
        case "today":
            return .today(date: components.dropFirst().first.flatMap(Self.date(from:)))
        case "day":
            guard components.count >= 2, let date = Self.date(from: components[1]) else { return nil }
            return .day(date)
        case "event":
            guard components.count >= 2 else { return nil }
            return .event(id: components[1])
        default:
            return nil
        }
    }

    private static func parseCallback(_ url: URL) -> DeepLink? {
        guard url.host == "auth" else { return nil }
        guard url.pathComponents.contains("callback") else { return nil }
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
            let state = components.queryItems?.first(where: { $0.name == "state" })?.value
        else {
            return nil
        }
        return .authCallback(code: code, state: state)
    }

    private static func date(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: string)
    }
}
