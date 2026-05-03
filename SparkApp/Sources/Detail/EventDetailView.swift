import SparkKit
import SparkUI
import SwiftUI

/// Inspector-style event detail. Mirrors the design's data-led variant —
/// hero card with value + title, then a key/value ledger, glass cards for
/// Actor / Target, linked blocks, and tags.
struct EventDetailView: View {
    let eventId: String
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: EventDetailViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                switch viewModel?.state {
                case .loaded(let detail):
                    content(for: detail)
                case .error(let msg):
                    EmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Couldn't load event",
                        message: msg,
                        actionTitle: "Retry"
                    ) { Task { await viewModel?.retry() } }
                default:
                    LoadingShimmerCard()
                    LoadingShimmerCard()
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.vertical, SparkSpacing.lg)
        }
        .background(Color.sparkSurface.ignoresSafeArea())
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: eventId) {
            if viewModel == nil {
                viewModel = EventDetailViewModel(eventId: eventId, apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(for detail: EventDetail) -> some View {
        heroCard(for: detail)
        inspectorRows(for: detail)

        if let actor = detail.actor {
            actorTargetCard(label: "Actor", entity: actor)
        }
        if let target = detail.target {
            actorTargetCard(label: "Target", entity: target)
        }

        if let summary = detail.aiSummary, !summary.isEmpty {
            aiSummaryCard(summary)
        }

        if !detail.blocks.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("Linked blocks (\(detail.blocks.count))")
                ForEach(detail.blocks) { block in
                    blockRow(block)
                }
            }
        }

        if !detail.tags.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("Tags")
                TagChipRow(detail.tags)
            }
        }

        if !detail.related.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("Recurring at this place")
                ForEach(detail.related) { rel in
                    relatedRow(rel)
                }
            }
        }
    }

    // MARK: - Hero

    private func heroCard(for detail: EventDetail) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                HStack(spacing: SparkSpacing.sm) {
                    Circle()
                        .fill(Color.domainTint(for: detail.event.domain))
                        .frame(width: 6, height: 6)
                    Text(heroBadge(for: detail.event))
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: SparkSpacing.sm)
                    if let time = detail.event.time {
                        Text(Self.shortTimeFormatter.string(from: time))
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.md) {
                    if let value = detail.event.value {
                        Text(value)
                            .font(SparkFonts.display(.title, weight: .bold))
                            .foregroundStyle(Color.domainTint(for: detail.event.domain))
                            .accessibilityLabel("Value \(value)")
                    }
                    if let target = detail.target {
                        Text(target.title)
                            .font(SparkTypography.bodyStrong)
                    }
                }
            }
        }
    }

    private func heroBadge(for event: Event) -> String {
        [event.action, event.domain, event.service]
            .map { $0.uppercased() }
            .joined(separator: " · ")
    }

    // MARK: - Inspector ledger

    private func inspectorRows(for detail: EventDetail) -> some View {
        GlassCard(radius: SparkRadii.md, padding: 0) {
            VStack(spacing: 0) {
                InspectorRow("Action") { Text(detail.event.action) }
                InspectorRow("Domain") { Text(detail.event.domain) }
                InspectorRow("Service") { Text(detail.event.service) }
                if let time = detail.event.time {
                    InspectorRow("When", isMono: true) {
                        Text(Self.fullTimeFormatter.string(from: time))
                    }
                }
                if let url = detail.event.url, let parsed = URL(string: url) {
                    InspectorRow("URL", isMono: true) {
                        Link(parsed.host ?? url, destination: parsed)
                    }
                }
            }
        }
    }

    // MARK: - Actor / Target

    private func actorTargetCard(label: String, entity: EventDetail.ActorTarget) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                SectionLabel(label)
                Text(entity.title)
                    .font(SparkTypography.bodyStrong)
                if let subtitle = entity.subtitle {
                    Text(subtitle)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func aiSummaryCard(_ summary: String) -> some View {
        GlassCard {
            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Color.sparkAccent)
                Text(summary)
                    .font(SparkTypography.bodySmall)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI summary. \(summary)")
    }

    // MARK: - Blocks / related

    private func blockRow(_ block: Block) -> some View {
        GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
            HStack(spacing: SparkSpacing.md) {
                Text(block.blockType.replacingOccurrences(of: "_", with: " "))
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 4))
                Text(block.title)
                    .font(SparkTypography.bodySmall)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let value = block.value {
                    Text(value)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(Color.sparkAccent)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(block.title), \(block.blockType.replacingOccurrences(of: "_", with: " "))")
    }

    private func relatedRow(_ rel: EventDetail.RelatedEvent) -> some View {
        GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
            HStack(spacing: SparkSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rel.title)
                        .font(SparkTypography.bodySmall)
                    if let meta = rel.meta {
                        Text(meta)
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let fullTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd  HH:mm:ss ZZZZZ"
        return f
    }()
}

extension Color {
    /// Map a domain string ("money", "health", …) to its canonical tint.
    /// Falls back to the brand accent for unknown values.
    static func domainTint(for domain: String) -> Color {
        switch domain.lowercased() {
        case "health": .domainHealth
        case "activity": .domainActivity
        case "money": .domainMoney
        case "media": .domainMedia
        case "knowledge": .domainKnowledge
        case "anomaly": .domainAnomaly
        default: .sparkAccent
        }
    }
}
