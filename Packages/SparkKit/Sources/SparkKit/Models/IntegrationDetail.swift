import Foundation

public enum IntegrationStatus: Sendable, Hashable {
    case upToDate
    case syncing
    case needsUpdate
    case needsReauth
    case paused
    /// A push or manual source that has gone quiet. Nothing to trigger, so it
    /// is informational rather than an error.
    case stale
    case unknown
    case error(String)

    /// Maps the backend's `Integration::statusKey()` values, plus the older
    /// spellings earlier builds of the API sent.
    public init(rawStatus: String) {
        switch rawStatus.lowercased() {
        case "up_to_date", "ok", "active": self = .upToDate
        case "processing", "syncing", "running": self = .syncing
        case "needs_update": self = .needsUpdate
        case "needs_reauth", "reauth", "expired": self = .needsReauth
        case "paused": self = .paused
        case "stale": self = .stale
        case "unknown": self = .unknown
        default: self = .error(rawStatus)
        }
    }

    public var label: String {
        switch self {
        case .upToDate: "Up to date"
        case .syncing: "Updating"
        case .needsUpdate: "Needs update"
        case .needsReauth: "Reauth required"
        case .paused: "Paused"
        case .stale: "Quiet"
        case .unknown: "Unknown"
        case .error(let msg): msg
        }
    }

    /// Whether someone should act on this status.
    public var needsAttention: Bool {
        switch self {
        case .needsUpdate, .needsReauth, .error: true
        case .upToDate, .syncing, .paused, .stale, .unknown: false
        }
    }
}

/// Richer integration payload returned by `/api/v1/mobile/integrations/{id}`.
/// Wraps the compact `Integration` and adds sync state, coverage, recent
/// events, and an optional reauth start URL the client opens in
/// `ASWebAuthenticationSession`.
public struct IntegrationDetail: Codable, Sendable, Hashable, Identifiable {
    public let integration: Integration
    public let lastSyncAt: Date?
    public let coveragePercent: Double?
    public let recentEvents: [Event]
    public let oauthStartURL: URL?
    public let domain: String?
    public let statusMessage: String?
    public let supportsReauth: Bool?

    public var id: String { integration.id }

    public var status: IntegrationStatus {
        switch integration.statusKind {
        case .error: .error(statusMessage ?? integration.statusValue)
        case let known: known
        }
    }

    /// Older backends signalled reauth support only by sending a URL.
    public var canReauthorise: Bool {
        supportsReauth ?? (oauthStartURL != nil)
    }

    enum CodingKeys: String, CodingKey {
        case integration, domain
        case lastSyncAt = "last_sync_at"
        case coveragePercent = "coverage_percent"
        case recentEvents = "recent_events"
        case oauthStartURL = "oauth_start_url"
        case statusMessage = "status_message"
        case supportsReauth = "supports_reauth"
    }

    public init(
        integration: Integration,
        lastSyncAt: Date? = nil,
        coveragePercent: Double? = nil,
        recentEvents: [Event] = [],
        oauthStartURL: URL? = nil,
        domain: String? = nil,
        statusMessage: String? = nil,
        supportsReauth: Bool? = nil
    ) {
        self.integration = integration
        self.lastSyncAt = lastSyncAt
        self.coveragePercent = coveragePercent
        self.recentEvents = recentEvents
        self.oauthStartURL = oauthStartURL
        self.domain = domain
        self.statusMessage = statusMessage
        self.supportsReauth = supportsReauth
    }
}
