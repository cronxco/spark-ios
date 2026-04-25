import SparkUI
import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: Tab = .today

    var body: some View {
        @Bindable var model = model
        TabView(selection: $selection) {
            DayPagerView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(Tab.today)

            ComingSoonTab(title: "Map", systemImage: "map")
                .tabItem { Label("Map", systemImage: "map") }
                .tag(Tab.map)

            ComingSoonTab(title: "Search", systemImage: "magnifyingglass")
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            ComingSoonTab(title: "Notifications", systemImage: "bell")
                .tabItem { Label("Inbox", systemImage: "bell") }
                .tag(Tab.notifications)

            SettingsPlaceholderView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .onChange(of: model.pendingRoute) { _, new in
            guard new != nil else { return }
            selection = .today
        }
    }

    enum Tab: Hashable {
        case today, map, search, notifications, settings
    }
}

private struct ComingSoonTab: View {
    let title: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            EmptyState(systemImage: systemImage, title: title, message: "Coming in Phase 2.")
                .navigationTitle(title)
        }
    }
}
