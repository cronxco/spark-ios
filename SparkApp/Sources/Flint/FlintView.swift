import SparkUI
import SwiftUI

struct FlintView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: FlintViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SparkSpacing.lg) {
                    SparkMainPageHeader(
                        title: "Flint",
                        subtitle: "Daily guidance from your connected signals"
                    )

                    GlassCard(tint: .sparkAccent.opacity(0.08)) {
                        VStack(alignment: .leading, spacing: SparkSpacing.md) {
                            GlassCardHeader(
                                icon: "sparkles",
                                tint: .sparkAccent,
                                title: "Daily Briefing"
                            )
                            briefingStatus
                            briefingContent
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
                .padding(.top, SparkSpacing.md)
                .padding(.bottom, SparkSpacing.xl)
            }
            .refreshable { await viewModel?.refresh() }
            .sparkMainNavigationTitle("Flint")
            .sparkAppBackground()
            .sparkMainAppToolbar()
        }
        .task {
            if viewModel == nil {
                viewModel = FlintViewModel(
                    apiClient: appModel.apiClient,
                    container: appModel.container
                )
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private var briefingStatus: some View {
        if let viewModel {
            switch viewModel.state {
            case .idle, .loading:
                StatusPill(.neutral, message: "Loading today's briefing")
            case .loaded:
                StatusPill(
                    viewModel.usedAppleIntelligence ? .ok : .neutral,
                    message: viewModel.generationStatusMessage,
                    trailing: viewModel.usedAppleIntelligence ? "On device" : "Fallback"
                )
            case .error:
                StatusPill(.warning, message: "Briefing unavailable")
            }
        } else {
            StatusPill(.neutral, message: "Loading today's briefing")
        }
    }

    @ViewBuilder
    private var briefingContent: some View {
        if let note = viewModel?.note {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    Text(note.title)
                        .font(SparkTypography.title)
                        .foregroundStyle(.primary)
                    Text(note.summary)
                        .font(SparkTypography.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                noteSection(title: "Highlights", systemImage: "sparkles", items: note.highlights)
                noteSection(title: "Watchouts", systemImage: "exclamationmark.triangle.fill", items: note.watchouts)
                noteSection(title: "Actions", systemImage: "checkmark.circle.fill", items: note.suggestedActions)
            }
        } else if case .error(let message) = viewModel?.state {
            EmptyState(
                systemImage: "wifi.exclamationmark",
                title: "Couldn't load your briefing",
                message: message
            )
        } else {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                LoadingShimmer(cornerRadius: SparkRadii.sm)
                    .frame(height: 18)
                    .frame(maxWidth: 180)
                LoadingShimmer(cornerRadius: SparkRadii.sm)
                    .frame(height: 72)
                LoadingShimmer(cornerRadius: SparkRadii.sm)
                    .frame(height: 18)
                    .frame(maxWidth: 260)
            }
            .accessibilityLabel("Loading daily briefing")
        }
    }

    @ViewBuilder
    private func noteSection(title: String, systemImage: String, items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                Label(title, systemImage: systemImage)
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: SparkSpacing.sm) {
                            Circle()
                                .fill(Color.sparkAccent.opacity(0.8))
                                .frame(width: 5, height: 5)
                                .padding(.top, 8)
                            Text(item)
                                .font(SparkTypography.bodySmall)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
