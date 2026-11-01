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
    /// The parent event's other blocks, loaded after the block itself.
    private(set) var siblings: [Block] = []

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

    /// The parent event's other blocks, so the screen can show where this one
    /// sits among them. A failure leaves the section out.
    func loadSiblings(eventID: String) async {
        do {
            let event = try await apiClient.request(EventsEndpoint.detailForWrite(id: eventID))
            siblings = event.blocks.filter { $0.id != blockId }
        } catch APIError.notModified {
            return
        } catch {
            SparkObservability.captureHandled(error)
            siblings = []
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
            flintNoteContext: .block(id: blockId, label: flintNoteLabel),
            edit: SparkSubViewMenuAction(title: "Edit block", isEnabled: isLoaded) { showEditor = true },
            details: blockInfo
        )
        .sparkRelationshipsHost(relationships, kind: .blocks, entityID: blockId, apiClient: appModel.apiClient) { request in
            guard let viewModel else { throw TagMutationError.missingETag }
            return try await viewModel.createRelationship(request)
        }
        .task(id: blockId) {
            if viewModel == nil {
                viewModel = BlockDetailViewModel(blockId: blockId, apiClient: appModel.apiClient)
            }
            await viewModel?.load()
            if case .loaded(let detail) = viewModel?.state, let eventID = parentEvent(for: detail)?.id {
                await viewModel?.loadSiblings(eventID: eventID)
            }
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

    /// Hero, then the block's own content, then where it came from: its
    /// event first, then the event's other blocks (§12.2). A generated block
    /// whose page is its text takes the full-width band (§3.5).
    @ViewBuilder
    private func content(for detail: BlockDetail) -> some View {
        let block = detail.block
        heroSection(for: detail)

        if block.kind.isAIWritten, let text = block.content?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                HStack(spacing: SparkSpacing.xs) {
                    SparkGlyph(.flint, size: 12, relativeTo: .caption)
                    Text("Generated from the \(sourceNoun(for: detail))")
                }
                .font(SparkTypography.captionStrong)
                .foregroundStyle(.secondary)

                SparkLongFormContentView(text: text, paragraphFont: SparkTypography.longFormBody)
            }
            .sparkGeneratedBand()
        } else if !SparkDetailContributorList.isContributor(block) {
            BlockCard(block, size: .full, eventID: detail.event?.id)
        }

        if let summary = detail.aiSummary, !summary.isEmpty {
            SparkDetailSummaryCard(text: summary)
        }

        referencesSection(for: block)

        if let parent = parentEvent(for: detail) {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkDetailSectionHeader("From event", icon: .duration)
                NavigationLink {
                    EventDetailView(eventId: parent.id)
                } label: {
                    SparkDetailLinkedRow(
                        title: parentRowTitle(for: parent),
                        subtitle: parentRowSubtitle(for: parent),
                        trailing: parent.displayValue?.sparkPlainTextFromHTMLFragment ?? parent.value?.sparkPlainTextFromHTMLFragment,
                        tint: Color.domainTint(for: parent.domain),
                        icon: EntityPresentation.icon(domain: parent.domain, service: parent.service, action: parent.action, type: "event")
                    )
                }
                .buttonStyle(.plain)
            }
        }

        siblingsSection(for: detail)

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

    /// The event's other blocks. Contributors stay bars beside a contributor;
    /// anything else is a row.
    @ViewBuilder
    private func siblingsSection(for detail: BlockDetail) -> some View {
        let siblings = viewModel?.siblings ?? []
        if !siblings.isEmpty {
            let parent = parentEvent(for: detail)
            let contributors = siblings.filter(SparkDetailContributorList.isContributor)
            let others = siblings.filter { !SparkDetailContributorList.isContributor($0) }
            let isContributor = SparkDetailContributorList.isContributor(detail.block)

            if !contributors.isEmpty {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    SparkDetailSectionHeader(isContributor ? "Other contributors" : "Contributors", count: contributors.count, icon: .list)
                    SparkDetailContributorList(
                        blocks: contributors,
                        domain: parent?.domain ?? "",
                        threshold: parent?.service.lowercased() == "oura" ? 0.85 : nil,
                        parent: parent
                    )
                }
            }

            if !others.isEmpty {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    SparkDetailSectionHeader(contributors.isEmpty ? "Other blocks" : "Blocks", count: others.count, icon: .list)
                    ForEach(others) { block in
                        NavigationLink {
                            BlockDetailView(blockId: block.id, parent: parent)
                        } label: {
                            BlockCard(block, size: .row)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// "the article" for a saved page, otherwise "the event".
    private func sourceNoun(for detail: BlockDetail) -> String {
        let concept = (parentEvent(for: detail)?.target?.concept ?? "").lowercased()
        return concept == "bookmark" || concept == "article" ? "article" : "event"
    }

    private func parentRowSubtitle(for event: Event) -> String? {
        let time = event.time.map { SparkDetailFormatters.compactDateTime.string(from: $0) }
        let subject = subject(of: event)
        let parts = [subject, time].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private var blockInfo: SparkDetailInfo? {
        guard case .loaded(let detail) = viewModel?.state else { return nil }
        let block = detail.block
        var rows = [
            SparkDetailInfo.Row(key: "Type", value: block.blockType),
        ]
        if let service = parentEvent(for: detail)?.service {
            rows.insert(SparkDetailInfo.Row(key: "Integration", value: service.sparkSentenceCase), at: 0)
        }
        if let time = block.time {
            rows.append(SparkDetailInfo.Row(key: "Recorded", value: SparkDetailDateText.full(time)))
        }
        rows.append(SparkDetailInfo.Row(key: "Block ID", value: block.id, isMono: true, isCopyable: true))
        if let eventID = parentEvent(for: detail)?.id {
            rows.append(SparkDetailInfo.Row(key: "Event ID", value: eventID, isMono: true, isCopyable: true))
        }
        return SparkDetailInfo(rows: rows, openTitle: "Open source", openURL: block.mediaUrl.flatMap(URL.init(string:)))
    }

    private func parentEvent(for detail: BlockDetail) -> Event? {
        detail.event ?? parent
    }

    /// A block with a value is named by itself: "Contributor", then
    /// "Restfulness", then 77 as a ring. A text block is named by what it
    /// summarises: "Key takeaways", then the article's title (§12.2).
    private func heroSection(for detail: BlockDetail) -> some View {
        let block = detail.block
        let parent = parentEvent(for: detail)
        let domain = parent?.domain ?? block.kind.domain ?? ""
        return SparkDetailCentredHero(
            icon: block.kind.systemImage,
            domain: domain,
            verb: heroVerb(for: detail),
            title: heroTitle(for: detail),
            value: heroValue(for: block, service: parent?.service),
            source: parent?.service.sparkSentenceCase,
            time: block.time
        )
    }

    private func heroVerb(for detail: BlockDetail) -> String {
        if hasValue(detail.block) || parentSubject(for: detail) == nil {
            return detail.block.blockType.sparkSentenceCase
        }
        return detail.block.title
    }

    private func heroValue(for block: Block, service: String?) -> SparkDetailHeroValue {
        if let value = block.displayValue, let number = value.number,
           SparkDetailNumber.isScore(value: number, unit: block.unit) || block.kind == .contributor {
            return .score(number, text: value.text, threshold: service?.lowercased() == "oura" ? 0.85 : nil)
        }
        if let text = blockDisplayValue(for: block) {
            return .text(text)
        }
        return .hidden
    }

    private func hasValue(_ block: Block) -> Bool {
        guard let value = block.value?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !value.isEmpty
    }

    private func heroTitle(for detail: BlockDetail) -> String {
        if hasValue(detail.block) { return detail.block.title }
        return parentSubject(for: detail) ?? detail.block.title
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
