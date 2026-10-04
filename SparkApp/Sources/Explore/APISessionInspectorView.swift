#if DEBUG
import SparkKit
import SparkUI
import SwiftUI
import UIKit

struct APISessionInspectorView: View {
    @State private var snapshot = APISessionStore.shared.snapshot()
    @State private var endpoint = ""
    @State private var status = ""

    private var filtered: [APISessionStore.Entry] {
        snapshot.entries.filter {
            (endpoint.isEmpty || $0.path.localizedCaseInsensitiveContains(endpoint)) &&
            (status.isEmpty || ($0.status.map(String.init) ?? "").contains(status) || $0.outcome.localizedCaseInsensitiveContains(status))
        }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: SparkSpacing.md) {
            TextField("Filter endpoint", text: $endpoint)
            TextField("Filter status or outcome", text: $status)
            HStack {
                Button("Copy all") { UIPasteboard.general.string = snapshot.export }
                Spacer()
                Button("Clear session") {
                    APISessionStore.shared.clear()
                    snapshot = APISessionStore.shared.snapshot()
                }
            }
            Text("\(snapshot.entries.count) attempts · \(snapshot.evicted) evicted · bodies capped at 2 MB")
                .font(SparkTypography.caption)
            ForEach(filtered) { entry in
                DisclosureGroup {
                    Button("Copy request") { UIPasteboard.general.string = entry.export }
                    Text(entry.export)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                } label: {
                    VStack(alignment: .leading) {
                        Text("\(entry.method) \(entry.path)")
                        Text("\(entry.status.map(String.init) ?? "—") · \(entry.outcome)\(entry.truncated ? " · TRUNCATED" : "")")
                            .foregroundStyle(.secondary)
                    }
                    .font(SparkTypography.caption)
                }
            }
        }
        .task {
            while !Task.isCancelled {
                snapshot = APISessionStore.shared.snapshot()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

struct APISessionSettingsView: View {
    var body: some View {
        ScrollView {
            APISessionInspectorView()
                .padding(SparkSpacing.lg)
        }
        .background(Color.sparkSurface)
        .navigationTitle("API Session")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
