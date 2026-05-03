#if DEBUG
import SparkKit
import SparkUI
import SwiftUI

struct DebugView: View {
    @Environment(AppModel.self) private var appModel
    @State private var cacheResetConfirm = false
    @State private var statusMessage: String?

    var body: some View {
        List {
            Section("Cache") {
                Button("Reset SwiftData cache") {
                    cacheResetConfirm = true
                }
                .foregroundStyle(Color.sparkError)
                .confirmationDialog(
                    "Reset cache?",
                    isPresented: $cacheResetConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Reset", role: .destructive) { resetCache() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("All locally cached data will be deleted. It will re-sync on next launch.")
                }
            }

            Section("Onboarding") {
                Button("Force re-onboard") {
                    let defaults = UserDefaults(suiteName: "group.co.cronx.spark")
                    defaults?.set(false, forKey: "onboarding.completed")
                    defaults?.removeObject(forKey: "onboarding.lastStep")
                    statusMessage = "Onboarding reset — restart app."
                }
                .foregroundStyle(Color.sparkWarning)
            }

            Section("Logging") {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    Text("OSLog is not queryable in-app without entitlements.")
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                    Text("Open Console.app on Mac and filter by subsystem: co.cronx.spark")
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if let msg = statusMessage {
                Section {
                    Text(msg)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(Color.sparkSuccess)
                }
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func resetCache() {
        Task {
            do {
                let context = appModel.container.mainContext
                try context.delete(model: CachedEvent.self)
                try context.delete(model: CachedObject.self)
                try context.delete(model: CachedBlock.self)
                try context.delete(model: CachedIntegration.self)
                try context.delete(model: CachedPlace.self)
                try context.delete(model: CachedMetric.self)
                try context.delete(model: CachedAnomaly.self)
                try context.delete(model: CachedDaySummary.self)
                try context.delete(model: CachedNotification.self)
                try context.save()
                await appModel.etagCache.clearAll()
                statusMessage = "Cache cleared."
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}
#endif
