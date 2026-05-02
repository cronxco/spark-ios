import SparkUI
import SwiftUI

struct FlintView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SparkSpacing.lg) {
                    GlassCard(tint: .sparkAccent.opacity(0.08)) {
                        VStack(alignment: .leading, spacing: SparkSpacing.md) {
                            GlassCardHeader(
                                icon: "sparkles",
                                tint: .sparkAccent,
                                title: "Daily Briefing"
                            )
                            StatusPill(.ok, message: "Ready when your data syncs", trailing: "Phase 3")
                            EmptyState(
                                systemImage: "text.bubble",
                                title: "Your briefing will appear here",
                                message: "Flint reads your day — sleep, activity, calendar, spend — and surfaces what matters most."
                            )
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: SparkSpacing.md) {
                            GlassCardHeader(
                                icon: "bubble.left.and.bubble.right.fill",
                                tint: .sparkAccent,
                                title: "Ask Flint"
                            )
                            HStack(spacing: SparkSpacing.md) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                Text("Ask anything about your day…")
                                    .font(SparkTypography.body)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(SparkSpacing.md)
                            .sparkGlass(.roundedRect(SparkRadii.md))
                            .opacity(0.5)

                            Text("Conversational AI advisor — coming in Phase 3.")
                                .font(SparkTypography.bodySmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.vertical, SparkSpacing.xl)
            }
            .navigationTitle("Flint")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
