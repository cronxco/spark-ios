import SparkKit

/// A single renderable page in the Up to Speed stories flow.
/// Flint digest items expand into multiple sub-pages (header, paragraphs, insights, questions).
enum UpToSpeedScreen: Identifiable {
    case flintHeader(UpToSpeedItem, firstSection: String?)
    case flintParagraph(UpToSpeedItem, text: String, index: Int)
    case flintInsight(UpToSpeedItem, FlintDigestBlock)
    case flintQuestion(UpToSpeedItem, FlintDigestBlock)
    case checkIn(UpToSpeedItem)
    case anomaly(UpToSpeedItem)
    case newsSummary(UpToSpeedItem)

    var id: String {
        switch self {
        case .flintHeader(let item, _): "\(item.id)-h"
        case .flintParagraph(let item, _, let index): "\(item.id)-p\(index)"
        case .flintInsight(let item, let block): "\(item.id)-\(block.id)"
        case .flintQuestion(let item, let block): "\(item.id)-\(block.id)"
        case .checkIn(let item): item.id
        case .anomaly(let item): item.id
        case .newsSummary(let item): item.id
        }
    }

    var item: UpToSpeedItem {
        switch self {
        case .flintHeader(let item, _): item
        case .flintParagraph(let item, _, _): item
        case .flintInsight(let item, _): item
        case .flintQuestion(let item, _): item
        case .checkIn(let item): item
        case .anomaly(let item): item
        case .newsSummary(let item): item
        }
    }

    /// Whether advancing past this screen auto-enqueues a markRead call.
    /// Flint sub-pages handle read-tracking themselves (via onQuestionAnswered / boundary detection).
    /// Check-in uses CheckInsEndpoint.submit as its read signal.
    var sendsMarkRead: Bool {
        switch self {
        case .flintHeader, .flintParagraph, .flintInsight, .flintQuestion, .checkIn: false
        case .anomaly, .newsSummary: true
        }
    }
}
