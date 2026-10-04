import SparkKit
import SwiftUI

/// Resolves an existing tag or creates one by name for a detail mutation.
struct TagPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel

    let onSelect: (TagMutationRequest) async throws -> Void

    @State private var query = ""
    @State private var type = ""
    @State private var suggestions: [TagResource] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Find or create") {
                    TextField("Tag name", text: $query)
                        .textInputAutocapitalization(.never)
                    TextField("Type (optional)", text: $type)
                        .textInputAutocapitalization(.never)

                    if canCreate {
                        Button {
                            select(TagMutationRequest(name: trimmedQuery, type: trimmedType))
                        } label: {
                            Label("Add \"\(trimmedQuery)\"", systemImage: "plus")
                        }
                        .disabled(isSaving)
                    }
                }

                if isLoading {
                    Section { HStack { Spacer(); ProgressView(); Spacer() } }
                } else if !suggestions.isEmpty {
                    Section("Suggestions") {
                        ForEach(suggestions) { tag in
                            Button {
                                select(TagMutationRequest(tagID: tag.id))
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tag.name)
                                    if let type = tag.type, !type.isEmpty {
                                        Text(type.replacingOccurrences(of: "_", with: " "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(isSaving)
                        }
                    }
                }
            }
            .overlay {
                if let errorMessage {
                    ContentUnavailableView("Couldn't update tags", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                }
            }
            .navigationTitle("Add tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task(id: query) { await loadSuggestions() }
        }
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedType: String? {
        let value = type.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
    private var canCreate: Bool { !trimmedQuery.isEmpty }

    private func loadSuggestions() async {
        guard !trimmedQuery.isEmpty else { suggestions = []; return }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            suggestions = try await appModel.apiClient.request(TagsEndpoint.suggest(query: trimmedQuery)) .data
        } catch APIError.notModified {
            return
        } catch {
            suggestions = []
        }
    }

    private func select(_ request: TagMutationRequest) {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await onSelect(request)
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Please try again."
            }
            isSaving = false
        }
    }
}
