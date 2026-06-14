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
                if let sub = result.subtitle {
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
        case .event(let hit):
            EntityPresentation.icon(domain: hit.domain, type: "event")
        case .object:
            EntityPresentation.icon(type: "object")
        case .block:
            EntityPresentation.icon(type: "block")
        case .metric(let hit):
            EntityPresentation.icon(domain: hit.domain, type: "metric")
        case .integration(let hit):
            EntityPresentation.icon(service: hit.service, type: "integration")
        case .place:
            EntityPresentation.icon(type: "place")
        case .tag: "tag.fill"
        case .intent(let h): h.symbol ?? "sparkles"
        }
    }

    var tint: Color {
        switch result {
        case .event(let hit): EntityPresentation.tint(domain: hit.domain)
        case .object: EntityPresentation.tint(domain: nil)
        case .block: EntityPresentation.tint(domain: "knowledge")
        case .metric(let hit): EntityPresentation.tint(domain: hit.domain)
        case .integration: EntityPresentation.tint(domain: nil)
        case .place: EntityPresentation.tint(domain: nil)
        case .tag(let h): EventTag(name: h.name, type: h.type).tagTint
        case .intent: .sparkAccent
        }
    }
}
