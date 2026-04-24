import Foundation
import SwiftData

@Model
public final class CachedAnomaly {
    #Unique<CachedAnomaly>([\.id])

    @Attribute(.unique) public var id: String
    public var metric: String?
    public var severity: String?
    public var desc: String?
    public var detectedAt: Date?
    public var acknowledgedAt: Date?
    public var lastSyncedAt: Date

    public init(
        id: String,
        metric: String? = nil,
        severity: String? = nil,
        desc: String? = nil,
        detectedAt: Date? = nil,
        acknowledgedAt: Date? = nil,
        lastSyncedAt: Date = .init()
    ) {
        self.id = id
        self.metric = metric
        self.severity = severity
        self.desc = desc
        self.detectedAt = detectedAt
        self.acknowledgedAt = acknowledgedAt
        self.lastSyncedAt = lastSyncedAt
    }
}
