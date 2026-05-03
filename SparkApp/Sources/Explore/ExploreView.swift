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
        HStack(spacing: SparkSpacing.xs) {
            ForEach(ExploreSection.allCases, id: \.self) { sec in
                Button {
                    section = sec
                } label: {
                    ExploreSectionChip(sec, isSelected: section == sec)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SparkSpacing.xs)
        .frame(maxWidth: .infinity)
        .sparkGlass(.capsule, tint: Color.sparkElevated.opacity(0.35))
        .padding(.horizontal, SparkSpacing.xl)
        .safeAreaPadding(.top)
        .padding(.top, SparkSpacing.sm)
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
        .padding(.vertical, SparkSpacing.sm)
        .foregroundStyle(isSelected ? Color.sparkTextPrimary : Color.secondary)
        .background {
            if isSelected {
                Capsule().fill(Color.sparkAccent)
            }
        }
    }
}
