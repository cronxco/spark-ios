import Foundation

public enum IntegrationStatus: Sendable, Hashable {
    case upToDate
    case syncing
    case needsReauth
    case error(String)

    public var label: String {
        switch self {
        case .upToDate: "Up to date"
        case .syncing: "Syncing"
        case .needsReauth: "Reauth required"
        case .error(let msg): msg
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

    public var id: String { integration.id }

    public var status: IntegrationStatus {
        switch integration.status.lowercased() {
        case "up_to_date", "ok", "active": .upToDate
        case "syncing", "running": .syncing
        case "needs_reauth", "reauth", "expired": .needsReauth
        default: .error(statusMessage ?? integration.status)
        }
    }

    enum CodingKeys: String, CodingKey {
        case integration, domain
        case lastSyncAt = "last_sync_at"
        case coveragePercent = "coverage_percent"
        case recentEvents = "recent_events"
        case oauthStartURL = "oauth_start_url"
        case statusMessage = "status_message"
    }

    public init(
        integration: Integration,
        lastSyncAt: Date? = nil,
        coveragePercent: Double? = nil,
        recentEvents: [Event] = [],
        oauthStartURL: URL? = nil,
        domain: String? = nil,
        statusMessage: String? = nil
    ) {
        self.integration = integration
        self.lastSyncAt = lastSyncAt
        self.coveragePercent = coveragePercent
        self.recentEvents = recentEvents
        self.oauthStartURL = oauthStartURL
        self.domain = domain
        self.statusMessage = statusMessage
    }
}
