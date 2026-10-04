import SparkUI
import SwiftUI

struct ExploreView: View {
    @State private var section: ExploreSection = .health
    @State private var path: [DetailRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            SparkSectionPager(
                title: "Explore",
                sections: ExploreSection.allCases.map { SparkPagerSection(id: $0, title: $0.label) },
                selection: $section,
                swipeDisabled: [.map]
            ) { section in
                page(for: section)
            }
            .sparkMainNavigationTitle("Explore")
            .sparkDetailDestinations()
            .sparkMainAppToolbar()
        }
    }

    @ViewBuilder
    private func page(for section: ExploreSection) -> some View {
        switch section {
        case .health:
            HealthExploreView(path: $path)
        case .money:
            MoneyExploreView(path: $path)
        case .metrics:
            MetricsExploreView(path: $path)
        case .tags:
            TagsExploreView()
        case .map:
            MapView(path: $path)
        }
    }
}

/// Map comes last: it keeps the horizontal drag for panning, so it is the
/// one section you swipe into but leave with the picker.
enum ExploreSection: CaseIterable, Hashable {
    case health, money, metrics, tags, map

    var label: String {
        switch self {
        case .health: "Health"
        case .money: "Money"
        case .metrics: "Metrics"
        case .tags: "Tags"
        case .map: "Map"
        }
    }
}
