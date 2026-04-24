import SwiftUI
import WidgetKit

@main
struct SparkWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PlaceholderWatchWidget()
    }
}

struct PlaceholderWatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "co.cronx.spark.watch.widgets.placeholder", provider: Provider()) { _ in
            Text("Spark")
                .containerBackground(for: .widget) { Color.black }
        }
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

private struct Provider: TimelineProvider {
    func placeholder(in _: Context) -> Entry { Entry(date: .now) }
    func getSnapshot(in _: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}

private struct Entry: TimelineEntry { let date: Date }
