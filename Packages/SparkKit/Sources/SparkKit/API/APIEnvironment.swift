import Foundation

/// Where the iOS client points its network stack. Switchable at runtime via
/// `UserDefaults` in the App Group; the build ships with `.production` so
/// TestFlight just works.
public struct APIEnvironment: Sendable, Hashable {
    public let baseURL: URL
    public let oauthAuthorizeURL: URL
    public let name: String

    public init(baseURL: URL, oauthAuthorizeURL: URL, name: String) {
        self.baseURL = baseURL
        self.oauthAuthorizeURL = oauthAuthorizeURL
        self.name = name
    }

    public static let production = APIEnvironment(
        baseURL: URL(string: "https://spark.cronx.co/api/v1/mobile")!,
        oauthAuthorizeURL: URL(string: "https://spark.cronx.co/oauth/authorize")!,
        name: "production"
    )

    public static let staging = APIEnvironment(
        baseURL: URL(string: "https://staging.spark.cronx.co/api/v1/mobile")!,
        oauthAuthorizeURL: URL(string: "https://staging.spark.cronx.co/oauth/authorize")!,
        name: "staging"
    )

    /// Pulled from the App Group UserDefaults so DEBUG builds can point at a
    /// local Sail instance over the LAN.
    public static func current(
        userDefaults: UserDefaults = .sparkAppGroup
    ) -> APIEnvironment {
        guard
            let base = userDefaults.string(forKey: "spark.env.baseURL"),
            let baseURL = URL(string: base),
            let authStr = userDefaults.string(forKey: "spark.env.oauthURL"),
            let authURL = URL(string: authStr)
        else {
            return .production
        }
        return APIEnvironment(
            baseURL: baseURL,
            oauthAuthorizeURL: authURL,
            name: userDefaults.string(forKey: "spark.env.name") ?? "custom"
        )
    }
}

public extension UserDefaults {
    /// The App Group UserDefaults. Writing via this suite lets widgets,
    /// extensions and the main app share preferences and ETags.
    nonisolated(unsafe) static let sparkAppGroup: UserDefaults = {
        UserDefaults(suiteName: "group.co.cronx.spark") ?? .standard
    }()
}
