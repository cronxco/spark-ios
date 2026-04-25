import Foundation

/// Richer block payload returned by `/api/v1/mobile/blocks/{id}`. Adds the
/// underlying event stub the detail screen needs to wire navigation back to
/// its parent event.
public struct BlockDetail: Codable, Sendable, Hashable, Identifiable {
    public let block: Block
    public let event: Event?
    public let aiSummary: String?

    public var id: String { block.id }

    enum CodingKeys: String, CodingKey {
        case block, event
        case aiSummary = "summary_ai"
    }

    public init(block: Block, event: Event? = nil, aiSummary: String? = nil) {
        self.block = block
        self.event = event
        self.aiSummary = aiSummary
    }
}
