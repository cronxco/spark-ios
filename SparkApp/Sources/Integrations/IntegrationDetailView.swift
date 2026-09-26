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
        .sparkAppBackground()
        .navigationTitle(viewModel?.state.loadedTitle ?? "Integration")
        .navigationBarTitleDisplayMode(.inline)
        .sparkSubViewToolbar(
            shareItems: integrationShareItems,
            rawTitle: "Raw integration",
            rawPayload: integrationRawPayload,
            feedbackContext: integrationFeedbackContext,
            refresh: { await viewModel?.load() }
        )
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

    private var integrationShareItems: [Any] {
        guard case .loaded(let detail) = viewModel?.state else {
            return ["Spark Integration: \(integrationId)"]
        }
        return ["Spark Integration: \(detail.integration.name)"]
    }

    private var integrationRawPayload: String? {
        guard case .loaded(let detail) = viewModel?.state else { return nil }
        if let rawPayload = viewModel?.rawPayload { return rawPayload }
        return SparkPrettyJSON.string(for: detail)
            ?? SparkPrettyJSON.fallback(
                entity: "integration",
                id: detail.integration.id,
                title: detail.integration.name
            )
    }

    private var integrationFeedbackContext: SparkFeedbackContext {
        if case .loaded(let detail) = viewModel?.state {
            return SparkFeedbackContext(
                entityType: "integration",
                entityId: detail.integration.id,
                title: detail.integration.name
            )
        }
        return SparkFeedbackContext(entityType: "integration", entityId: integrationId, title: integrationId)
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
                    DomainGlyph(
                        icon: EntityPresentation.integrationIcon(domain: detail.domain ?? detail.integration.domain),
                        tint: EntityPresentation.tint(domain: detail.domain ?? detail.integration.domain),
                        size: 28
                    )
                    Text(detail.integration.service.sparkSentenceCase)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
                Text(detail.integration.name)
                    .font(SparkFonts.display(.title2, weight: .bold))
                StatusPill(
                    pillTone(for: detail.status),
                    message: detail.status.label,
                    trailing: detail.lastSyncAt.map { SparkRelativeTime.string(for: $0) }
                )
                if let message = detail.statusMessage, !message.isEmpty {
                    Text(message)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func actionRow(for detail: IntegrationDetail) -> some View {
        let isPaused = detail.status == .paused
        VStack(spacing: SparkSpacing.md) {
            HStack(spacing: SparkSpacing.md) {
                if !isPaused {
                    Button {
                        Task { await viewModel?.syncNow() }
                    } label: {
                        Label("Update now", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            // Design system: text on the amber primary fill is
                            // primary-content (slate), never white.
                            .foregroundStyle(Color.slate5)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.sparkAccent)
                    .disabled(viewModel?.actionInProgress != nil || detail.status == .syncing)
                }

                Button {
                    Task { await viewModel?.setPaused(!isPaused) }
                } label: {
                    Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel?.actionInProgress != nil)
            }

            if detail.canReauthorise {
                Button {
                    guard let anchor = ASPresentationAnchorHandle.current() else { return }
                    Task { await viewModel?.reauthorise(presentationAnchor: anchor) }
                } label: {
                    Label("Reauthorise", systemImage: "lock.rotation")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel?.actionInProgress != nil)
            }
        }
    }

    private func inspectorRows(for detail: IntegrationDetail) -> some View {
        GlassCard(radius: SparkRadii.md, padding: 0) {
            VStack(spacing: 0) {
                InspectorRow("Service", detail.integration.service.sparkSentenceCase)
                if let domain = detail.domain {
                    InspectorRow("Domain", domain.sparkSentenceCase)
                }
                if let coverage = detail.coveragePercent {
                    InspectorRow("Coverage", "\(Int(coverage * 100))%")
                }
                if let last = detail.lastSyncAt {
                    InspectorRow("Last sync", isMono: SparkRelativeTime.isAbsolute(last)) {
                        Text(SparkRelativeTime.string(for: last))
                    }
                }
                if let next = detail.integration.nextUpdateAt, detail.status != .paused {
                    InspectorRow(next < .now ? "Was due" : "Next update", isMono: SparkRelativeTime.isAbsolute(next)) {
                        Text(SparkRelativeTime.string(for: next))
                    }
                }
                if let schedule = detail.integration.scheduleSummary {
                    InspectorRow("Schedule", schedule)
                }
                if let instance = detail.integration.instanceType {
                    InspectorRow("Instance", instance.sparkSentenceCase)
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
                        Text(SparkRelativeTime.string(for: time))
                            .font(SparkRelativeTime.isAbsolute(time) ? SparkTypography.monoSmall : SparkTypography.caption)
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
        case .syncing, .paused, .stale, .unknown: .neutral
        case .needsUpdate, .needsReauth, .error: .warning
        }
    }
}

private extension DetailLoadState where T == IntegrationDetail {
    var loadedTitle: String? {
        if case .loaded(let d) = self { return d.integration.name }
        return nil
    }
}
