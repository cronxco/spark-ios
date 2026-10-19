import SparkKit
import SparkUI
import SwiftUI

/// Relationship state for one entity, owned by its detail screen. The screen
/// shows `RelationshipsSection` only when there is something in it, and offers
/// "add" from its shared Add row, so an empty record no longer carries a
/// "No relationships yet." section.
@MainActor
@Observable
final class RelationshipsStore {
    var relationships = [EntityRelationship]()
    var isLoading = true
    var isMutating = false
    var errorMessage: String?
    var mutationError: String?
    var isAdding = false

    /// Shown once loaded with rows, or when the load failed and can be retried.
    var hasContent: Bool { !isLoading && (errorMessage != nil || !relationships.isEmpty) }

    func load(kind: SparkEntityKind, entityID: String, apiClient: APIClient) async {
        isLoading = true; errorMessage = nil; defer { isLoading = false }
        do { relationships = try await apiClient.request(EntityMutationsEndpoint.relationships(kind: kind, id: entityID)).data }
        catch APIError.notModified { }
        catch { errorMessage = "Couldn't load relationships. Tap to retry." }
    }

    func add(_ request: RelationshipCreateRequest, using create: @MainActor (RelationshipCreateRequest) async throws -> EntityRelationship) async throws {
        isMutating = true; defer { isMutating = false }
        do { relationships.append(try await create(request)) }
        catch { mutationError = (error as? LocalizedError)?.errorDescription ?? "Please try again."; throw error }
    }

    func remove(_ relationship: EntityRelationship, using delete: @MainActor (EntityRelationship) async throws -> Void) async {
        isMutating = true; defer { isMutating = false }
        do { try await delete(relationship); relationships.removeAll { $0.id == relationship.id } }
        catch { mutationError = (error as? LocalizedError)?.errorDescription ?? "Please try again." }
    }
}

/// Loads an entity's relationships and hosts the add sheet. Apply it to the
/// detail screen itself, so both work while the section is hidden.
private struct RelationshipsHostModifier: ViewModifier {
    let store: RelationshipsStore
    let kind: SparkEntityKind
    let entityID: String
    let apiClient: APIClient
    let create: @MainActor (RelationshipCreateRequest) async throws -> EntityRelationship

    func body(content: Content) -> some View {
        @Bindable var store = store
        content
            .task(id: "\(kind.rawValue):\(entityID)") { await self.store.load(kind: kind, entityID: entityID, apiClient: apiClient) }
            .sheet(isPresented: $store.isAdding) {
                RelationshipEditorSheet(sourceKind: kind, sourceID: entityID, apiClient: apiClient) { request in
                    try await self.store.add(request, using: create)
                }
            }
            .alert("Couldn't update relationships", isPresented: Binding(get: { self.store.mutationError != nil }, set: { if !$0 { self.store.mutationError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(self.store.mutationError ?? "Please try again.") }
    }
}

extension View {
    func sparkRelationshipsHost(
        _ store: RelationshipsStore,
        kind: SparkEntityKind,
        entityID: String,
        apiClient: APIClient,
        create: @escaping @MainActor (RelationshipCreateRequest) async throws -> EntityRelationship
    ) -> some View {
        modifier(RelationshipsHostModifier(store: store, kind: kind, entityID: entityID, apiClient: apiClient, create: create))
    }
}

/// Authoritative relationship list for every owned entity detail. Render it
/// only when `store.hasContent`; loading and adding live on the host.
struct RelationshipsSection: View {
    var title = "Relationships"
    let store: RelationshipsStore
    let kind: SparkEntityKind
    let entityID: String
    let apiClient: APIClient
    let delete: @MainActor (EntityRelationship) async throws -> Void

    @State private var pendingDeletion: EntityRelationship?

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SparkDetailSectionHeader(title, trailing: store.relationships.isEmpty ? nil : "\(store.relationships.count)")
            if let errorMessage = store.errorMessage {
                Button { Task { await store.load(kind: kind, entityID: entityID, apiClient: apiClient) } } label: {
                    Label(errorMessage, systemImage: "arrow.clockwise")
                        .font(SparkTypography.bodySmall).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            } else {
                ForEach(store.relationships) { relationship in relationshipRow(relationship) }
            }
        }
        .confirmationDialog("Delete relationship?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
            Button("Delete relationship", role: .destructive) {
                guard let relationship = pendingDeletion else { return }
                Task {
                    await store.remove(relationship, using: delete)
                    pendingDeletion = nil
                }
            }
        } message: { Text("This removes the relationship from both entities.") }
    }

    @ViewBuilder private func relationshipRow(_ relationship: EntityRelationship) -> some View {
        let row = row(relationship).contextMenu {
            Button("Delete relationship", systemImage: "trash", role: .destructive) { pendingDeletion = relationship }
        }
        if let route = route(for: relationship) { NavigationLink(value: route) { row }.buttonStyle(.plain) } else { row }
    }

    private func row(_ relationship: EntityRelationship) -> some View {
        let target = target(for: relationship)
        return SparkDetailLinkedRow(title: relationship.type.replacingOccurrences(of: "_", with: " ").capitalized, subtitle: "\(relationship.fromID == entityID ? "To" : "From") • \(target.type)", trailing: target.id)
    }

    private func target(for relationship: EntityRelationship) -> (type: String, id: String) {
        relationship.toID == entityID ? (relationship.fromType, relationship.fromID) : (relationship.toType, relationship.toID)
    }

    private func route(for relationship: EntityRelationship) -> DetailRoute? {
        let target = target(for: relationship)
        return switch target.type {
        case "event", "events": .event(id: target.id)
        case "object", "objects": .object(id: target.id)
        case "block", "blocks": .block(id: target.id)
        default: nil
        }
    }
}

private struct RelationshipEditorSheet: View {
    let sourceKind: SparkEntityKind
    let sourceID: String
    let apiClient: APIClient
    let save: @MainActor (RelationshipCreateRequest) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel
    @State private var targetKind: SearchEndpoint.EntityType = .objects
    @State private var query = ""
    @State private var results = [SearchResult]()
    @State private var target: SearchResult?
    @State private var relationshipType = "related_to"
    @State private var value = ""
    @State private var valueUnit = ""
    @State private var isSearching = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    /// Types come from the server's registry, so the app never offers one the API rejects.
    @State private var typeOptions = [RelationshipTypeOption]()

    private var pickerTypes: [(type: String, name: String)] {
        typeOptions.isEmpty ? [("related_to", "Related To")] : typeOptions.map { ($0.type, $0.displayName) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Target") {
                    Picker("Kind", selection: $targetKind) { ForEach(SearchEndpoint.EntityType.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                    TextField("Search \(targetKind.rawValue)", text: $query)
                        .textInputAutocapitalization(.never)
                        .task(id: query) {
                            try? await Task.sleep(for: .milliseconds(300))
                            guard !Task.isCancelled else { return }
                            await search(query: query)
                        }
                    if isSearching { ProgressView() }
                    ForEach(results, id: \.id) { result in
                        Button { target = result } label: {
                            HStack { VStack(alignment: .leading) { Text(result.title); if let subtitle = result.subtitle { Text(subtitle).foregroundStyle(.secondary) } }; Spacer(); if target?.id == result.id { Image(systemName: "checkmark") } }
                        }
                    }
                }
                Section("Relationship") {
                    Picker("Type", selection: $relationshipType) { ForEach(pickerTypes, id: \.type) { Text($0.name).tag($0.type) } }
                    TextField("Numeric value (optional)", text: $value).keyboardType(.decimalPad)
                    TextField("Unit (optional)", text: $valueUnit)
                }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .navigationTitle("Add relationship")
            .task { await loadTypes() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { Task { await submit() } }.disabled(target == nil || isSaving) }
            }
        }
    }

    private func loadTypes() async {
        do {
            let options = try await apiClient.request(EntityMutationsEndpoint.relationshipTypes()).data
            typeOptions = options
            if let first = options.first, !options.contains(where: { $0.type == relationshipType }) {
                relationshipType = first.type
            }
        } catch {
            typeOptions = []
        }
    }

    private func search(query: String) async {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { results = []; return }
        isSearching = true; defer { isSearching = false }
        do {
            let response = try await appModel.apiClient.request(SearchEndpoint.entity(targetKind, query: query))
            guard !Task.isCancelled else { return }
            results = response.results.filter {
                switch (targetKind, $0) { case (.events, .event), (.objects, .object), (.blocks, .block): true; default: false }
            }
        } catch { results = [] }
    }

    private func submit() async {
        guard let target else { return }
        let targetID: String
        switch target { case .event(let hit): targetID = hit.id; case .object(let hit): targetID = hit.id; case .block(let hit): targetID = hit.id; default: return }
        guard !(targetKind.rawValue == sourceKind.rawValue && targetID == sourceID) else { errorMessage = "An entity cannot have a relationship with itself."; return }
        let number = value.isEmpty ? nil : Double(value)
        guard value.isEmpty || number != nil else { errorMessage = "The numeric value must be valid."; return }
        isSaving = true; defer { isSaving = false }
        do {
            try await save(RelationshipCreateRequest(toKind: SparkEntityKind(rawValue: targetKind.rawValue) ?? .objects, toID: targetID, type: relationshipType, value: number, valueMultiplier: nil, valueUnit: valueUnit.nilIfEmpty, metadata: nil))
            dismiss()
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't add relationship." }
    }
}

private extension String {
    var nilIfEmpty: String? { let trimmed = trimmingCharacters(in: .whitespacesAndNewlines); return trimmed.isEmpty ? nil : trimmed }
}
