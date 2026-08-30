import SparkKit
import SparkUI
import SwiftUI

struct IntegrationsListView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: IntegrationsListViewModel?

    var body: some View {
        Group {
            switch viewModel?.state {
            case .loaded(let list):
                if list.isEmpty {
                    EmptyState(
                        systemImage: "link.badge.plus",
                        title: "No integrations",
                        message: "Connect a service from your Spark dashboard to see it here."
                    )
                } else {
                    Form {
                        Section {
                            SparkSystemScreenHeader(
                                title: "Integrations",
                                subtitle: "Connection health and sync controls for Spark sources."
                            )
                            .padding(.vertical, SparkSpacing.sm)
                        }
                        .listRowBackground(Color.clear)

                        ForEach(viewModel?.grouped(list) ?? [], id: \.0) { group in
                            Section {
                                ForEach(group.1) { integration in
                                    NavigationLink {
                                        IntegrationDetailView(integrationId: integration.id)
                                    } label: {
                                        IntegrationRow(integration: integration)
                                    }
                                }
                                #if DEBUG
                                Button(viewModel?.syncingService == group.1.first?.service ? "Syncing all \(group.1.first?.service ?? "")…" : "Sync all \(group.1.first?.service ?? "")") {
                                    guard let service = group.1.first?.service else { return }
                                    Task { await viewModel?.syncAll(service: service) }
                                }
                                .disabled(viewModel?.syncingService != nil || group.1.allSatisfy { $0.statusValue.lowercased() == "paused" })
                                #endif
                            } header: {
                                Text(group.0)
                            }
                        }
                    }
                }
            case .error(let msg):
                EmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load",
                    message: msg,
                    actionTitle: "Retry"
                ) { Task { await viewModel?.load() } }
            default:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = IntegrationsListViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
        .alert("Integration sync", isPresented: Binding(get: { viewModel?.syncMessage != nil }, set: { if !$0 { viewModel?.clearSyncMessage() } })) {
            Button("OK", role: .cancel) { viewModel?.clearSyncMessage() }
        } message: {
            Text(viewModel?.syncMessage ?? "")
        }
    }
}

private struct IntegrationRow: View {
    let integration: Integration

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            DomainGlyph(icon: glyph, tint: tint, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(integration.name)
                    .font(SparkTypography.body)
                if let instance = integration.instanceType {
                    Text(instance)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            statusDot
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .accessibilityLabel(integration.statusValue)
    }

    private var statusColor: Color {
        switch integration.statusValue.lowercased() {
        case "up_to_date", "ok", "active": .sparkSuccess
        case "syncing", "running": .sparkInfo
        case "needs_reauth", "reauth", "expired": .sparkWarning
        case "unknown": .secondary
        default: .sparkError
        }
    }

    private var glyph: String {
        switch integration.service.lowercased() {
        case "apple_health", "fitbit", "oura", "whoop", "garmin", "withings": "heart.fill"
        case "monzo", "starling", "plaid", "amex", "stripe": "creditcard.fill"
        case "spotify", "apple_music", "lastfm", "youtube", "trakt", "letterboxd": "music.note"
        case "readwise", "instapaper", "raindrop", "github", "linear", "notion", "obsidian": "book.fill"
        case "google", "fastmail", "calendar", "gmail", "icloud": "envelope.fill"
        default: "link"
        }
    }

    private var tint: Color {
        switch integration.service.lowercased() {
        case "apple_health", "fitbit", "oura", "whoop", "garmin", "withings": .domainHealth
        case "monzo", "starling", "plaid", "amex", "stripe": .domainMoney
        case "spotify", "apple_music", "lastfm", "youtube", "trakt", "letterboxd": .domainMedia
        case "readwise", "instapaper", "raindrop", "github", "linear", "notion", "obsidian": .domainKnowledge
        default: .sparkAccent
        }
    }
}
