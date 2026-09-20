import SparkKit
import SparkUI

/// A single renderable page in the Up to Speed stories flow.
/// Flint digest items expand into multiple sub-pages (header, paragraphs, insights, questions).
/// Derived screens (`opener`, `wrap`) have no backing feed item.
enum UpToSpeedScreen: Identifiable {
    case opener
    case flintHeader(UpToSpeedItem, firstSection: String?)
    case flintParagraph(UpToSpeedItem, text: String, index: Int)
    case flintInsight(UpToSpeedItem, FlintDigestBlock)
    case flintQuestion(UpToSpeedItem, FlintDigestBlock)
    case checkIn(UpToSpeedItem)
    case anomaly(UpToSpeedItem)
    case newsStory(UpToSpeedItem, section: NewsRoundupSection, index: Int, total: Int)
    case newsSummary(UpToSpeedItem)
    case wrap
    /// Everything already caught up on today, offered after the wrap so an
    /// item dismissed by accident can be found again.
    case recap

    var id: String {
        switch self {
        case .opener: "opener"
        case .flintHeader(let item, _): "\(item.id)-h"
        case .flintParagraph(let item, _, let index): "\(item.id)-p\(index)"
        case .flintInsight(let item, let block): "\(item.id)-\(block.id)"
        case .flintQuestion(let item, let block): "\(item.id)-\(block.id)"
        case .checkIn(let item): item.id
        case .anomaly(let item): item.id
        case .newsStory(let item, _, let index, _): "\(item.id)-news\(index)"
        case .newsSummary(let item): item.id
        case .wrap: "wrap"
        case .recap: "recap"
        }
    }

    /// The backing feed item, when the screen has one.
    var item: UpToSpeedItem? {
        switch self {
        case .opener, .wrap, .recap: nil
        case .flintHeader(let item, _): item
        case .flintParagraph(let item, _, _): item
        case .flintInsight(let item, _): item
        case .flintQuestion(let item, _): item
        case .checkIn(let item): item
        case .anomaly(let item): item
        case .newsStory(let item, _, _, _): item
        case .newsSummary(let item): item
        }
    }

    var flintNoteContext: FlintNoteContext {
        switch self {
        case .flintInsight(_, let block), .flintQuestion(_, let block):
            return .block(id: block.id, label: block.title)
        case .flintHeader(let item, _),
             .flintParagraph(let item, _, _),
             .newsStory(let item, _, _, _):
            return .digest(id: item.id, label: Self.digestLabel(for: item))
        // A news summary is its own event, not part of a digest: its id is the
        // event id `NewsSummaryScreen` reads the article with.
        case .newsSummary(let item):
            guard case .newsSummary(let news) = item.payload else { return .generic }
            return .event(id: item.id, label: news.title)
        case .checkIn(let item):
            guard case .checkIn(let checkIn) = item.payload, let eventID = checkIn.eventId else {
                return .generic
            }
            return .event(id: eventID, label: "check-in")
        case .opener, .anomaly, .wrap, .recap:
            return .generic
        }
    }

    private static func digestLabel(for item: UpToSpeedItem) -> String {
        guard case .flintDigest(let digest) = item.payload else { return "Flint digest" }
        return digest.title ?? digest.period.map { "\($0.displayName) Digest" } ?? "Flint digest"
    }
}
