import SparkKit
import SwiftData
import SwiftUI
import WidgetKit

/// Phase 1 plumbing widget. Proves the App Group container and the shared
/// Keychain are reachable from an extension before we start building real
/// widget content in Phase 3.
struct PlumbingSmokeTestWidget: Widget {
    let kind: String = "co.cronx.spark.widgets.plumbing"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlumbingProvider()) { entry in
            PlumbingSmokeTestView(entry: entry)
        }
        .configurationDisplayName("Spark · Plumbing")
        .description("Verifies the App Group container and shared Keychain.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PlumbingEntry: TimelineEntry {
    let date: Date
    let containerOK: Bool
    let keychainOK: Bool
    let failureMessage: String?
}

struct PlumbingProvider: TimelineProvider {
    func placeholder(in _: Context) -> PlumbingEntry {
        PlumbingEntry(date: .now, containerOK: true, keychainOK: true, failureMessage: nil)
    }

    func getSnapshot(in _: Context, completion: @escaping @Sendable (PlumbingEntry) -> Void) {
        Task.detached { completion(await Self.probe()) }
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<PlumbingEntry>) -> Void) {
        Task.detached {
            let entry = await Self.probe()
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
        }
    }

    private static func probe() async -> PlumbingEntry {
        var containerOK = false
        var keychainOK = false
        var failures: [String] = []

        do {
            _ = try SparkDataStore.makeContainer()
            containerOK = true
        } catch {
            failures.append("container: \(error.localizedDescription)")
        }

        let store = KeychainTokenStore()
        let access = await store.accessToken()
        let refresh = await store.refreshToken()
        keychainOK = access != nil || refresh == nil
        if !keychainOK {
            failures.append("keychain: unreachable")
        }

        return PlumbingEntry(
            date: .now,
            containerOK: containerOK,
            keychainOK: keychainOK,
            failureMessage: failures.isEmpty ? nil : failures.joined(separator: " · ")
        )
    }
}

struct PlumbingSmokeTestView: View {
    let entry: PlumbingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Spark plumbing")
                .font(.caption).foregroundStyle(.secondary)
            row(label: "App Group", ok: entry.containerOK)
            row(label: "Keychain", ok: entry.keychainOK)
            if let message = entry.failureMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    private func row(label: String, ok: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red)
            Text(label).font(.footnote)
        }
    }
}
