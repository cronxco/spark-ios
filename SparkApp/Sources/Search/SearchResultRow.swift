import SparkKit
import SparkUI
import SwiftUI

struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            DomainGlyph(icon: glyph, tint: tint, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(SparkTypography.body)
                    .lineLimit(1)
                if let sub = subtitle {
                    Text(sub)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(SparkSpacing.md)
        .sparkGlass(.roundedRect(SparkRadii.lg), tint: Color.sparkElevated.opacity(0.18))
        .contentShape(Rectangle())
    }

    var glyph: String {
        switch result {
        case .event: "circle.dotted"
        case .object(let h): Self.objectGlyph(type: h.subtitle)
        case .block: "square.stack.3d.up"
        case .metric: "chart.line.uptrend.xyaxis"
        case .integration: "link"
        case .place: "mappin.circle.fill"
        case .tag: "tag.fill"
        case .intent(let h): h.symbol ?? "sparkles"
        }
    }

    /// Object hits carry their raw type key ("day_note") as the subtitle.
    /// Show it as words ("Day note"); other hits' subtitles are already prose.
    var subtitle: String? {
        guard case .object(let h) = result else { return result.subtitle }
        return h.subtitle.map(Self.humanizedType)
    }

    nonisolated static func humanizedType(_ raw: String) -> String {
        let words = raw.replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// Every object used to share one cube, so a track, a bookmark and a day
    /// note were indistinguishable in a list. Unknown types keep the cube.
    nonisolated static func objectGlyph(type: String?) -> String {
        switch type?.lowercased() {
        case "track", "album", "song": "music.note"
        case "playlist": "music.note.list"
        case "podcast", "episode", "podcast_episode": "mic.fill"
        case "bookmark": "bookmark.fill"
        case "article", "newsletter", "publication": "newspaper.fill"
        case "day_note", "note", "document": "note.text"
        case "person", "contact": "person.fill"
        case "book": "book.fill"
        case "movie", "film", "show", "tv_show": "film"
        default: "shippingbox"
        }
    }

    var tint: Color {
        switch result {
        case .event(let h): h.domain.map(Color.domainTint(for:)) ?? .sparkAccent
        case .object: .sparkAccent
        case .block: .domainKnowledge
        case .metric(let h): h.domain.map(Color.domainTint(for:)) ?? .sparkAccent
        case .integration: .sparkOcean
        case .place: .sparkAccent
        case .tag(let h): EventTag(name: h.name, type: h.type).tagTint
        case .intent: .sparkAccent
        }
    }
}
