import SparkKit
import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: AppTab = .day

    var body: some View {
        @Bindable var model = model

        tabs
            .tabBarMinimizeBehavior(.onScrollDown)
            .onChange(of: model.pendingRoute, initial: true) { _, new in
                guard new != nil else { return }
                switch new {
                case .knowledgeTask, .knowledgeProject: selection = .knowledge
                default: selection = .day
                }
            }
            .onChange(of: model.pendingDestination, initial: true) { _, new in
                guard let new else { return }
                switch new {
                case .day: selection = .day
                case .flint: selection = .flint
                case .knowledge: selection = .knowledge
                // ExploreView picks the section, then clears the destination.
                case .exploreHealth, .exploreMoney, .exploreMetrics, .exploreTags, .exploreMap:
                    selection = .explore
                    return
                }
                model.pendingDestination = nil
            }
            .onChange(of: model.pendingSearchQuery, initial: true) { _, new in
                guard new != nil else { return }
                selection = .cmd
            }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            Tab("Day", systemImage: "sun.max.fill", value: AppTab.day) {
                DayPagerView()
            }
            Tab("Explore", systemImage: "safari", value: AppTab.explore) {
                ExploreView()
            }
            Tab("Knowledge", systemImage: "books.vertical.fill", value: AppTab.knowledge) {
                KnowledgeView()
            }
            Tab("Flint", systemImage: "sparkles", value: AppTab.flint) {
                FlintView()
            }
            Tab("CMD", systemImage: "terminal", value: AppTab.cmd) {
                CmdView(apiClient: model.apiClient)
            }
        }
    }
}

enum AppTab: Hashable {
    case day, explore, knowledge, flint, cmd
}
