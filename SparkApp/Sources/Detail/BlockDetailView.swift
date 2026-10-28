import SparkKit
import SparkUI
import SwiftUI

@MainActor
@Observable
final class BlockDetailViewModel: ETagDetailMutationHandling {
    let blockId: String
    var state: DetailLoadState<BlockDetail> = .loading
    var rawPayload: String?
    var etag: String?

    let apiClient: APIClient

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
            try EntityMutationsEndpoint.createRelationship(kind: .blocks, id: blockId, request: request, etag: etag)
        )
        try await adoptVersion(after: response.decoded, kind: .blocks, id: blockId)
        return response.decoded
    }

    func deleteRelationship(_ relationship: EntityRelationship) async throws {
        try await deleteRelationship(relationship, kind: .blocks, id: blockId)
    }

    func update(_ attributes: [String: AnyCodable]) async throws {
        guard let etag else { throw TagMutationError.missingETag }
        try await applyMutation(
            try EntityMutationsEndpoint.update(kind: .blocks, id: blockId, attributes: attributes, etag: etag, response: BlockDetail.self)
        )
    }
}

struct BlockDetailView: View {
    let blockId: String
    /// The event the block was opened from. Used for the link back when the
    /// block payload doesn't carry its event.
    var parent: Event?
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: BlockDetailViewModel?
    @State private var showEditor = false
    @State private var relationships = RelationshipsStore()

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
            .padding(.bottom, SparkSpacing.xxl)
        }
        .sparkDetailInlineTitle(inlineTitle)
        .sparkAppBackground()
        .sparkSubViewToolbar(
            shareItems: blockShareItems,
            rawTitle: "Raw block",
            rawPayload: blockRawPayload,
            feedbackContext: blockFeedbackContext,
            refresh: { await viewModel?.load() },
            flintNoteContext: .block(id: blockId, label: flintNoteLabel)
        )
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEditor = true }.disabled(!isLoaded) } }
        .sparkRelationshipsHost(relationships, kind: .blocks, entityID: blockId, apiClient: appModel.apiClient) { request in
            guard let viewModel else { throw TagMutationError.missingETag }
            return try await viewModel.createRelationship(request)
        }
        .task(id: blockId) {
            if viewModel == nil {
                viewModel = BlockDetailViewModel(blockId: blockId, apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
        .sheet(isPresented: $showEditor) { if case .loaded(let detail) = viewModel?.state { EntityEditorSheet(title: "Block", initial: ["title": detail.block.title, "block_type": detail.block.blockType, "value": detail.block.value ?? "", "value_unit": detail.block.unit ?? "", "time": detail.block.time?.ISO8601Format() ?? ""]) { try await viewModel?.update($0) } } }
    }

    private var blockShareItems: [Any] {
        guard case .loaded(let detail) = viewModel?.state else {
            return ["Spark Block: \(blockId)"]
        }
        return ["Spark Block: \(detail.block.title)"]
    }

    private var inlineTitle: String {
        if case .loaded(let detail) = viewModel?.state { return heroTitle(for: detail) }
        return ""
    }

    private var isLoaded: Bool {
        if case .loaded = viewModel?.state { return true }
        return false
    }

    private var flintNoteLabel: String {
        if case .loaded(let detail) = viewModel?.state {
            return detail.block.title
        }
        return "this block"
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

        BlockCard(detail.block, size: .full)

        if let summary = detail.aiSummary, !summary.isEmpty {
            SparkDetailInsightCard(label: "Insight", text: summary)
        }

        referencesSection(for: detail.block)

        if let parent = parentEvent(for: detail) {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkDetailSectionHeader("From event")
                NavigationLink {
                    EventDetailView(eventId: parent.id)
                } label: {
                    SparkDetailLinkedRow(
                        title: parentRowTitle(for: parent),
                        subtitle: parent.time.map { SparkDetailFormatters.compactDateTime.string(from: $0) },
                        trailing: parent.displayValue?.sparkPlainTextFromHTMLFragment ?? parent.value?.sparkPlainTextFromHTMLFragment,
                        tint: Color.domainTint(for: parent.domain),
                        icon: EntityPresentation.icon(domain: parent.domain, service: parent.service, action: parent.action, type: "event")
                    )
                }
                .buttonStyle(.plain)
            }
        }

        if relationships.hasContent {
            RelationshipsSection(
                store: relationships,
                kind: .blocks,
                entityID: detail.id,
                apiClient: appModel.apiClient,
                delete: { relationship in
                    guard let viewModel else { throw TagMutationError.missingETag }
                    try await viewModel.deleteRelationship(relationship)
                }
            )
        }

        SparkDetailAddRow(actions: [
            SparkDetailAddRow.Action(title: "Link", systemImage: "link") { relationships.isAdding = true },
        ])
    }

    private func parentEvent(for detail: BlockDetail) -> Event? {
        detail.event ?? parent
    }

    /// With a parent, the block is named by what it summarises: the eyebrow
    /// says which kind of block it is ("Tweet Summary — 19 Oct 2026"), and
    /// the title is the event's subject ("Jason from 404 Media").
    private func heroSection(for detail: BlockDetail) -> some View {
        let hasSubject = parentSubject(for: detail) != nil
        return SparkDetailHero(
            eyebrow: blockEyebrow(for: detail.block, leadingWithTitle: hasSubject),
            status: nil,
            title: heroTitle(for: detail),
            subtitle: nil,
            value: blockDisplayValue(for: detail.block),
            valueTint: .sparkAccent
        )
    }

    private func heroTitle(for detail: BlockDetail) -> String {
        parentSubject(for: detail) ?? detail.block.title
    }

    private func parentSubject(for detail: BlockDetail) -> String? {
        parentEvent(for: detail).flatMap(subject(of:))
    }

    /// The same rule as the event screen's hero: the target names the event
    /// only when the event displays with its object.
    private func subject(of event: Event) -> String? {
        guard event.displayWithObject,
              let target = event.target?.title.trimmingCharacters(in: .whitespacesAndNewlines),
              !target.isEmpty
        else { return nil }
        return target
    }

    private func parentRowTitle(for event: Event) -> String {
        // When the hero names the subject, the row says what happened.
        subject(of: event) == nil ? eventTitle(for: event) : event.action.sparkSentenceCase
    }

    private func blockEyebrow(for block: Block, leadingWithTitle: Bool) -> String {
        var parts = [leadingWithTitle ? block.title : block.blockType.sparkSentenceCase]
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
