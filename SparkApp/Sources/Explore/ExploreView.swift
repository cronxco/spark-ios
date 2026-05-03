import SparkUI
import SwiftUI

struct ExploreView: View {
    @State private var section: ExploreSection = .map

    var body: some View {
        ZStack(alignment: .top) {
            currentSectionView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SparkSpacing.sm) {
                ForEach(ExploreSection.allCases, id: \.self) { sec in
                    Button {
                        section = sec
                    } label: {
                        ExploreSectionChip(sec, isSelected: section == sec)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
        }
        .safeAreaPadding(.top)
        .padding(.vertical, SparkSpacing.sm)
        .background(.ultraThinMaterial)
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
        case .map: "map"
        case .health: "heart.fill"
        case .metrics: "chart.line.uptrend.xyaxis"
        case .money: "sterlingsign.circle.fill"
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
        .padding(.horizontal, SparkSpacing.md)
        .padding(.vertical, SparkSpacing.sm)
        .foregroundStyle(isSelected ? Color.white : section.tint)
        .sparkGlass(.capsule, tint: isSelected ? section.tint : section.tint.opacity(0.15))
    }
}
