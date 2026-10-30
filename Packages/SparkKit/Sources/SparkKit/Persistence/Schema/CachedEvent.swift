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
    public var displayWithObject: Bool = false
    public var displayValue: String?
    public var tagNames: String?
    public var blocksCount: Int?
    public var actorTitle: String?
    public var actorType: String?
    public var actorMediaUrl: String?
    public var targetTitle: String?
    public var targetType: String?
    public var targetMediaUrl: String?
    /// The server's run key; see `Event.groupKey`. `nil` on rows cached
    /// before the field existed.
    public var groupKey: String?
    /// `MoneyDirection` raw value, money events only.
    public var direction: String?
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
        displayWithObject: Bool = false,
        displayValue: String? = nil,
        tagNames: String? = nil,
        blocksCount: Int? = nil,
        actorTitle: String? = nil,
        actorType: String? = nil,
        actorMediaUrl: String? = nil,
        targetTitle: String? = nil,
        targetType: String? = nil,
        targetMediaUrl: String? = nil,
        groupKey: String? = nil,
        direction: String? = nil,
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
        self.displayWithObject = displayWithObject
        self.displayValue = displayValue
        self.tagNames = tagNames
        self.blocksCount = blocksCount
        self.actorTitle = actorTitle
        self.actorType = actorType
        self.actorMediaUrl = actorMediaUrl
        self.targetTitle = targetTitle
        self.targetType = targetType
        self.targetMediaUrl = targetMediaUrl
        self.groupKey = groupKey
        self.direction = direction
        self.lastSyncedAt = lastSyncedAt
    }
}

public extension CachedEvent {
    /// The event's tags. Each is stored as its name and type split by U+1E,
    /// and tags are split by U+1F, so the store needs no schema change.
    /// Rows written before types were kept decode with no type.
    var decodedTags: [EventTag] {
        guard let tagNames else { return [] }
        return tagNames
            .split(separator: "\u{1F}")
            .compactMap { entry in
                let parts = entry.split(separator: "\u{1E}", maxSplits: 1, omittingEmptySubsequences: false)
                guard let name = parts.first.map(String.init), !name.isEmpty else { return nil }
                let type = parts.count > 1 ? String(parts[1]) : ""
                return EventTag(name: name, type: type.isEmpty ? nil : type)
            }
    }

    var decodedTagNames: [String] {
        decodedTags.map(\.name)
    }

    static func encodeTagNames(_ tags: [EventTag]) -> String? {
        let entries = tags
            .filter { !$0.name.isEmpty }
            .map { tag in
                guard let type = tag.type, !type.isEmpty else { return tag.name }
                return "\(tag.name)\u{1E}\(type)"
            }
        return entries.isEmpty ? nil : entries.joined(separator: "\u{1F}")
    }
}
