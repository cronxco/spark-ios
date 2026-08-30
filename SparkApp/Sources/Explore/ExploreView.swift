import SparkUI
import SwiftUI

struct ExploreView: View {
    @Environment(\.tabAccessoryCoordinator) private var tabAccessoryCoordinator
    @State private var section: ExploreSection = .health

    var body: some View {
        currentSectionView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                registerSectionAccessory()
            }
            .onChange(of: section) { _, _ in
                registerSectionAccessory()
            }
            .onDisappear {
                tabAccessoryCoordinator?.clear(owner: .explore)
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

    private func registerSectionAccessory() {
        tabAccessoryCoordinator?.set(TabAccessory(
            owner: .explore,
            title: "Section",
            items: ExploreSection.allCases.map {
                TabAccessoryItem(id: $0.id, title: $0.label, systemImage: $0.icon)
            },
            selectedID: section.id,
            select: { id in
                guard let selected = ExploreSection.allCases.first(where: { $0.id == id }) else { return }
                section = selected
            }
        ))
    }
}

enum ExploreSection: CaseIterable, Equatable {
    case health, money, metrics, map

    var id: String {
        switch self {
        case .map: "map"
        case .health: "health"
        case .metrics: "metrics"
        case .money: "money"
        }
    }

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
