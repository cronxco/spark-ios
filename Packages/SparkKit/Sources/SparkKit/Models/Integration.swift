import Foundation

/// Mirrors `CompactIntegrationResource` on the backend.
public struct Integration: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let service: String
    public let name: String
    public let instanceType: String?
    public let status: String?
    /// The plugin's domain (`health`, `money`, `media`, `knowledge`, `online`).
    public let domain: String?
    public let paused: Bool?
    public let lastSyncAt: Date?
    public let nextUpdateAt: Date?
    public let scheduleSummary: String?

    public var statusValue: String {
        guard let status, !status.isEmpty else { return "unknown" }
        return status
    }

    /// The backend status mapped onto the shared vocabulary. `error` carries
    /// the raw value for anything the app doesn't recognise.
    public var statusKind: IntegrationStatus {
        IntegrationStatus(rawStatus: statusValue)
    }

    enum CodingKeys: String, CodingKey {
        case id, service, name, status, domain, paused
        case instanceType = "instance_type"
        case lastSyncAt = "last_sync_at"
        case nextUpdateAt = "next_update_at"
        case scheduleSummary = "schedule_summary"
    }

    public init(
        id: String,
        service: String,
        name: String,
        instanceType: String? = nil,
        status: String? = nil,
        domain: String? = nil,
        paused: Bool? = nil,
        lastSyncAt: Date? = nil,
        nextUpdateAt: Date? = nil,
        scheduleSummary: String? = nil
    ) {
        self.id = id
        self.service = service
        self.name = name
        self.instanceType = instanceType
        self.status = status
        self.domain = domain
        self.paused = paused
        self.lastSyncAt = lastSyncAt
        self.nextUpdateAt = nextUpdateAt
        self.scheduleSummary = scheduleSummary
    }
}
