import SparkKit
import SwiftUI

/// The glyph and tint for each kind of block, so every screen that shows a
/// block marks it the same way.
public extension BlockKind {
    var systemImage: String {
        switch self {
        case .aiSummary, .takeaways: "sparkles"
        case .content: "doc.plaintext"
        case .raw: "curlybraces"

        case .heartRate: "heart.fill"
        case .energy: "flame.fill"
        case .intensity: "bolt.fill"
        case .duration, .sleepStage: "clock"
        case .distance: "map"
        case .activityMetric: "figure.walk"
        case .workoutMetric: "figure.strengthtraining.traditional"
        case .biometrics: "waveform.path.ecg"
        case .mentalEnergy: "brain.head.profile"
        case .physicalEnergy: "battery.75percent"
        case .contributor: "chart.bar.fill"

        case .albumArt: "music.note"
        case .bookCover: "book.closed.fill"
        case .image, .immichPhoto: "photo"
        case .bookmarkMetadata: "bookmark.fill"

        case .track: "music.note"
        case .artist: "music.mic"
        case .book: "book.fill"
        case .bookAuthor: "person.fill"
        case .beer: "mug.fill"
        case .brewery: "building.2.fill"
        case .exercise, .exerciseSummary: "dumbbell.fill"
        case .coachRecommendation: "chart.line.uptrend.xyaxis"
        case .badgeEarned: "rosette"
        case .url: "link"

        case .bankTransfer: "building.columns.fill"
        case .potTransfer: "arrow.left.arrow.right"
        case .balanceChange, .balanceSnapshot: "sterlingsign.circle.fill"
        case .foreignExchange: "dollarsign.arrow.circlepath"
        case .virtualCard: "creditcard.fill"
        case .merchant: "storefront.fill"
        case .spentToday: "cart.fill"
        case .receiptLineItem, .receiptTaxSummary, .receiptPaymentMethod: "receipt"

        case .dayTask: "circle"
        case .docTask: "square"
        case .eventTime: "clock"
        case .eventLocation: "mappin.and.ellipse"
        case .eventDetails: "info.circle"
        case .clusterSummary: "photo.on.rectangle.angled"
        case .clusterPeople: "person.2.fill"

        case .flintQuestion: "questionmark.circle.fill"
        case .flintEditorialNote: "pencil.and.scribble"
        case .flintHealthInsight: "heart.fill"
        case .flintNews: "newspaper.fill"
        case .flintReadingPick: "book.fill"
        case .flintReadingDrop: "trash"
        case .flintInsight, .flintDayContext: "sparkles"

        case .genericValue: "number"
        case .genericContent: "square.stack.3d.up"
        }
    }

    /// The domain whose ink colours the hero value (§3.6), or nil.
    var domain: String? {
        switch self {
        case .energy, .intensity, .activityMetric, .workoutMetric, .exercise, .exerciseSummary,
             .coachRecommendation, .distance:
            "activity"
        case .heartRate, .duration, .sleepStage, .biometrics, .mentalEnergy, .physicalEnergy, .contributor,
             .flintHealthInsight:
            "health"
        case .albumArt, .track, .artist, .image, .immichPhoto, .clusterSummary, .clusterPeople:
            "media"
        case .bankTransfer, .potTransfer, .balanceChange, .balanceSnapshot, .foreignExchange,
             .virtualCard, .merchant, .spentToday, .receiptLineItem, .receiptTaxSummary,
             .receiptPaymentMethod:
            "money"
        case .book, .bookAuthor, .bookCover, .bookmarkMetadata, .content, .url:
            "knowledge"
        default: nil
        }
    }

    var tint: Color {
        switch self {
        case .heartRate: .sparkError
        case .energy, .intensity, .activityMetric, .workoutMetric, .exercise, .exerciseSummary,
             .coachRecommendation, .distance:
            .domainActivity
        case .duration, .sleepStage, .biometrics, .mentalEnergy, .physicalEnergy, .contributor,
             .flintHealthInsight:
            .domainHealth
        case .albumArt, .track, .artist, .image, .immichPhoto, .clusterSummary, .clusterPeople:
            .domainMedia
        case .bankTransfer, .potTransfer, .balanceChange, .balanceSnapshot, .foreignExchange,
             .virtualCard, .merchant, .spentToday, .receiptLineItem, .receiptTaxSummary,
             .receiptPaymentMethod:
            .domainMoney
        case .book, .bookAuthor, .bookCover, .bookmarkMetadata, .content, .url:
            .domainKnowledge
        case .flintNews, .flintReadingPick: .sparkOcean
        case .flintReadingDrop, .raw: .sparkTextSecondary
        default: .sparkAccent
        }
    }
}
