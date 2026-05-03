import SparkKit
import SparkUI
import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: AppTab = .day

    var body: some View {
        @Bindable var model = model
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
            Tab(value: AppTab.search, role: .search) {
                SearchView()
            }
        }
        .onChange(of: model.pendingRoute) { _, new in
            guard new != nil else { return }
            selection = .day
        }
    }
}

enum AppTab: Hashable {
    case day, explore, knowledge, flint, search
}
