import Foundation
import WidgetKit

/// TimelineEntry carrying a fully decoded today-snapshot. All widget families
/// share this entry type — each view renders whichever fields it needs.
struct SparkWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDataSnapshot
}

/// Base TimelineProvider shared by all Spark widgets. Reads cached data from
/// SwiftData (App Group) — never makes network calls.
struct SparkTimelineProvider: TimelineProvider {
    func placeholder(in _: Context) -> SparkWidgetEntry {
        SparkWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in _: Context, completion: @escaping @Sendable (SparkWidgetEntry) -> Void) {
        Task.detached {
            let snapshot = await WidgetDataSnapshot.fetchToday()
            completion(SparkWidgetEntry(date: .now, snapshot: snapshot))
        }
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<SparkWidgetEntry>) -> Void) {
        Task.detached {
            let snapshot = await WidgetDataSnapshot.fetchToday()
            let entry = SparkWidgetEntry(date: .now, snapshot: snapshot)
            // Reload every 15 minutes during the day; widgets are also
            // explicitly reloaded after a silent push applies delta changes.
            let reload = Date(timeIntervalSinceNow: 15 * 60)
            completion(Timeline(entries: [entry], policy: .after(reload)))
        }
    }
}
