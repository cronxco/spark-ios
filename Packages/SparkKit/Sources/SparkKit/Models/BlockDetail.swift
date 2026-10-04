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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let wrappedBlock = try container.decodeIfPresent(Block.self, forKey: .block) {
            block = wrappedBlock
            event = try container.decodeIfPresent(Event.self, forKey: .event)
            aiSummary = try container.decodeIfPresent(String.self, forKey: .aiSummary)
        } else {
            block = try Block(from: decoder)
            event = nil
            aiSummary = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(block, forKey: .block)
        try container.encodeIfPresent(event, forKey: .event)
        try container.encodeIfPresent(aiSummary, forKey: .aiSummary)
    }
}
