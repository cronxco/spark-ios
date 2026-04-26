import SparkKit
import SparkUI
import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: Tab = .today
    @Query(filter: #Predicate<CachedNotification> { !$0.isRead })
    private var unreadNotifications: [CachedNotification]

    var body: some View {
        @Bindable var model = model
        TabView(selection: $selection) {
            DayPagerView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(Tab.today)

            MapView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(Tab.map)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            NotificationsInboxView()
                .tabItem { Label("Inbox", systemImage: "bell") }
                .badge(unreadNotifications.count)
                .tag(Tab.notifications)

            SettingsRootView()
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
