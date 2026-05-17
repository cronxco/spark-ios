import SparkKit
import SparkUI
import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: AppTab = .day
    @State private var tabAccessoryCoordinator = TabAccessoryCoordinator()

    var body: some View {
        @Bindable var model = model
        let activeAccessory = tabAccessoryCoordinator.accessory?.owner == selection
            ? tabAccessoryCoordinator.accessory
            : nil

        ZStack {
            if selection == .day {
                SparkResolvedAppBackground()
            }

            tabs
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory(isEnabled: activeAccessory != nil) {
                    if let activeAccessory {
                        TabAccessoryView(accessory: activeAccessory)
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .environment(\.tabAccessoryCoordinator, tabAccessoryCoordinator)
        .onChange(of: model.pendingRoute) { _, new in
            guard new != nil else { return }
            selection = .day
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
            Tab(value: AppTab.search, role: .search) {
                SearchView()
            }
        }
    }
}

enum AppTab: Hashable {
    case day, explore, knowledge, flint, search
}
