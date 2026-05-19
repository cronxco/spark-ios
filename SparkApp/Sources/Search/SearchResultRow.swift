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
        case .event: "circle.dotted"
        case .object: "shippingbox"
        case .block: "square.stack.3d.up"
        case .metric: "chart.line.uptrend.xyaxis"
        case .integration: "link"
        case .place: "mappin.circle.fill"
        case .tag: "tag.fill"
        case .intent(let h): h.symbol ?? "sparkles"
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
