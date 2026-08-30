import SparkKit
import SparkUI
import SwiftUI

@MainActor
@Observable
final class BlockDetailViewModel {
    let blockId: String
    private(set) var state: DetailLoadState<BlockDetail> = .loading
    private(set) var rawPayload: String?
    private var etag: String?

    private let apiClient: APIClient

    init(blockId: String, apiClient: APIClient) {
        self.blockId = blockId
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let response = try await apiClient.requestWithRawResponse(BlocksEndpoint.detail(id: blockId))
            rawPayload = response.utf8Body
            etag = response.etag
            state = .loaded(response.decoded)
        } catch APIError.notModified {
            return
        } catch {
            SparkObservability.captureHandled(error)
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            state = .error(msg)
        }
    }

    func createRelationship(_ request: RelationshipCreateRequest) async throws -> EntityRelationship {
        guard let etag else { throw TagMutationError.missingETag }
        let response = try await apiClient.requestWithRawResponse(
            EntityMutationsEndpoint.createRelationship(kind: .blocks, id: blockId, request: request, etag: etag)
        )
        self.etag = response.etag ?? etag
        return response.decoded
    }

    func deleteRelationship(_ relationshipID: String) async throws {
        guard let etag else { throw TagMutationError.missingETag }
        let response = try await apiClient.requestWithRawResponse(
            EntityMutationsEndpoint.deleteRelationship(id: relationshipID, etag: etag)
        )
        self.etag = response.etag ?? etag
    }
}

struct BlockDetailView: View {
    let blockId: String
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: BlockDetailViewModel?

    @ViewBuilder
    private func referencesSection(for block: Block) -> some View {
        EntityReferenceLinkRow(label: "References", references: block.references ?? [])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                switch viewModel?.state {
                case .loaded(let detail):
                    content(for: detail)
                case .error(let msg):
                    EmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Couldn't load block",
                        message: msg,
                        actionTitle: "Retry"
                    ) { Task { await viewModel?.load() } }
                default:
                    LoadingShimmerCard()
                    LoadingShimmerCard()
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, SparkSpacing.xxl)
            .padding(.bottom, SparkSpacing.xl)
        }
        .sparkAppBackground()
        .navigationTitle("Block")
        .navigationBarTitleDisplayMode(.inline)
        .sparkSubViewToolbar(
            shareItems: blockShareItems,
            rawTitle: "Raw block",
            rawPayload: blockRawPayload,
            feedbackContext: blockFeedbackContext,
            refresh: { await viewModel?.load() }
        )
        .task(id: blockId) {
            if viewModel == nil {
                viewModel = BlockDetailViewModel(blockId: blockId, apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    private var blockShareItems: [Any] {
        guard case .loaded(let detail) = viewModel?.state else {
            return ["Spark Block: \(blockId)"]
        }
        return ["Spark Block: \(detail.block.title)"]
    }

    private var blockRawPayload: String? {
        guard case .loaded(let detail) = viewModel?.state else { return nil }
        if let rawPayload = viewModel?.rawPayload { return rawPayload }
        return SparkPrettyJSON.string(for: detail)
            ?? SparkPrettyJSON.fallback(entity: "block", id: detail.block.id, title: detail.block.title)
    }

    private var blockFeedbackContext: SparkFeedbackContext {
        if case .loaded(let detail) = viewModel?.state {
            return SparkFeedbackContext(
                entityType: "block",
                entityId: detail.block.id,
                title: detail.block.title
            )
        }
        return SparkFeedbackContext(entityType: "block", entityId: blockId, title: blockId)
    }

    @ViewBuilder
    private func content(for detail: BlockDetail) -> some View {
        heroSection(for: detail)

        if let body = detail.block.content, !body.isEmpty {
            GlassCard(radius: SparkRadii.lg, padding: SparkSpacing.lg) {
                SparkRichContentText(text: body, font: SparkTypography.body, foregroundStyle: .primary)
            }
        }

        referencesSection(for: detail.block)

        RelationshipsSection(
            kind: .blocks,
            entityID: detail.id,
            apiClient: appModel.apiClient,
            create: { request in
                guard let viewModel else { throw TagMutationError.missingETag }
                return try await viewModel.createRelationship(request)
            },
            delete: { relationshipID in
                guard let viewModel else { throw TagMutationError.missingETag }
                try await viewModel.deleteRelationship(relationshipID)
            }
        )

        if let summary = detail.aiSummary, !summary.isEmpty {
            SparkDetailInsightCard(label: "Insight", text: summary)
        }

        if let parent = detail.event {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkDetailSectionHeader("From event")
                NavigationLink {
                    EventDetailView(eventId: parent.id)
                } label: {
                    SparkDetailLinkedRow(
                        title: eventTitle(for: parent),
                        subtitle: parent.time.map { SparkDetailFormatters.compactDateTime.string(from: $0) },
                        trailing: parent.displayValue?.sparkPlainTextFromHTMLFragment ?? parent.value?.sparkPlainTextFromHTMLFragment,
                        tint: Color.domainTint(for: parent.domain)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func heroSection(for detail: BlockDetail) -> some View {
        SparkDetailHero(
            eyebrow: blockEyebrow(for: detail.block),
            status: detail.event?.action.humanisedAction,
            title: detail.block.title,
            subtitle: detail.event?.time.map { "From event on \(SparkDetailFormatters.compactDateTime.string(from: $0))" },
            value: blockDisplayValue(for: detail.block),
            valueTint: .sparkAccent
        )
    }

    private func blockEyebrow(for block: Block) -> String {
        var parts = [block.blockType.replacingOccurrences(of: "_", with: " ").uppercased()]
        if let time = block.time {
            parts.append(SparkDetailFormatters.shortDate.string(from: time))
            parts.append(SparkDetailFormatters.shortTime.string(from: time))
        }
        return parts.joined(separator: " — ")
    }

    private func blockDisplayValue(for block: Block) -> String? {
        guard let value = block.value?.sparkPlainTextFromHTMLFragment, !value.isEmpty else { return nil }
        guard let unit = block.unit, !unit.isEmpty else { return value }
        if value.localizedCaseInsensitiveContains(unit) {
            return value
        }
        return "\(value) \(unit)"
    }

    private func eventTitle(for event: Event) -> String {
        let action = event.action.sparkActionTitle
        guard event.displayWithObject,
              let target = event.target?.title.trimmingCharacters(in: .whitespacesAndNewlines),
              !target.isEmpty
        else {
            return action
        }
        return "\(action) \(target)"
    }
}
