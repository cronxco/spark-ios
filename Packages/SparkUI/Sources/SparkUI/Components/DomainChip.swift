import SwiftUI

public struct DomainChip: View {
    public enum Domain: String, Sendable, CaseIterable {
        case health
        case activity
        case money
        case media
        case knowledge
        case online

        public var label: String { rawValue.capitalized }

        public var icon: String {
            switch self {
            case .health: "heart.fill"
            case .activity: "figure.walk"
            case .money: "sterlingsign"
            case .media: "play.rectangle.fill"
            case .knowledge: "brain"
            case .online: "globe"
            }
        }

        /// The domain fill (§3.2), for the glyph and the chip's ground.
        public var tint: Color { EntityPresentation.tint(domain: rawValue) }

        /// The domain ink (§3.2), for the label on an unselected chip.
        public var ink: Color { Color.domainInk(for: rawValue) ?? .primary }
    }

    let domain: Domain
    let isSelected: Bool

    public init(domain: Domain, isSelected: Bool = false) {
        self.domain = domain
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: SparkSpacing.xs) {
            Image(systemName: domain.icon)
                .foregroundStyle(isSelected ? Color.white : domain.tint)
            Text(domain.label)
                .foregroundStyle(isSelected ? Color.white : domain.ink)
        }
        .font(SparkTypography.captionStrong)
        .padding(.horizontal, SparkSpacing.md)
        .padding(.vertical, SparkSpacing.sm)
        .sparkGlass(.capsule, tint: isSelected ? domain.tint : domain.tint.opacity(0.15))
    }
}

#Preview {
    VStack(spacing: SparkSpacing.sm) {
        HStack { ForEach(DomainChip.Domain.allCases, id: \.self) { DomainChip(domain: $0) } }
        DomainChip(domain: .health, isSelected: true)
    }
    .padding()
    .background(Color.sparkSurface)
}
