import SparkKit
import SparkUI
import SwiftUI

struct IntegrationDetailView: View {
    let integrationId: String
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: IntegrationDetailViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                switch viewModel?.state {
                case .loaded(let detail):
                    content(for: detail)
                case .error(let msg):
                    EmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Couldn't load",
                        message: msg,
                        actionTitle: "Retry"
                    ) { Task { await viewModel?.load() } }
                default:
                    LoadingShimmerCard()
                    LoadingShimmerCard()
                }
            }
            .padding(SparkSpacing.lg)
        }
        .background(Color.sparkSurface.ignoresSafeArea())
        .navigationTitle(viewModel?.state.loadedTitle ?? "Integration")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: integrationId) {
            if viewModel == nil {
                viewModel = IntegrationDetailViewModel(
                    integrationId: integrationId,
                    apiClient: appModel.apiClient
                )
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(for detail: IntegrationDetail) -> some View {
        heroCard(for: detail)
        actionRow(for: detail)
        if let msg = viewModel?.lastActionMessage {
            Text(msg)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        inspectorRows(for: detail)
        if !detail.recentEvents.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("Recent events")
                ForEach(detail.recentEvents) { event in
                    eventRow(event)
                }
            }
        }
    }

    private func heroCard(for detail: IntegrationDetail) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                HStack(spacing: SparkSpacing.sm) {
                    DomainGlyph(icon: "link", tint: .sparkAccent, size: 28)
                    Text(detail.integration.service.uppercased())
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
                Text(detail.integration.name)
                    .font(SparkFonts.display(.title2, weight: .bold))
                StatusPill(
                    pillTone(for: detail.status),
                    message: detail.status.label,
                    trailing: detail.lastSyncAt.map { Self.relative(from: $0) }
                )
            }
        }
    }

    @ViewBuilder
    private func actionRow(for detail: IntegrationDetail) -> some View {
        HStack(spacing: SparkSpacing.md) {
            Button {
                Task { await viewModel?.syncNow() }
            } label: {
                Label("Sync now", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.sparkAccent)
            .disabled(viewModel?.actionInProgress == .syncing)

            Button {
                guard let anchor = ASPresentationAnchorHandle.current() else { return }
                Task { await viewModel?.reauthorise(presentationAnchor: anchor) }
            } label: {
                Label("Reauthorise", systemImage: "lock.rotation")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.sparkAccent)
            .disabled(detail.oauthStartURL == nil || viewModel?.actionInProgress == .reauthing)
        }
    }

    private func inspectorRows(for detail: IntegrationDetail) -> some View {
        GlassCard(radius: SparkRadii.md, padding: 0) {
            VStack(spacing: 0) {
                InspectorRow("Service", detail.integration.service)
                if let domain = detail.domain {
                    InspectorRow("Domain", domain)
                }
                if let coverage = detail.coveragePercent {
                    InspectorRow("Coverage", "\(Int(coverage * 100))%")
                }
                if let last = detail.lastSyncAt {
                    InspectorRow("Last sync", isMono: true) {
                        Text(Self.fullTimeFormatter.string(from: last))
                    }
                }
                if let instance = detail.integration.instanceType {
                    InspectorRow("Instance", instance)
                }
            }
        }
    }

    private func eventRow(_ event: Event) -> some View {
        GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
            HStack(spacing: SparkSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.action)
                        .font(SparkTypography.bodySmall)
                    if let time = event.time {
                        Text(Self.shortTimeFormatter.string(from: time))
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if let value = event.value {
                    Text(value)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(Color.domainTint(for: event.domain))
                }
            }
        }
    }

    private func pillTone(for status: IntegrationStatus) -> StatusPill.Tone {
        switch status {
        case .upToDate: .ok
        case .syncing: .neutral
        case .needsReauth, .error: .warning
        }
    }

    private static func relative(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()

    private static let fullTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd  HH:mm"
        return f
    }()
}

private extension DetailLoadState where T == IntegrationDetail {
    var loadedTitle: String? {
        if case .loaded(let d) = self { return d.integration.name }
        return nil
    }
}
