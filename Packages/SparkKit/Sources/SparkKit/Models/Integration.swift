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
    /// The latest update run. Absent from older backends and before an
    /// integration's first run.
    public let lastRun: IntegrationRun?

    public var statusValue: String {
        guard let status, !status.isEmpty else { return "unknown" }
        return status
    }

    /// The backend status mapped onto the shared vocabulary. `error` carries
    /// the raw value for anything the app doesn't recognise. A finished run
    /// that did not process everything is not reported as up to date.
    public var statusKind: IntegrationStatus {
        let status = IntegrationStatus(rawStatus: statusValue)
        switch status {
        case .upToDate, .needsUpdate, .stale, .unknown:
            return lastRun?.failureStatus ?? status
        case .syncing, .needsReauth, .paused, .error:
            return status
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, service, name, status, domain, paused
        case instanceType = "instance_type"
        case lastSyncAt = "last_sync_at"
        case nextUpdateAt = "next_update_at"
        case scheduleSummary = "schedule_summary"
        case lastRun = "last_run"
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
        scheduleSummary: String? = nil,
        lastRun: IntegrationRun? = nil
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
        self.lastRun = lastRun
    }
}

/// Mirrors `last_run` on `CompactIntegrationResource`: the latest update run,
/// covering the provider fetch and the processing of what it fetched.
public struct IntegrationRun: Codable, Sendable, Hashable {
    public enum Status: Sendable, Hashable {
        case requested
        case fetching
        case processing
        case upToDate
        case partial
        case failed
        case other(String)

        public init(rawValue: String) {
            switch rawValue.lowercased() {
            case "requested": self = .requested
            case "fetching": self = .fetching
            case "processing": self = .processing
            case "up_to_date": self = .upToDate
            case "partial": self = .partial
            case "failed": self = .failed
            default: self = .other(rawValue)
            }
        }
    }

    public let status: String
    public let requestedAt: Date?
    public let startedAt: Date?
    public let finishedAt: Date?
    public let processedJobs: Int?
    public let failedJobs: Int?
    public let error: String?

    public var statusKind: Status { Status(rawValue: status) }

    /// Whether the run is still fetching or processing.
    public var isInFlight: Bool {
        switch statusKind {
        case .requested, .fetching, .processing: true
        case .upToDate, .partial, .failed, .other: false
        }
    }

    /// The integration status a finished run that went wrong overrides, or
    /// nil when the run gives no reason to doubt the backend's status.
    var failureStatus: IntegrationStatus? {
        switch statusKind {
        case .partial: .error("Partly updated")
        case .failed: .error("Last update failed")
        case .requested, .fetching, .processing, .upToDate, .other: nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case status, error
        case requestedAt = "requested_at"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case processedJobs = "processed_jobs"
        case failedJobs = "failed_jobs"
    }

    /// Only `status` is required; a malformed optional field is dropped
    /// rather than failing the whole integration.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        requestedAt = try? container.decodeIfPresent(Date.self, forKey: .requestedAt)
        startedAt = try? container.decodeIfPresent(Date.self, forKey: .startedAt)
        finishedAt = try? container.decodeIfPresent(Date.self, forKey: .finishedAt)
        processedJobs = try? container.decodeIfPresent(Int.self, forKey: .processedJobs)
        failedJobs = try? container.decodeIfPresent(Int.self, forKey: .failedJobs)
        error = try? container.decodeIfPresent(String.self, forKey: .error)
    }

    public init(
        status: String,
        requestedAt: Date? = nil,
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        processedJobs: Int? = nil,
        failedJobs: Int? = nil,
        error: String? = nil
    ) {
        self.status = status
        self.requestedAt = requestedAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.processedJobs = processedJobs
        self.failedJobs = failedJobs
        self.error = error
    }
}
