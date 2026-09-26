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
                            summary(for: list)
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
                                ForEach(Array(Set(group.1.map(\.service))).sorted(), id: \.self) { service in
                                    Button(viewModel?.syncingService == service ? "Syncing all \(service.sparkSentenceCase)…" : "Sync all \(service.sparkSentenceCase)") {
                                        Task { await viewModel?.syncAll(service: service) }
                                    }
                                    .disabled(
                                        viewModel?.syncingService != nil
                                            || group.1.filter { $0.service == service }.allSatisfy { $0.statusKind == .paused }
                                    )
                                }
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
        .refreshable { await viewModel?.load() }
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

    @ViewBuilder
    private func summary(for list: [Integration]) -> some View {
        let attention = viewModel?.attentionCount(list) ?? 0
        if attention > 0 {
            StatusPill(.warning, message: attention == 1 ? "1 integration needs attention" : "\(attention) integrations need attention")
        } else {
            StatusPill(.ok, message: "Everything is up to date")
        }
    }
}

private struct IntegrationRow: View {
    let integration: Integration

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            DomainGlyph(
                icon: EntityPresentation.integrationIcon(domain: integration.domain),
                tint: EntityPresentation.tint(domain: integration.domain),
                size: 30
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(integration.name)
                    .font(SparkTypography.body)
                HStack(spacing: SparkSpacing.xs) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(detailLine)
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(integration.name), \(detailLine)")
    }

    /// Status in words, so colour is never the only signal, plus when it last synced.
    private var detailLine: String {
        let status = integration.statusKind.label
        guard let lastSync = integration.lastSyncAt, integration.statusKind != .stale else { return status }
        return "\(status) · \(SparkRelativeTime.string(for: lastSync))"
    }

    private var statusColor: Color {
        switch integration.statusKind {
        case .upToDate: .sparkSuccess
        case .syncing: .sparkInfo
        case .paused, .stale, .unknown: .secondary
        case .needsUpdate, .needsReauth: .sparkWarning
        case .error: .sparkError
        }
    }
}
