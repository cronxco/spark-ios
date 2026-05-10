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
        Picker("Section", selection: $section) {
            ForEach(ExploreSection.allCases, id: \.self) { sec in
                Label(sec.label, systemImage: sec.icon).tag(sec)
            }
        }
        .pickerStyle(.segmented)
        .padding(SparkSpacing.sm)
        .sparkGlass(.roundedRect(SparkRadii.lg), tint: Color.sparkElevated.opacity(0.48))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.top, SparkSpacing.sm)
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
}
