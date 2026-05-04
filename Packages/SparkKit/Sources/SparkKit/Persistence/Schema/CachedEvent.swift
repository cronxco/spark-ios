import Foundation
import SwiftData

@Model
public final class CachedEvent {
    #Unique<CachedEvent>([\.id])

    @Attribute(.unique) public var id: String
    public var time: Date?
    public var service: String
    public var domain: String
    public var action: String
    public var value: String?
    public var unit: String?
    public var url: String?
    public var displayName: String?
    public var hidden: Bool = false
    public var displayValue: String?
    public var tagNames: String?
    public var blocksCount: Int?
    public var actorTitle: String?
    public var actorType: String?
    public var actorMediaUrl: String?
    public var targetTitle: String?
    public var targetType: String?
    public var targetMediaUrl: String?
    public var lastSyncedAt: Date

    public init(
        id: String,
        time: Date?,
        service: String,
        domain: String,
        action: String,
        value: String? = nil,
        unit: String? = nil,
        url: String? = nil,
        displayName: String? = nil,
        hidden: Bool = false,
        displayValue: String? = nil,
        tagNames: String? = nil,
        blocksCount: Int? = nil,
        actorTitle: String? = nil,
        actorType: String? = nil,
        actorMediaUrl: String? = nil,
        targetTitle: String? = nil,
        targetType: String? = nil,
        targetMediaUrl: String? = nil,
        lastSyncedAt: Date = .init()
    ) {
        self.id = id
        self.time = time
        self.service = service
        self.domain = domain
        self.action = action
        self.value = value
        self.unit = unit
        self.url = url
        self.displayName = displayName
        self.hidden = hidden
        self.displayValue = displayValue
        self.tagNames = tagNames
        self.blocksCount = blocksCount
        self.actorTitle = actorTitle
        self.actorType = actorType
        self.actorMediaUrl = actorMediaUrl
        self.targetTitle = targetTitle
        self.targetType = targetType
        self.targetMediaUrl = targetMediaUrl
        self.lastSyncedAt = lastSyncedAt
    }
}

public extension CachedEvent {
    var decodedTagNames: [String] {
        guard let tagNames else { return [] }
        return tagNames
            .split(separator: "\u{1F}")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    static func encodeTagNames(_ tags: [EventTag]) -> String? {
        let names = tags.map(\.name).filter { !$0.isEmpty }
        return names.isEmpty ? nil : names.joined(separator: "\u{1F}")
    }
}
