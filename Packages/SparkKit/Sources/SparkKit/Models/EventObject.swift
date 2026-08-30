import Foundation

/// Mirrors `CompactObjectResource` on the backend.
public struct EventObject: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let concept: String
    public let type: String
    public let title: String
    public let time: Date?
    public let content: String?
    public let url: String?
    public let mediaUrl: String?
    public let location: EventDetail.Location?

    enum CodingKeys: String, CodingKey {
        case id, concept, type, title, time, content, url
        case mediaUrl = "media_url"
        case location
    }

    public init(
        id: String,
        concept: String,
        type: String,
        title: String,
        time: Date? = nil,
        content: String? = nil,
        url: String? = nil,
        mediaUrl: String? = nil,
        location: EventDetail.Location? = nil
    ) {
        self.id = id
        self.concept = concept
        self.type = type
        self.title = title
        self.time = time
        self.content = content
        self.url = url
        self.mediaUrl = mediaUrl
        self.location = location
    }
}
