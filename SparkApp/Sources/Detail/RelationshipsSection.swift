import SparkKit
import SparkUI
import SwiftUI

/// Authoritative relationship list for every owned entity detail.
struct RelationshipsSection: View {
    let kind: SparkEntityKind
    let entityID: String
    let apiClient: APIClient
    let create: @MainActor (RelationshipCreateRequest) async throws -> EntityRelationship
    let delete: @MainActor (String) async throws -> Void

    @State private var relationships = [EntityRelationship]()
    @State private var isLoading = true
    @State private var isMutating = false
    @State private var errorMessage: String?
    @State private var showingAddSheet = false
    @State private var pendingDeletion: EntityRelationship?

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SparkDetailSectionHeader("Relationships", trailing: relationships.isEmpty ? nil : "\(relationships.count)")
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if let errorMessage {
                Button { Task { await load() } } label: {
                    Label(errorMessage, systemImage: "arrow.clockwise")
                        .font(SparkTypography.bodySmall).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            } else if relationships.isEmpty {
                Text("No relationships yet.").font(SparkTypography.bodySmall).foregroundStyle(.secondary)
            } else {
                ForEach(relationships) { relationship in relationshipRow(relationship) }
            }
            Button { showingAddSheet = true } label: {
                Label("Add relationship", systemImage: "link.badge.plus").font(SparkTypography.bodySmall.weight(.medium))
            }.buttonStyle(.borderless).disabled(isLoading || isMutating)
        }
        .task(id: "\(kind.rawValue):\(entityID)") { await load() }
        .sheet(isPresented: $showingAddSheet) {
            RelationshipEditorSheet(sourceKind: kind, sourceID: entityID) { request in try await add(request) }
        }
        .confirmationDialog("Delete relationship?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
            Button("Delete relationship", role: .destructive) {
                guard let relationship = pendingDeletion else { return }
                Task { await remove(relationship) }
            }
        } message: { Text("This removes the relationship from both entities.") }
        .alert("Couldn't update relationships", isPresented: Binding(get: { errorMessage != nil && !isLoading }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "Please try again.") }
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

    private func load() async {
        isLoading = true; errorMessage = nil; defer { isLoading = false }
        do { relationships = try await apiClient.request(EntityMutationsEndpoint.relationships(kind: kind, id: entityID)).data }
        catch APIError.notModified { }
        catch { errorMessage = "Couldn't load relationships. Tap to retry." }
    }

    private func add(_ request: RelationshipCreateRequest) async throws {
        isMutating = true; defer { isMutating = false }
        do { relationships.append(try await create(request)) }
        catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "Please try again."; throw error }
    }

    private func remove(_ relationship: EntityRelationship) async {
        isMutating = true; defer { isMutating = false; pendingDeletion = nil }
        do { try await delete(relationship.id); relationships.removeAll { $0.id == relationship.id } }
        catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "Please try again." }
    }
}

private struct RelationshipEditorSheet: View {
    let sourceKind: SparkEntityKind
    let sourceID: String
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
    private let relationshipTypes = ["related_to", "references", "part_of", "causes", "follows"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Target") {
                    Picker("Kind", selection: $targetKind) { ForEach(SearchEndpoint.EntityType.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                    TextField("Search \(targetKind.rawValue)", text: $query).textInputAutocapitalization(.never).onChange(of: query) { _, _ in Task { await search() } }
                    if isSearching { ProgressView() }
                    ForEach(results, id: \.id) { result in
                        Button { target = result } label: {
                            HStack { VStack(alignment: .leading) { Text(result.title); if let subtitle = result.subtitle { Text(subtitle).foregroundStyle(.secondary) } }; Spacer(); if target?.id == result.id { Image(systemName: "checkmark") } }
                        }
                    }
                }
                Section("Relationship") {
                    Picker("Type", selection: $relationshipType) { ForEach(relationshipTypes, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) } }
                    TextField("Numeric value (optional)", text: $value).keyboardType(.decimalPad)
                    TextField("Unit (optional)", text: $valueUnit)
                }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .navigationTitle("Add relationship")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { Task { await submit() } }.disabled(target == nil || isSaving) }
            }
        }
    }

    private func search() async {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { results = []; return }
        isSearching = true; defer { isSearching = false }
        do {
            let response = try await appModel.apiClient.request(SearchEndpoint.entity(targetKind, query: query))
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
