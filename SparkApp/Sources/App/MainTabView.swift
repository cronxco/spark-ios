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

            ComingSoonTab(title: "Timeline", systemImage: "clock")
                .tabItem { Label("Timeline", systemImage: "clock") }
                .tag(Tab.timeline)

            ComingSoonTab(title: "Settings", systemImage: "gear")
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(Tab.settings)
        }
        .onChange(of: model.pendingRoute) { _, new in
            guard new != nil else { return }
            selection = .today
        }
    }

    enum Tab: Hashable { case today, timeline, settings }
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
