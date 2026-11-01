import SparkKit
import SparkUI
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
            Tab(value: AppTab.day) {
                DayPagerView()
            } label: {
                tabLabel("Day", .day)
            }
            Tab(value: AppTab.explore) {
                ExploreView()
            } label: {
                tabLabel("Explore", .explore)
            }
            Tab(value: AppTab.knowledge) {
                KnowledgeView()
            } label: {
                tabLabel("Knowledge", .knowledge)
            }
            Tab(value: AppTab.flint) {
                FlintView()
            } label: {
                tabLabel("Flint", .flint)
            }
            Tab(value: AppTab.cmd) {
                CmdView(apiClient: model.apiClient)
            } label: {
                tabLabel("CMD", .command)
            }
        }
    }
}

// Tab bar items take only an image, so each glyph is drawn into one
// (`docs/design-language.md` section 6).
@MainActor
private func tabLabel(_ title: String, _ icon: SparkIcon) -> some View {
    Label {
        Text(title)
    } icon: {
        icon.image()
    }
}

enum AppTab: Hashable {
    case day, explore, knowledge, flint, cmd
}
