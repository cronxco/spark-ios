import SparkKit
import SparkUI
import SwiftUI

struct ExploreView: View {
    @Environment(AppModel.self) private var appModel
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
        .sparkOpensDetailRoutes(on: $path)
        .onChange(of: appModel.pendingDestination, initial: true) { _, destination in
            guard let destination, let target = ExploreSection(destination: destination) else { return }
            // A detail left open in this tab would hide the section asked for.
            path.removeAll()
            section = target
            appModel.pendingDestination = nil
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

    init?(destination: CmdDestination) {
        switch destination {
        case .exploreHealth: self = .health
        case .exploreMoney: self = .money
        case .exploreMetrics: self = .metrics
        case .exploreTags: self = .tags
        case .exploreMap: self = .map
        case .day, .flint, .knowledge: return nil
        }
    }

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
