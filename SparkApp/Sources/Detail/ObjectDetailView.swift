import SparkKit
import SparkUI
import SwiftUI

@MainActor
@Observable
final class ObjectDetailViewModel {
    let objectId: String
    private(set) var state: DetailLoadState<ObjectDetail> = .loading

    private let apiClient: APIClient

    init(objectId: String, apiClient: APIClient) {
        self.objectId = objectId
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let detail = try await apiClient.request(ObjectsEndpoint.detail(id: objectId))
            state = .loaded(detail)
        } catch APIError.notModified {
            return
        } catch {
            SparkObservability.captureHandled(error)
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            state = .error(msg)
        }
    }
}

struct ObjectDetailView: View {
    let objectId: String
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: ObjectDetailViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                switch viewModel?.state {
                case .loaded(let detail):
                    content(for: detail)
                case .error(let msg):
                    EmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Couldn't load object",
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
        .navigationTitle("Object")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: objectId) {
            if viewModel == nil {
                viewModel = ObjectDetailViewModel(objectId: objectId, apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(for detail: ObjectDetail) -> some View {
        heroCard(for: detail)

        if let summary = detail.aiSummary, !summary.isEmpty {
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
        }

        GlassCard(radius: SparkRadii.md, padding: 0) {
            VStack(spacing: 0) {
                InspectorRow("Concept") { Text(detail.object.concept) }
                InspectorRow("Type") { Text(detail.object.type) }
                if let url = detail.object.url, let parsed = URL(string: url) {
                    InspectorRow("URL", isMono: true) {
                        Link(parsed.host ?? url, destination: parsed)
                    }
                }
                if let time = detail.object.time {
                    InspectorRow("Created", isMono: true) {
                        Text(Self.fullTimeFormatter.string(from: time))
                    }
                }
            }
        }

        if !detail.tags.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("Tags")
                TagChipRow(detail.tags)
            }
        }

        if !detail.relatedObjects.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("Related")
                ForEach(detail.relatedObjects) { rel in
                    relatedObjectRow(rel)
                }
            }
        }

        if !detail.recentEvents.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("Recent events")
                ForEach(detail.recentEvents) { event in
                    eventRowSummary(event)
                }
            }
        }
    }

    private func heroCard(for detail: ObjectDetail) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                HStack(spacing: SparkSpacing.sm) {
                    DomainGlyph(icon: "shippingbox", tint: .sparkAccent, size: 28)
                    Text(detail.object.concept.uppercased())
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
                Text(detail.object.title)
                    .font(SparkFonts.display(.title2, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                if let content = detail.object.content {
                    Text(content)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func relatedObjectRow(_ rel: ObjectDetail.Related) -> some View {
        GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
            HStack {
                Text(rel.title)
                    .font(SparkTypography.bodySmall)
                Spacer(minLength: 0)
                Text(rel.relationship ?? rel.concept)
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func eventRowSummary(_ event: Event) -> some View {
        GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
            HStack {
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
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()

    private static let fullTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd  HH:mm:ss"
        return f
    }()
}
