import ActivityKit
import SwiftUI
import WidgetKit

@main
struct SparkLiveActivitiesBundle: WidgetBundle {
    var body: some Widget {
        PlaceholderLiveActivity()
    }
}

/// Phase 1 stub. The real Live Activity lives in Phase 3.
public struct PlaceholderActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var status: String
        public init(status: String) { self.status = status }
    }

    public var title: String
    public init(title: String) { self.title = title }
}

struct PlaceholderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlaceholderActivityAttributes.self) { _ in
            Text("Spark")
                .containerBackground(for: .widget) { Color(.systemBackground) }
        } dynamicIsland: { _ in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text("Spark") }
                DynamicIslandExpandedRegion(.trailing) { EmptyView() }
                DynamicIslandExpandedRegion(.center) { EmptyView() }
                DynamicIslandExpandedRegion(.bottom) { EmptyView() }
            } compactLeading: {
                Text("✦")
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Text("✦")
            }
        }
    }
}
