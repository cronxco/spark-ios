import SparkKit
import SparkUI
import SwiftUI

struct TagPickerSheet: View {
    let entity: TaggableEntity
    let entityID: String
    let initialTags: [EventTag]
    let onChanged: () -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var tags: [EventTag]
    @State private var suggestions: [Tag] = []
    @State private var query = ""
    @State private var isLoading = false
    @State private var mutatingTagID: String?
    @State private var errorMessage: String?

    init(
        entity: TaggableEntity,
        entityID: String,
        initialTags: [EventTag],
        onChanged: @escaping () -> Void
    ) {
        self.entity = entity
        self.entityID = entityID
        self.initialTags = initialTags
        self.onChanged = onChanged
        _tags = State(initialValue: initialTags)
    }

    var body: some View {
        NavigationStack {
            List {
                if !tags.isEmpty {
                    Section("Current") {
                        ForEach(tags) { tag in
                            HStack {
                                TagChip(tag)
                                Spacer()
                                Button(role: .destructive) {
                                    Task { await remove(tag) }
                                } label: {
                                    if mutatingTagID == tag.id {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "minus.circle.fill")
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(mutatingTagID != nil || tag.serverID == nil)
                                .accessibilityLabel("Remove \(tag.name)")
                            }
                        }
                    }
                }

                Section(query.isEmpty ? "Suggested" : "Matches") {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        ForEach(availableSuggestions) { tag in
                            Button {
                                Task { await add(tag) }
                            } label: {
                                HStack {
                                    TagChip(tag.eventTag)
                                    Spacer()
                                    if mutatingTagID == tag.id {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(Color.sparkAccent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(mutatingTagID != nil)
                        }

                        if canCreate {
                            Button {
                                Task { await createAndAdd() }
                            } label: {
                                Label("Create \"\(trimmedQuery)\"", systemImage: "plus")
                            }
                            .disabled(mutatingTagID != nil)
                        }

                        if availableSuggestions.isEmpty, !canCreate {
                            Text("Type a tag name to search or create one.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Color.sparkError)
                    }
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Find or create a tag")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadSuggestions()
        }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await loadSuggestions()
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var availableSuggestions: [Tag] {
        suggestions.filter { suggestion in
            !tags.contains(where: { $0.serverID == suggestion.id })
        }
    }

    private var canCreate: Bool {
        !trimmedQuery.isEmpty
            && !suggestions.contains(where: {
                $0.name.caseInsensitiveCompare(trimmedQuery) == .orderedSame
            })
    }

    private func loadSuggestions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await appModel.apiClient.request(
                TagsEndpoint.suggest(query: trimmedQuery, limit: 20)
            )
            suggestions = response.data
            errorMessage = nil
        } catch {
            SparkObservability.captureHandled(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't load tags."
        }
    }

    private func add(_ tag: Tag) async {
        await mutate(id: tag.id) {
            try await appModel.apiClient.request(
                TagsEndpoint.add(entity: entity, id: entityID, tagID: tag.id)
            )
        }
    }

    private func createAndAdd() async {
        let name = trimmedQuery
        guard !name.isEmpty else { return }
        await mutate(id: "new:\(name)") {
            try await appModel.apiClient.request(
                TagsEndpoint.createAndAdd(entity: entity, id: entityID, name: name)
            )
        }
        query = ""
        await loadSuggestions()
    }

    private func remove(_ tag: EventTag) async {
        guard let tagID = tag.serverID else { return }
        await mutate(id: tag.id) {
            try await appModel.apiClient.request(
                TagsEndpoint.remove(entity: entity, id: entityID, tagID: tagID)
            )
        }
    }

    private func mutate(
        id: String,
        request: () async throws -> TagMutationResponse
    ) async {
        mutatingTagID = id
        defer { mutatingTagID = nil }
        do {
            let response = try await request()
            tags = response.tags.map(\.eventTag)
            errorMessage = nil
            onChanged()
        } catch {
            SparkObservability.captureHandled(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't update tags."
        }
    }
}
