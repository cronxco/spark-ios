import Observation
import OSLog
import SparkKit
import SparkUI
import SwiftUI

struct FlintNoteContext: Identifiable, Hashable {
    let link: FlintNoteContextLink?
    let label: String?

    var id: String {
        guard let link else { return "generic" }
        return "\(link.type.rawValue):\(link.id)"
    }

    static var generic: Self { .init(link: nil, label: nil) }

    static func event(id: String, label: String) -> Self {
        .init(link: .init(type: .event, id: id), label: label)
    }

    static func digest(id: String, label: String) -> Self {
        .init(link: .init(type: .digest, id: id), label: label)
    }

    static func block(id: String, label: String) -> Self {
        .init(link: .init(type: .block, id: id), label: label)
    }

    static func topic(id: String, label: String) -> Self {
        .init(link: .init(type: .topic, id: id), label: label)
    }
}

@MainActor
@Observable
final class FlintNoteComposerModel {
    static let characterLimit = 10_000

    var body = ""
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?

    private let context: FlintNoteContext
    /// The note currently being sent, kept across a failed attempt so a retry
    /// of the same text reuses its mutation identity. Readable so tests can
    /// assert on that identity: URLSession does not reliably leave a request
    /// body where a `URLProtocol` stub can read it.
    private(set) var pendingRequest: FlintNoteCreateRequest?

    init(context: FlintNoteContext) {
        self.context = context
    }

    var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmit: Bool {
        !trimmedBody.isEmpty && body.count <= Self.characterLimit && !isSubmitting
    }

    var hasDraft: Bool { !body.isEmpty }

    func updateBody(_ value: String) {
        body = String(value.prefix(Self.characterLimit))
        errorMessage = nil
    }

    func submit(using apiClient: APIClient, now: Date = .now) async -> FlintNote? {
        guard canSubmit else { return nil }

        let links = context.link.map { [$0] } ?? []
        if pendingRequest?.body != trimmedBody || pendingRequest?.contextLinks != links {
            pendingRequest = FlintNoteCreateRequest(
                clientMutationID: UUID(),
                authoredAt: now,
                body: trimmedBody,
                contextLinks: links
            )
        }
        guard let pendingRequest else { return nil }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            return try await apiClient.request(FlintEndpoint.createNote(pendingRequest)).data
        } catch where error.isAPICancellation {
            return nil
        } catch {
            SparkObservability.captureHandled(error)
            errorMessage = Self.userFacingError(error)
            return nil
        }
    }

    private static func userFacingError(_ error: Error) -> String {
        if case APIError.httpStatus(403, _, _) = error {
            return "This session cannot save notes to Flint."
        }
        if case APIError.httpStatus(409, _, _) = error {
            return "That note conflicted with an earlier submission. Edit it slightly and try again."
        }
        if case APIError.httpStatus(422, _, _) = error {
            return "Flint could not save that note. Check its contents and try again."
        }
        return (error as? LocalizedError)?.errorDescription ?? "Couldn’t save your note. Please try again."
    }
}

struct FlintNoteComposerView: View {
    let context: FlintNoteContext
    let apiClient: APIClient
    let onSaved: (FlintNote) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model: FlintNoteComposerModel
    @State private var confirmsDiscard = false

    init(
        context: FlintNoteContext,
        apiClient: APIClient,
        onSaved: @escaping (FlintNote) -> Void = { _ in }
    ) {
        self.context = context
        self.apiClient = apiClient
        self.onSaved = onSaved
        self.model = FlintNoteComposerModel(context: context)
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                if let label = context.label {
                    Label("Linked to \(label)", systemImage: "link")
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, SparkSpacing.md)
                        .frame(minHeight: 36)
                        .sparkGlass(.capsule)
                        .accessibilityLabel("Linked to \(label)")
                }

                TextEditor(text: Binding(
                    get: { model.body },
                    set: { model.updateBody($0) }
                ))
                .font(SparkTypography.body)
                .frame(maxWidth: .infinity, minHeight: 220)
                .scrollContentBackground(.hidden)
                .padding(SparkSpacing.sm)
                .sparkGlass(.roundedRect(SparkRadii.md))
                .accessibilityLabel("Note to Flint")

                HStack(alignment: .firstTextBaseline) {
                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .font(SparkTypography.caption)
                            .foregroundStyle(Color.sparkError)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: SparkSpacing.sm)
                    Text("\(model.body.count) / \(FlintNoteComposerModel.characterLimit)")
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)
            }
            .padding(SparkSpacing.lg)
            .background(SparkResolvedAppBackground().ignoresSafeArea())
            .navigationTitle("Note to Flint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            guard let note = await model.submit(using: apiClient) else { return }
                            onSaved(note)
                            dismiss()
                        }
                    } label: {
                        if model.isSubmitting {
                            ProgressView().accessibilityLabel("Saving note")
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!model.canSubmit)
                }
            }
            .confirmationDialog("Discard this note?", isPresented: $confirmsDiscard) {
                Button("Discard Note", role: .destructive) { dismiss() }
                Button("Keep Writing", role: .cancel) {}
            } message: {
                Text("Your draft will not be saved.")
            }
            .interactiveDismissDisabled(model.hasDraft)
        }
    }

    private func cancel() {
        if model.hasDraft {
            confirmsDiscard = true
        } else {
            dismiss()
        }
    }
}

@MainActor
@Observable
final class FlintNotesViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    private(set) var state: LoadState = .idle
    private(set) var notes: [FlintNote] = []
    private(set) var nextCursor: String?
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    private(set) var deletingIDs: Set<String> = []
    var deleteError: String?

    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "FlintNotes")

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        guard state == .idle else { return }
        await refresh()
    }

    func refresh() async {
        if notes.isEmpty { state = .loading }
        do {
            let response = try await apiClient.request(FlintEndpoint.notes())
            notes = response.data
            nextCursor = response.nextCursor
            hasMore = response.hasMore
            state = .loaded
        } catch APIError.notModified {
            state = .loaded
        } catch where error.isAPICancellation {
            state = notes.isEmpty ? .idle : .loaded
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Flint notes load failed: \(String(describing: error))")
            state = notes.isEmpty
                ? .error((error as? LocalizedError)?.errorDescription ?? "Couldn’t load your notes.")
                : .loaded
        }
    }

    func loadMore() async {
        guard hasMore, let nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let response = try await apiClient.request(FlintEndpoint.notes(cursor: nextCursor))
            let existing = Set(notes.map(\.id))
            notes.append(contentsOf: response.data.filter { !existing.contains($0.id) })
            self.nextCursor = response.nextCursor
            hasMore = response.hasMore
        } catch where error.isAPICancellation {
            return
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Flint notes pagination failed: \(String(describing: error))")
        }
    }

    func insert(_ note: FlintNote) {
        notes.removeAll { $0.id == note.id }
        notes.insert(note, at: 0)
        state = .loaded
    }

    @discardableResult
    func delete(_ note: FlintNote) async -> Bool {
        guard !deletingIDs.contains(note.id) else { return false }
        deletingIDs.insert(note.id)
        deleteError = nil
        defer { deletingIDs.remove(note.id) }

        do {
            _ = try await apiClient.request(FlintEndpoint.deleteNote(id: note.id))
            notes.removeAll { $0.id == note.id }
            return true
        } catch where error.isAPICancellation {
            return false
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Flint note deletion failed: \(String(describing: error))")
            deleteError = (error as? LocalizedError)?.errorDescription ?? "Couldn’t delete that note."
            return false
        }
    }
}

struct FlintNotesView: View {
    let apiClient: APIClient
    @State private var viewModel: FlintNotesViewModel?
    @State private var showsComposer = false
    @State private var pendingDeletion: FlintNote?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView("Loading notes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Notes to Flint")
        .navigationBarTitleDisplayMode(.large)
        .sparkAppBackground()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showsComposer = true } label: {
                    Label("New note", systemImage: "square.and.pencil")
                }
            }
        }
        .task {
            if viewModel == nil { viewModel = FlintNotesViewModel(apiClient: apiClient) }
            await viewModel?.load()
        }
        .refreshable { await viewModel?.refresh() }
        .sheet(isPresented: $showsComposer) {
            FlintNoteComposerView(context: .generic, apiClient: apiClient) { note in
                viewModel?.insert(note)
            }
        }
        .confirmationDialog("Delete this note?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("Delete Note", role: .destructive) {
                guard let note = pendingDeletion else { return }
                Task { _ = await viewModel?.delete(note) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the note from Flint.")
        }
        .alert("Couldn’t delete note", isPresented: Binding(
            get: { viewModel?.deleteError != nil },
            set: { if !$0 { viewModel?.deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel?.deleteError ?? "Please try again.")
        }
    }

    @ViewBuilder
    private func content(_ viewModel: FlintNotesViewModel) -> some View {
        switch viewModel.state {
        case .idle where viewModel.notes.isEmpty,
             .loading where viewModel.notes.isEmpty:
            ProgressView("Loading notes…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message) where viewModel.notes.isEmpty:
            EmptyState(
                systemImage: "wifi.exclamationmark",
                title: "Couldn’t load notes",
                message: message,
                actionTitle: "Retry"
            ) { Task { await viewModel.refresh() } }
        default:
            if viewModel.notes.isEmpty {
                EmptyState(
                    systemImage: "square.and.pencil",
                    title: "No notes yet",
                    message: "Leave Flint context it can use in future briefings and conversations.",
                    actionTitle: "Leave a note"
                ) { showsComposer = true }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.notes) { note in
                        NavigationLink {
                            FlintNoteDetailView(note: note, viewModel: viewModel)
                        } label: {
                            FlintNoteRow(note: note)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                pendingDeletion = note
                            }
                        }
                    }

                    if viewModel.isLoadingMore {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .listRowSeparator(.hidden)
                    } else if viewModel.hasMore {
                        Color.clear
                            .frame(height: 1)
                            .onAppear { Task { await viewModel.loadMore() } }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

private struct FlintNoteRow: View {
    let note: FlintNote

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text(note.body)
                .font(SparkTypography.body)
                .foregroundStyle(.primary)
                .lineLimit(3)
            Text(note.authoredAt?.formatted(date: .abbreviated, time: .shortened) ?? note.title)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, SparkSpacing.xs)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}

private struct FlintNoteDetailView: View {
    let note: FlintNote
    let viewModel: FlintNotesViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDeletion = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                Text(note.body)
                    .font(SparkTypography.longFormBody)
                    .textSelection(.enabled)

                if !note.contextLinks.isEmpty {
                    VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                        Text("Linked context")
                            .font(SparkTypography.captionStrong)
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(note.contextLinks) { contextLink($0) }
                    }
                }

                Text(note.authoredAt?.formatted(date: .complete, time: .shortened) ?? note.title)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(SparkSpacing.lg)
        }
        .navigationTitle("Note to Flint")
        .navigationBarTitleDisplayMode(.inline)
        .sparkAppBackground()
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    confirmsDeletion = true
                }
            }
        }
        .confirmationDialog("Delete this note?", isPresented: $confirmsDeletion) {
            Button("Delete Note", role: .destructive) {
                Task {
                    if await viewModel.delete(note) { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the note from Flint.")
        }
    }

    @ViewBuilder
    private func contextLink(_ link: FlintNoteContextLink) -> some View {
        switch link.type {
        case .event:
            NavigationLink(value: DetailRoute.event(id: link.id)) {
                contextLabel("Open linked event", icon: "calendar")
            }
        case .digest:
            NavigationLink(value: FlintRoute.digest(link.id)) {
                contextLabel("Open linked digest", icon: "doc.text")
            }
        case .block:
            NavigationLink(value: DetailRoute.block(id: link.id)) {
                contextLabel("Open linked block", icon: "rectangle.text.page")
            }
        case .topic:
            NavigationLink(value: FlintRoute.thread(link.id)) {
                contextLabel("Open linked Thread", icon: "point.3.connected.trianglepath.dotted")
            }
        case .unknown:
            contextLabel("Linked context unavailable", icon: "link.badge.plus")
                .foregroundStyle(.secondary)
        }
    }

    private func contextLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(SparkTypography.bodyStrong)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}
