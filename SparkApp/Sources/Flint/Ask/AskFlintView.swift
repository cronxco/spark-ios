import SparkKit
import SparkUI
import SwiftUI

/// Ask Flint: a conversation with the user's Spark data. Flint can search it
/// and change it; every change it makes shows here with an Undo.
struct AskFlintView: View {
    let apiClient: APIClient
    /// A question typed into the command line: asked once, as the screen opens.
    var initialQuestion: String?
    /// Opens a record Flint linked to, on the stack that hosts this screen.
    let onOpen: (DetailRoute) -> Void

    @State private var viewModel: AskFlintViewModel?
    @State private var showsHistory = false
    @FocusState private var composerFocused: Bool

    private static let suggestions = [
        "How did I sleep this week?",
        "What did I spend on coffee this month?",
        "Tag yesterday's lunch as work",
    ]

    var body: some View {
        Group {
            if let viewModel {
                thread(viewModel)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sparkAppBackground()
        .navigationTitle("Ask Flint")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("History", systemImage: "clock.arrow.circlepath") { showsHistory = true }
                Button("New conversation", systemImage: "square.and.pencil") {
                    viewModel?.startNewConversation()
                    composerFocused = true
                }
                .disabled(viewModel?.turns.isEmpty ?? true)
            }
        }
        .sheet(isPresented: $showsHistory) {
            if let viewModel {
                AskFlintHistoryView(viewModel: viewModel)
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            if let route = DeepLink.parse(url)?.detailRoute {
                onOpen(route)
                return .handled
            }
            return .systemAction
        })
        .task {
            if viewModel == nil {
                let model = AskFlintViewModel(
                    service: AskFlintAPIService(apiClient: apiClient),
                    localAnswerer: AskFlintLocalAnswerer()
                )
                viewModel = model
                if let initialQuestion { model.ask(initialQuestion) }
            }
        }
    }

    private func thread(_ viewModel: AskFlintViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    if viewModel.turns.isEmpty {
                        introduction(viewModel)
                    }
                    ForEach(viewModel.turns) { turn in
                        AskFlintTurnView(
                            turn: turn,
                            activity: turn.isStreaming ? viewModel.activity : nil,
                            undoingReceiptIDs: viewModel.undoingReceiptIDs,
                            onOpen: onOpen,
                            onUndo: { change in Task { await viewModel.undo(change) } }
                        )
                        .id(turn.id)
                    }
                    if let errorMessage = viewModel.errorMessage, !viewModel.isResponding {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(SparkTypography.caption)
                            .foregroundStyle(Color.sparkError)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Color.clear.frame(height: 1).id(Self.bottomAnchor)
                }
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.top, SparkSpacing.lg)
                .padding(.bottom, SparkSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay {
                if viewModel.isLoadingConversation {
                    ProgressView()
                }
            }
            .onChange(of: viewModel.turns.last?.text) {
                proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
            }
            .onChange(of: viewModel.turns.count) {
                withAnimation(.snappy) { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            composer(viewModel)
        }
    }

    private static let bottomAnchor = "ask-flint-bottom"

    private func introduction(_ viewModel: AskFlintViewModel) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            FlintByline()
            Text("Ask about anything in Spark, or tell me what to change.")
                .font(SparkTypography.titleStrong)
                .fixedSize(horizontal: false, vertical: true)
            Text("Changes apply straight away. Each one shows here with an Undo.")
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                ForEach(Self.suggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.ask(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(SparkTypography.bodySmall)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, SparkSpacing.md)
                            .frame(minHeight: 44)
                            .sparkGlass(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, SparkSpacing.sm)
        }
        .padding(.top, SparkSpacing.xl)
    }

    private func composer(_ viewModel: AskFlintViewModel) -> some View {
        @Bindable var viewModel = viewModel

        return HStack(alignment: .bottom, spacing: SparkSpacing.sm) {
            TextField("Ask Flint", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...5)
                .font(SparkTypography.body)
                .focused($composerFocused)
                .submitLabel(.send)
                .onSubmit { viewModel.send() }
                .padding(.horizontal, SparkSpacing.md)
                .padding(.vertical, SparkSpacing.sm)
                .frame(minHeight: 44)
                .sparkGlass(.roundedRect(SparkRadii.lg))
                .accessibilityLabel("Question for Flint")

            if viewModel.isResponding {
                Button("Stop", systemImage: "stop.fill") { viewModel.stop() }
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
                    .sparkGlass(.circle)
            } else {
                Button("Send", systemImage: "arrow.up") { viewModel.send() }
                    .labelStyle(.iconOnly)
                    .fontWeight(.semibold)
                    .frame(width: 44, height: 44)
                    .sparkGlass(.circle, tint: viewModel.canSend ? .sparkAccent : nil)
                    .disabled(!viewModel.canSend)
            }
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.vertical, SparkSpacing.sm)
    }
}

// MARK: - A turn

private struct AskFlintTurnView: View {
    let turn: AskFlintViewModel.Turn
    let activity: String?
    let undoingReceiptIDs: Set<String>
    let onOpen: (DetailRoute) -> Void
    let onUndo: (FlintAskChange) -> Void

    var body: some View {
        switch turn.role {
        case .user: question
        case .assistant: answer
        }
    }

    private var question: some View {
        HStack {
            Spacer(minLength: SparkSpacing.xxl)
            Text(turn.text)
                .font(SparkTypography.body)
                .padding(.horizontal, SparkSpacing.md)
                .padding(.vertical, SparkSpacing.sm)
                .background(Color.sparkAccent.opacity(0.18), in: RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous))
                .textSelection(.enabled)
        }
        .accessibilityLabel("You asked: \(turn.text)")
    }

    private var answer: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            FlintByline(meta: turn.source == .local ? "On this device" : nil)

            if !turn.text.isEmpty {
                SparkRichContentText(
                    text: FlintAskText.linkified(turn.text),
                    foregroundStyle: turn.failed ? Color.sparkError : .primary
                )
                .textSelection(.enabled)
            }

            if turn.isStreaming {
                HStack(spacing: SparkSpacing.sm) {
                    ProgressView().controlSize(.small)
                    Text(activity ?? (turn.text.isEmpty ? "Thinking" : "Writing"))
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            if turn.source == .local {
                Text("Answered from what this device could read. Flint can't make changes until Spark is reachable.")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(turn.changes) { change in
                AskFlintChangeCard(
                    change: change,
                    isUndoing: change.receiptId.map(undoingReceiptIDs.contains) ?? false,
                    onOpen: onOpen,
                    onUndo: { onUndo(change) }
                )
            }

            if !turn.isStreaming, !turn.references.isEmpty {
                references
            }
        }
        .padding(SparkSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkGeneratedSurface()
    }

    private var references: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SparkSpacing.sm) {
                ForEach(turn.references) { reference in
                    Button {
                        if let route = reference.deepLink?.detailRoute { onOpen(route) }
                    } label: {
                        Label(reference.title, systemImage: AskFlintGlyph.kind(reference.kind))
                            .font(SparkTypography.caption)
                            .lineLimit(1)
                            .padding(.horizontal, SparkSpacing.md)
                            .frame(minHeight: 36)
                            .sparkGlass(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this record")
                }
            }
        }
    }
}

// MARK: - A change

private struct AskFlintChangeCard: View {
    let change: FlintAskChange
    let isUndoing: Bool
    let onOpen: (DetailRoute) -> Void
    let onUndo: () -> Void

    /// Re-evaluated on a timer so the Undo button goes when its window does.
    @State private var now = Date.now

    var body: some View {
        HStack(alignment: .top, spacing: SparkSpacing.md) {
            Image(systemName: AskFlintGlyph.operation(change.operation))
                .font(.body.weight(.semibold))
                .foregroundStyle(change.undo.undone ? Color.secondary : Color.sparkAccent)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                Text(change.title)
                    .font(SparkTypography.bodyStrong)
                    .strikethrough(change.undo.undone)
                    .lineLimit(2)
                Text(change.undo.undone ? "Undone" : change.summary)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: SparkSpacing.sm)

            if isUndoing {
                ProgressView().controlSize(.small).frame(minWidth: 44, minHeight: 44)
            } else if change.canUndo(at: now) {
                Button("Undo", action: onUndo)
                    .font(SparkTypography.captionStrong)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Undo: \(change.summary)")
            }
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkGlass(.roundedRect(SparkRadii.md))
        .contentShape(RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous))
        .onTapGesture {
            // A deleted event has no detail screen until it is restored.
            guard change.operation != "delete" || change.undo.undone else { return }
            if let route = FlintAskReference(kind: change.kind, id: change.entityId, title: change.title).deepLink?.detailRoute {
                onOpen(route)
            }
        }
        .task(id: change.id) {
            // The card may reappear after its Undo ran out while off screen.
            now = .now
            guard let expiresAt = change.undo.expiresAt, expiresAt > .now else { return }
            try? await Task.sleep(for: .seconds(expiresAt.timeIntervalSinceNow + 0.5))
            now = .now
        }
        .accessibilityElement(children: .contain)
    }
}

private enum AskFlintGlyph {
    static func operation(_ operation: String) -> String {
        switch operation {
        case "tag": "tag"
        case "note": "note.text"
        case "link": "link"
        case "delete": "trash"
        case "create": "plus"
        default: "pencil"
        }
    }

    static func kind(_ kind: String) -> String {
        switch kind {
        case "object": "cube"
        case "block": "square.stack"
        default: "calendar"
        }
    }
}

// MARK: - History

private struct AskFlintHistoryView: View {
    let viewModel: AskFlintViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.historyState {
                case .idle, .loading:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                case .error(let message):
                    EmptyState(
                        systemImage: "wifi.exclamationmark",
                        title: "Couldn't load conversations",
                        message: message,
                        actionTitle: "Retry",
                        action: { Task { await viewModel.loadConversations() } }
                    )
                case .loaded where viewModel.conversations.isEmpty:
                    EmptyState(
                        systemImage: "bubble.left.and.bubble.right",
                        title: "No conversations yet",
                        message: "Questions you ask Flint are kept here."
                    )
                case .loaded:
                    List {
                        ForEach(viewModel.conversations) { conversation in
                            Button {
                                Task {
                                    await viewModel.open(conversation)
                                    dismiss()
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                                    Text(conversation.title)
                                        .font(SparkTypography.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    if let updatedAt = conversation.updatedAt {
                                        Text(updatedAt, format: .relative(presentation: .named))
                                            .font(SparkTypography.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    Task { await viewModel.delete(conversation) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task { await viewModel.loadConversations() }
        }
    }
}

// MARK: - Entry

/// The way into Ask Flint from the Command tab: it reads as a question field
/// and opens the conversation, with its history.
struct AskFlintEntry: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SparkSpacing.md) {
                FlintAvatar(size: .md)
                VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                    Text("Ask Flint")
                        .font(SparkTypography.bodyStrong)
                    Text("Questions, changes and past conversations")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: SparkSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.vertical, SparkSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .sparkGlass(.roundedRect(SparkRadii.lg))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Ask a question about your data, or ask Flint to change something")
    }
}
