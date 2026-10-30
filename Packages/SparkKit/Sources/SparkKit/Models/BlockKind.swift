import Foundation

/// What a block is, parsed once from its `block_type`.
///
/// This is the iOS half of the web's layout lookup: the web renders
/// `blocks.types.{block_type}` when that view exists and falls back to a
/// generic card otherwise. Every screen that picks a layout, an icon or an
/// order for a block switches on this instead of matching substrings of
/// `block_type`, so adding a layout for a type is one new case.
///
/// Types without a case of their own fall back to `.genericValue` when the
/// block carries a value and `.genericContent` when it doesn't.
public enum BlockKind: Hashable, Sendable {
    // MARK: Text

    /// Text a model wrote about the source: `*_tldr`, `*_summary_paragraph`,
    /// `*_summary_short`, `*_summary_tweet`, `bookmark_summary`.
    case aiSummary
    /// A model's bullet-point takeaways: `*_key_takeaways`.
    case takeaways
    /// The source's own text: a newsletter issue, an article body.
    case content
    /// An unprocessed payload kept for debugging. Never shown.
    case raw

    // MARK: Values

    case heartRate
    case energy
    case intensity
    case duration
    case sleepStage
    case distance
    case activityMetric
    case workoutMetric
    case biometrics
    /// Scored out of 5.
    case mentalEnergy
    /// Scored out of 5.
    case physicalEnergy
    /// An Oura readiness or sleep contributor, as a percentage.
    case contributor

    // MARK: Media

    case albumArt
    case bookCover
    case image
    case bookmarkMetadata
    case immichPhoto

    // MARK: Records

    case track
    case artist
    case book
    case bookAuthor
    case beer
    case brewery
    case exercise
    case exerciseSummary
    case coachRecommendation
    case badgeEarned
    case url

    // MARK: Money

    case bankTransfer
    case potTransfer
    case balanceChange
    case balanceSnapshot
    case foreignExchange
    case virtualCard
    case merchant
    case spentToday
    case receiptLineItem
    case receiptTaxSummary
    case receiptPaymentMethod

    // MARK: Tasks, events and places

    case dayTask
    case docTask
    case eventTime
    case eventLocation
    case eventDetails
    case clusterSummary
    case clusterPeople

    // MARK: Flint

    case flintQuestion
    case flintEditorialNote
    case flintInsight
    case flintHealthInsight
    case flintNews
    case flintReadingPick
    case flintReadingDrop
    case flintDayContext

    // MARK: Fallbacks

    case genericValue
    case genericContent

    public init(blockType: String, hasValue: Bool = false) {
        let type = blockType.lowercased()

        if let kind = Self.exactTypes[type] {
            self = kind
        } else if type.split(separator: "_").contains("raw") {
            self = .raw
        } else if type.hasSuffix("_key_takeaways") {
            self = .takeaways
        } else if Self.aiSummarySuffixes.contains(where: { type.hasSuffix($0) }) {
            self = .aiSummary
        } else if type.hasSuffix("_content") {
            self = .content
        } else {
            self = hasValue ? .genericValue : .genericContent
        }
    }

    /// Text written by a model rather than by the source. These are marked
    /// as such wherever they're shown.
    public var isAIWritten: Bool {
        self == .aiSummary || self == .takeaways
    }

    public var isFlint: Bool {
        switch self {
        case .flintQuestion, .flintEditorialNote, .flintInsight, .flintHealthInsight,
             .flintNews, .flintReadingPick, .flintReadingDrop, .flintDayContext:
            true
        default:
            false
        }
    }

    private static let aiSummarySuffixes = ["_tldr", "_summary_paragraph", "_summary_short", "_summary_tweet"]

    private static let exactTypes: [String: BlockKind] = [
        "tldr": .aiSummary,
        "summary_paragraph": .aiSummary,
        "paragraph_summary": .aiSummary,
        "summary_short": .aiSummary,
        "summary_tweet": .aiSummary,
        "bookmark_summary": .aiSummary,
        "key_takeaways": .takeaways,
        "content": .content,

        "heart_rate": .heartRate,
        "heartrate": .heartRate,
        "energy": .energy,
        "intensity": .intensity,
        "duration": .duration,
        "sleep_stage": .sleepStage,
        "distance": .distance,
        "activity_metric": .activityMetric,
        "workout_metric": .workoutMetric,
        "biometrics": .biometrics,
        "mental_energy": .mentalEnergy,
        "physical_energy": .physicalEnergy,
        "contributor": .contributor,

        "album_art": .albumArt,
        "book_cover": .bookCover,
        "image": .image,
        "bookmark_metadata": .bookmarkMetadata,
        "immich_photo": .immichPhoto,

        "track_details": .track,
        "artist": .artist,
        "book": .book,
        "book_author": .bookAuthor,
        "beer_details": .beer,
        "beer_brewery": .brewery,
        "brewery_details": .brewery,
        "exercise": .exercise,
        "exercise_summary": .exerciseSummary,
        "coach_recommendation": .coachRecommendation,
        "badge_earned": .badgeEarned,
        "url": .url,

        "bank_transfer": .bankTransfer,
        "pot_transfer": .potTransfer,
        "balance_change": .balanceChange,
        "balance_snapshot": .balanceSnapshot,
        "foreign_exchange": .foreignExchange,
        "virtual_card": .virtualCard,
        "merchant": .merchant,
        "spent_today": .spentToday,
        "receipt_line_item": .receiptLineItem,
        "receipt_tax_summary": .receiptTaxSummary,
        "receipt_payment_method": .receiptPaymentMethod,

        "day_task": .dayTask,
        "doc_task": .docTask,
        "event_time": .eventTime,
        "event_location": .eventLocation,
        "event_details": .eventDetails,
        "cluster_summary": .clusterSummary,
        "cluster_people": .clusterPeople,

        "flint_user_question": .flintQuestion,
        "flint_editorial_note": .flintEditorialNote,
        "flint_insight": .flintInsight,
        "flint_health_insight": .flintHealthInsight,
        "flint_news": .flintNews,
        "flint_reading_pick": .flintReadingPick,
        "flint_reading_drop": .flintReadingDrop,
        "flint_day_context": .flintDayContext,
    ]
}

public extension Block {
    var kind: BlockKind {
        BlockKind(blockType: blockType, hasValue: value?.isEmpty == false)
    }

    /// The first couple of lines of the block's text, without markup, so a
    /// row can say which block it is before you open it.
    var preview: String? {
        guard let content = content?.sparkPlainTextFromHTMLFragment else { return nil }
        let collapsed = content
            .replacingOccurrences(of: "[#*_>`]", with: "", options: .regularExpression)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return collapsed.count > 220 ? String(collapsed.prefix(220)) + "…" : collapsed
    }
}

public extension FlintDigestBlock {
    var kind: BlockKind {
        BlockKind(blockType: blockType)
    }
}
