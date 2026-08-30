import Foundation

/// DEBUG-only callers use these strongly-routed endpoints; payloads whose
/// backend shape is intentionally open-ended remain `AnyCodable`.
public enum PowerToolsEndpoint {
    public static func eventFilter(service: String, action: String? = nil, from: String? = nil, to: String? = nil, limit: Int = 50) -> Endpoint<AnyCodable> {
        Endpoint(method: .get, path: "/events/filter", query: [
            URLQueryItem(name: "service", value: service), URLQueryItem(name: "action", value: action), URLQueryItem(name: "from_date", value: from), URLQueryItem(name: "to_date", value: to), URLQueryItem(name: "limit", value: String(limit)),
        ].compactMap { $0.value == nil ? nil : $0 })
    }
    public static func dayContext(date: String) -> Endpoint<AnyCodable> { Endpoint(method: .get, path: "/context/day", query: [URLQueryItem(name: "date", value: date)]) }
    public static func serviceStatus(date: String) -> Endpoint<AnyCodable> { Endpoint(method: .get, path: "/context/service-status", query: [URLQueryItem(name: "date", value: date)]) }
    public static func typedSearch(kind: SparkEntityKind, query: String, semantic: Bool = true, limit: Int = 20) -> Endpoint<AnyCodable> {
        Endpoint(method: .get, path: "/search/\(kind.rawValue)", query: [URLQueryItem(name: "query", value: query), URLQueryItem(name: "semantic", value: String(semantic)), URLQueryItem(name: "limit", value: String(limit))])
    }
}
