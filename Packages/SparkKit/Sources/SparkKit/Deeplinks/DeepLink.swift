import Foundation

/// Routable links the app understands. Mirrors the AASA paths declared in
/// `public/.well-known/apple-app-site-association` on the backend.
public enum DeepLink: Sendable, Equatable {
    /// OAuth callback from `ASWebAuthenticationSession`.
    case authCallback(code: String, state: String)
    /// Today view — optional date for deep-linking to a specific day.
    case today(date: Date?)
    /// Day pager for an arbitrary date (`/day/YYYY-MM-DD`).
    case day(Date)

    case event(id: String)
    case object(id: String)
    case block(id: String)
    case metric(identifier: String)
    case place(id: String)
    case integration(service: String)

    /// Parse an incoming URL. Returns nil when the URL doesn't match any
    /// route — caller can fall through to default handling (e.g. opening
    /// the URL in Safari).
    public static func parse(
        _ url: URL,
        host: String = "spark.cronx.co",
        callbackScheme: String = "spark"
    ) -> DeepLink? {
        if url.scheme == callbackScheme {
            return parseCallback(url)
        }

        guard url.host == host else { return nil }

        let parts = url.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        switch parts.first {
        case "today":
            return .today(date: parts.dropFirst().first.flatMap(Self.date(from:)))
        case "day":
            guard parts.count >= 2, let date = Self.date(from: parts[1]) else { return nil }
            return .day(date)
        case "events", "event":
            guard parts.count >= 2 else { return nil }
            return .event(id: parts[1])
        case "objects", "object":
            guard parts.count >= 2 else { return nil }
            return .object(id: parts[1])
        case "blocks", "block":
            guard parts.count >= 2 else { return nil }
            return .block(id: parts[1])
        case "metrics", "metric":
            guard parts.count >= 2 else { return nil }
            return .metric(identifier: parts[1])
        case "places", "place":
            guard parts.count >= 2 else { return nil }
            return .place(id: parts[1])
        case "integrations":
            // /integrations/{service}/details
            guard parts.count >= 3, parts[2] == "details" else { return nil }
            return .integration(service: parts[1])
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
