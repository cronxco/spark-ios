import Foundation

public struct FlintDailyNote: Codable, Sendable, Hashable {
    public let title: String
    public let summary: String
    public let highlights: [String]
    public let watchouts: [String]
    public let suggestedActions: [String]

    public init(
        title: String,
        summary: String,
        highlights: [String],
        watchouts: [String],
        suggestedActions: [String]
    ) {
        self.title = title
        self.summary = summary
        self.highlights = highlights
        self.watchouts = watchouts
        self.suggestedActions = suggestedActions
    }
}

