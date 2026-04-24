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

        public var tint: Color {
            switch self {
            case .health: .red
            case .activity: .green
            case .money: .sparkAccent
            case .media: .purple
            case .knowledge: .blue
            case .online: .teal
            }
        }
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
            Text(domain.label)
        }
        .font(SparkTypography.captionStrong)
        .padding(.horizontal, SparkSpacing.md)
        .padding(.vertical, SparkSpacing.sm)
        .foregroundStyle(isSelected ? Color.white : domain.tint)
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
