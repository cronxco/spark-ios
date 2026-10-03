import Foundation

/// One item in Flint's Review queue: an automated decision or a suggestion
/// Spark was not sure enough to act on (GET /flint/review).
public struct FlintReviewItem: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let kind: FlintReviewKind
    public let title: String
    public let summary: String
    /// On a 0–1 scale for every kind.
    public let confidence: Double?
    public let createdAt: Date?
    public let relationshipType: String?
    public let subject: FlintReviewEvent
    public let linked: FlintReviewEvent?
    public let candidates: [FlintReviewEvent]
    public let actions: [FlintReviewAction]

    enum CodingKeys: String, CodingKey {
        case id, kind, title, summary, confidence, subject, linked, candidates, actions
        case createdAt = "created_at"
        case relationshipType = "relationship_type"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(FlintReviewKind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        relationshipType = try container.decodeIfPresent(String.self, forKey: .relationshipType)
        subject = try container.decode(FlintReviewEvent.self, forKey: .subject)
        linked = try container.decodeIfPresent(FlintReviewEvent.self, forKey: .linked)
        candidates = try container.decodeIfPresent([FlintReviewEvent].self, forKey: .candidates) ?? []
        actions = try container.decode([FlintReviewAction].self, forKey: .actions)
    }
}

/// A transaction or receipt shown in a review item.
public struct FlintReviewEvent: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String?
    public let amount: Double?
    public let unit: String?
    public let time: Date?
    public let service: String?
    /// Set on a receipt suggestion's candidates only.
    public let confidence: Double?
}

public enum FlintReviewKind: String, Codable, Sendable, Hashable {
    case receiptSuggestion = "receipt_suggestion"
    case receiptAutoMatch = "receipt_auto_match"
    case linkSuggestion = "link_suggestion"
    case autoLink = "auto_link"

    public var label: String {
        switch self {
        case .receiptSuggestion: "Receipt suggestion"
        case .receiptAutoMatch: "Receipt linked automatically"
        case .linkSuggestion: "Link suggestion"
        case .autoLink: "Linked automatically"
        }
    }
}

public enum FlintReviewAction: String, Codable, Sendable, Hashable {
    case confirm, dismiss, keep, undo

    public var label: String {
        switch self {
        case .confirm: "Confirm"
        case .dismiss: "Dismiss"
        case .keep: "Keep"
        case .undo: "Undo"
        }
    }
}

public struct FlintReviewResponse: Codable, Sendable {
    public let data: [FlintReviewItem]
}

public struct FlintReviewActionRequest: Codable, Sendable, Hashable {
    public let action: FlintReviewAction
    public let transactionID: String?

    public init(action: FlintReviewAction, transactionID: String? = nil) {
        self.action = action
        self.transactionID = transactionID
    }

    enum CodingKeys: String, CodingKey {
        case action
        case transactionID = "transaction_id"
    }
}
