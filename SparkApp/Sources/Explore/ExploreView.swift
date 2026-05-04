import SparkUI
import SwiftUI

struct ExploreView: View {
    @State private var section: ExploreSection = .map

    var body: some View {
        currentSectionView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                sectionPicker
            }
    }

    @ViewBuilder
    private var currentSectionView: some View {
        switch section {
        case .map:
            MapView(isEmbedded: true)
        case .health:
            HealthExploreView()
        case .metrics:
            MetricsExploreView()
        case .money:
            MoneyExploreView()
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: SparkSpacing.xs) {
            ForEach(ExploreSection.allCases, id: \.self) { sec in
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        section = sec
                    }
                } label: {
                    ExploreSectionChip(sec, isSelected: section == sec)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SparkSpacing.sm)
        .frame(maxWidth: .infinity)
        .sparkGlass(.capsule, tint: Color.sparkElevated.opacity(0.48))
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.bottom, SparkSpacing.xl + SparkSpacing.sm)
    }
}

enum ExploreSection: CaseIterable {
    case map, health, metrics, money

    var label: String {
        switch self {
        case .map: "Map"
        case .health: "Health"
        case .metrics: "Metrics"
        case .money: "Money"
        }
    }

    var icon: String {
        switch self {
        case .map: "mappin"
        case .health: "heart.fill"
        case .metrics: "bolt.fill"
        case .money: "sterlingsign"
        }
    }

    var tint: Color {
        switch self {
        case .map: .sparkOcean
        case .health: .sparkSuccess
        case .metrics: .sparkAccent
        case .money: .domainMoney
        }
    }
}

private struct ExploreSectionChip: View {
    let section: ExploreSection
    let isSelected: Bool

    init(_ section: ExploreSection, isSelected: Bool) {
        self.section = section
        self.isSelected = isSelected
    }

    var body: some View {
        HStack(spacing: SparkSpacing.xs) {
            Image(systemName: section.icon)
            Text(section.label)
        }
        .font(SparkTypography.captionStrong)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SparkSpacing.sm)
        .padding(.vertical, SparkSpacing.md)
        .foregroundStyle(isSelected ? Color.sparkTextPrimary : Color.secondary)
        .background {
            if isSelected {
                Capsule()
                    .fill(Color.sparkAccent)
                    .shadow(color: section.tint.opacity(0.24), radius: 10, x: 0, y: 4)
            }
        }
        .sparkGlass(.capsule, tint: isSelected ? section.tint.opacity(0.16) : Color.clear)
    }
}
