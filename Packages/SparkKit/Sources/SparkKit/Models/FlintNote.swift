import Foundation

public struct FlintNote: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let body: String
    public let authoredAt: Date?
    public let createdAt: Date?
    public let deletedAt: Date?
    public let contextLinks: [FlintNoteContextLink]
    public let consentVersion: String
    public let consentedAt: Date?
    public let version: String

    enum CodingKeys: String, CodingKey {
        case id, title, body, version
        case authoredAt = "authored_at"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
        case contextLinks = "context_links"
        case consentVersion = "consent_version"
        case consentedAt = "consented_at"
    }
}

public struct FlintNoteContextLink: Codable, Sendable, Hashable, Identifiable {
    public let type: FlintNoteContextType
    public let id: String

    public init(type: FlintNoteContextType, id: String) {
        self.type = type
        self.id = id
    }
}

public enum FlintNoteContextType: Sendable, Hashable, Codable {
    case event
    case digest
    case block
    case topic
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .event: "event"
        case .digest: "digest"
        case .block: "block"
        case .topic: "topic"
        case .unknown(let value): value
        }
    }

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = switch value {
        case "event": .event
        case "digest": .digest
        case "block": .block
        case "topic": .topic
        default: .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct FlintNotesResponse: Codable, Sendable, Hashable {
    public let data: [FlintNote]
    public let nextCursor: String?
    public let hasMore: Bool
    public let meta: FlintNotesMeta

    enum CodingKeys: String, CodingKey {
        case data, meta
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

public struct FlintNotesMeta: Codable, Sendable, Hashable {
    public let effectiveTimezone: String
    public let accountID: String

    enum CodingKeys: String, CodingKey {
        case effectiveTimezone = "effective_timezone"
        case accountID = "account_id"
    }
}

public struct FlintNoteCreateRequest: Codable, Sendable, Hashable {
    public static let currentConsentVersion = "flint-note-v1"

    public let clientMutationID: UUID
    public let authoredAt: Date
    public let body: String
    public let contextLinks: [FlintNoteContextLink]
    public let consentVersion: String

    public init(
        clientMutationID: UUID,
        authoredAt: Date,
        body: String,
        contextLinks: [FlintNoteContextLink] = [],
        consentVersion: String = Self.currentConsentVersion
    ) {
        self.clientMutationID = clientMutationID
        self.authoredAt = authoredAt
        self.body = body
        self.contextLinks = contextLinks
        self.consentVersion = consentVersion
    }

    enum CodingKeys: String, CodingKey {
        case body
        case clientMutationID = "client_mutation_id"
        case authoredAt = "authored_at"
        case contextLinks = "context_links"
        case consentVersion = "consent_version"
    }
}

public struct FlintNoteResponse: Codable, Sendable, Hashable {
    public let data: FlintNote
}
