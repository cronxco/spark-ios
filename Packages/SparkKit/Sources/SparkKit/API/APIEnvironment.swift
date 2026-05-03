import Foundation

/// Where the iOS client points its network stack. Switchable at runtime via
/// `UserDefaults` in the App Group; the build ships with `.production` so
/// TestFlight just works.
public struct APIEnvironment: Sendable, Hashable {
    public let baseURL: URL
    public let oauthAuthorizeURL: URL
    public let name: String

    /// Reverb WebSocket config. `reverbHost` is the bare hostname (no scheme).
    /// The client connects to `wss://{reverbHost}/app/{reverbAppKey}?protocol=7`.
    public let reverbHost: String
    public let reverbAppKey: String
    public let reverbPort: Int
    public let reverbUseTLS: Bool

    public init(
        baseURL: URL,
        oauthAuthorizeURL: URL,
        name: String,
        reverbHost: String = "spark.cronx.co",
        reverbAppKey: String = "lw0lmvu5kovdvtfycyub",
        reverbPort: Int = 443,
        reverbUseTLS: Bool = true
    ) {
        self.baseURL = baseURL
        self.oauthAuthorizeURL = oauthAuthorizeURL
        self.name = name
        self.reverbHost = reverbHost
        self.reverbAppKey = reverbAppKey
        self.reverbPort = reverbPort
        self.reverbUseTLS = reverbUseTLS
    }

    /// WebSocket URL for Reverb, e.g. wss://spark.cronx.co/app/key?protocol=7
    public var reverbWebSocketURL: URL {
        let scheme = reverbUseTLS ? "wss" : "ws"
        return URL(string: "\(scheme)://\(reverbHost):\(reverbPort)/app/\(reverbAppKey)?protocol=7&client=spark-ios&version=1.0")!
    }

    /// The base HTTP URL for the Reverb host (used for the auth endpoint).
    public var reverbHTTPBaseURL: URL {
        let scheme = reverbUseTLS ? "https" : "http"
        return URL(string: "\(scheme)://\(reverbHost):\(reverbPort)")!
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
        let reverbHost = userDefaults.string(forKey: "spark.env.reverbHost") ?? "spark.cronx.co"
        let reverbAppKey = userDefaults.string(forKey: "spark.env.reverbAppKey") ?? "lw0lmvu5kovdvtfycyub"
        let reverbPort = userDefaults.integer(forKey: "spark.env.reverbPort")
        let reverbUseTLS = userDefaults.object(forKey: "spark.env.reverbUseTLS") as? Bool ?? true
        return APIEnvironment(
            baseURL: baseURL,
            oauthAuthorizeURL: authURL,
            name: userDefaults.string(forKey: "spark.env.name") ?? "custom",
            reverbHost: reverbHost,
            reverbAppKey: reverbAppKey,
            reverbPort: reverbPort > 0 ? reverbPort : 443,
            reverbUseTLS: reverbUseTLS
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
