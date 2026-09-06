import SparkKit
import SparkUI
import SwiftUI

@MainActor
@Observable
final class ObjectDetailViewModel: ETagDetailMutationHandling {
    let objectId: String
    var state: DetailLoadState<ObjectDetail> = .loading
    var rawPayload: String?
    var etag: String?

    let apiClient: APIClient

    init(objectId: String, apiClient: APIClient) {
        self.objectId = objectId
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let response = try await apiClient.requestWithRawResponse(ObjectsEndpoint.detail(id: objectId))
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

    func attachTag(_ request: TagMutationRequest) async throws {
        guard let etag else { throw TagMutationError.missingETag }
        let response = try await apiClient.requestWithRawResponse(
            TagsEndpoint.attach(kind: .objects, id: objectId, request: request, etag: etag, response: ObjectDetail.self)
        )
        rawPayload = response.utf8Body
        self.etag = response.etag ?? etag
        state = .loaded(response.decoded)
    }

    func detachTag(_ tag: EventTag) async throws {
        guard let tagID = tag.tagID else { throw TagMutationError.missingTagID }
        guard let etag else { throw TagMutationError.missingETag }
        let response = try await apiClient.requestWithRawResponse(
            TagsEndpoint.detach(kind: .objects, id: objectId, tagID: tagID, etag: etag, response: ObjectDetail.self)
        )
        rawPayload = response.utf8Body
        self.etag = response.etag ?? etag
        state = .loaded(response.decoded)
    }

    func createRelationship(_ request: RelationshipCreateRequest) async throws -> EntityRelationship {
        guard let etag else { throw TagMutationError.missingETag }
        let response = try await apiClient.requestWithRawResponse(
            try EntityMutationsEndpoint.createRelationship(kind: .objects, id: objectId, request: request, etag: etag)
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

    func update(_ attributes: [String: AnyCodable]) async throws {
        guard let etag else { throw TagMutationError.missingETag }
        try await applyMutation(
            try EntityMutationsEndpoint.update(kind: .objects, id: objectId, attributes: attributes, etag: etag, response: ObjectDetail.self)
        )
    }

    func geocode(address: String) async throws { try await applyMutation(try EntityMutationsEndpoint.geocode(kind: .objects, id: objectId, address: address, etag: currentETag(), response: ObjectDetail.self)) }
    func setLocation(_ location: LocationRequest) async throws { try await applyMutation(try EntityMutationsEndpoint.setLocation(kind: .objects, id: objectId, location: location, etag: currentETag(), response: ObjectDetail.self)) }
    func clearLocation() async throws { try await applyMutation(EntityMutationsEndpoint.clearLocation(kind: .objects, id: objectId, etag: currentETag(), response: ObjectDetail.self)) }

}

struct ObjectDetailView: View {
    let objectId: String
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: ObjectDetailViewModel?
    @State private var showTagPicker = false
    @State private var tagPendingRemoval: EventTag?
    @State private var tagMutationError: String?
    @State private var showEditor = false
    @State private var showLocationEditor = false

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
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, SparkSpacing.xxl)
            .padding(.bottom, SparkSpacing.xl)
        }
        .sparkAppBackground()
        .navigationTitle("Object")
        .navigationBarTitleDisplayMode(.inline)
        .sparkSubViewToolbar(
            shareItems: objectShareItems,
            rawTitle: "Raw object",
            rawPayload: objectRawPayload,
            feedbackContext: objectFeedbackContext,
            refresh: { await viewModel?.load() }
        )
        .toolbar { ToolbarItemGroup(placement: .topBarTrailing) { Button("Edit") { showEditor = true }.disabled(!isLoaded); Button { showLocationEditor = true } label: { Image(systemName: "mappin.and.ellipse") }.accessibilityLabel("Edit location").disabled(!isLoaded) } }
        .task(id: objectId) {
            if viewModel == nil {
                viewModel = ObjectDetailViewModel(objectId: objectId, apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
        .sheet(isPresented: $showTagPicker) {
            TagPickerSheet { request in
                try await viewModel?.attachTag(request)
            }
        }
        .sheet(isPresented: $showEditor) { if case .loaded(let detail) = viewModel?.state { EntityEditorSheet(title: "Object", initial: ["title": detail.object.title, "type": detail.object.type, "concept": detail.object.concept, "url": detail.object.url ?? ""]) { try await viewModel?.update($0) } } }
        .sheet(isPresented: $showLocationEditor) { LocationEditorSheet(hasLocation: { if case .loaded(let detail) = viewModel?.state { return detail.location != nil }; return false }(), geocode: { try await viewModel?.geocode(address: $0) }, coordinates: { try await viewModel?.setLocation($0) }, clear: { try await viewModel?.clearLocation() }) }
        .confirmationDialog(
            "Remove tag?",
            isPresented: Binding(get: { tagPendingRemoval != nil }, set: { if !$0 { tagPendingRemoval = nil } })
        ) {
            Button("Remove tag", role: .destructive) {
                guard let tag = tagPendingRemoval else { return }
                Task { await detach(tag) }
            }
        } message: {
            Text("This removes the tag from this object.")
        }
        .alert("Couldn't update tags", isPresented: Binding(get: { tagMutationError != nil }, set: { if !$0 { tagMutationError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(tagMutationError ?? "Please try again.")
        }
    }

    private var objectShareItems: [Any] {
        guard case .loaded(let detail) = viewModel?.state else {
            return ["Spark Object: \(objectId)"]
        }
        if let url = detail.object.url.flatMap(URL.init) {
            return [url]
        }
        return ["Spark Object: \(detail.object.title)"]
    }

    private var isLoaded: Bool {
        if case .loaded = viewModel?.state { return true }
        return false
    }

    private var objectRawPayload: String? {
        guard case .loaded(let detail) = viewModel?.state else { return nil }
        if let rawPayload = viewModel?.rawPayload { return rawPayload }
        return SparkPrettyJSON.string(for: detail)
            ?? SparkPrettyJSON.fallback(entity: "object", id: detail.object.id, title: detail.object.title)
    }

    private var objectFeedbackContext: SparkFeedbackContext {
        if case .loaded(let detail) = viewModel?.state {
            return SparkFeedbackContext(
                entityType: "object",
                entityId: detail.object.id,
                title: detail.object.title
            )
        }
        return SparkFeedbackContext(entityType: "object", entityId: objectId, title: objectId)
    }

    @ViewBuilder
    private func content(for detail: ObjectDetail) -> some View {
        heroSection(for: detail)

        if let summary = detail.aiSummary, !summary.isEmpty {
            SparkDetailInsightCard(label: "Insight", text: summary)
        }

        tagSection(for: detail)

        RelationshipsSection(
            kind: .objects,
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

        if !detail.relatedObjects.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkDetailSectionHeader("Related", trailing: "\(detail.relatedObjects.count) objects")
                ForEach(detail.relatedObjects) { rel in
                    relatedObjectRow(rel)
                }
            }
        }

        if !detail.recentEvents.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkDetailSectionHeader("Recent events", trailing: "\(detail.recentEvents.count) events")
                ForEach(detail.recentEvents) { event in
                    NavigationLink {
                        EventDetailView(eventId: event.id)
                    } label: {
                        eventRowSummary(event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func tagSection(for detail: ObjectDetail) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SectionLabel("Tags")
            FlowLayout(spacing: SparkSpacing.xs + 2) {
                ForEach(detail.tags) { tag in
                    NavigationLink(value: DetailRoute.tag(id: tag.tagID, name: tag.name, type: tag.type)) {
                        TagChip(tag)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) { tagPendingRemoval = tag } label: {
                            Label("Remove tag", systemImage: "trash")
                        }
                    }
                }
                Button { showTagPicker = true } label: { TagChip("+", isGhost: true) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add tag")
            }
        }
    }

    private func detach(_ tag: EventTag) async {
        do {
            try await viewModel?.detachTag(tag)
        } catch {
            tagMutationError = (error as? LocalizedError)?.errorDescription ?? "Please try again."
        }
        tagPendingRemoval = nil
    }

    private func heroSection(for detail: ObjectDetail) -> some View {
        SparkDetailHero(
            eyebrow: objectEyebrow(for: detail.object),
            status: detail.object.type.humanisedAction,
            title: detail.object.title,
            subtitle: objectSubtitle(for: detail.object),
            value: nil
        )
    }

    private func objectEyebrow(for object: EventObject) -> String {
        var parts = [
            object.concept.uppercased(),
            object.type.replacingOccurrences(of: "_", with: " ").uppercased()
        ]
        if let time = object.time {
            parts.append(SparkDetailFormatters.shortDate.string(from: time))
            parts.append(SparkDetailFormatters.shortTime.string(from: time))
        }
        return parts.joined(separator: " — ")
    }

    private func objectSubtitle(for object: EventObject) -> String? {
        if let content = object.content, !content.isEmpty {
            return content
        }
        if let url = object.url, let parsed = URL(string: url) {
            return parsed.host ?? url
        }
        return nil
    }

    private func relatedObjectRow(_ rel: ObjectDetail.Related) -> some View {
        SparkDetailLinkedRow(
            title: rel.title,
            subtitle: rel.concept,
            trailing: rel.relationship
        )
    }

    private func eventRowSummary(_ event: Event) -> some View {
        SparkDetailLinkedRow(
            title: eventTitle(for: event),
            subtitle: event.time.map { SparkDetailFormatters.compactDateTime.string(from: $0) },
            trailing: event.displayValue?.sparkPlainTextFromHTMLFragment ?? event.value?.sparkPlainTextFromHTMLFragment,
            tint: Color.domainTint(for: event.domain)
        )
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
