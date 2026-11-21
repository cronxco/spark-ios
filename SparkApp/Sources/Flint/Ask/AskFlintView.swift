import SparkKit
import SparkUI
import SwiftUI

/// One Chat conversation with Flint, pushed full screen from the Chat home.
/// Flint can search the user's Spark data and change it; every change it
/// makes shows here with an Undo.
struct AskFlintView: View {
    let apiClient: APIClient
    /// A past conversation to show and carry on. Nil starts a new one.
    var conversation: FlintAskConversation?
    /// The line typed on the Chat home: asked once, as the screen opens.
    var initialQuestion: String?
    /// Opens a record Flint linked to, on the stack that hosts this screen.
    let onOpen: (DetailRoute) -> Void

    @State private var viewModel: AskFlintViewModel?
    /// The question last asked here, held at the top of the screen.
    @State private var pinnedQuestionID: String?
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
        .navigationTitle(conversation?.title ?? "New chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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
                if let conversation {
                    await model.open(conversation)
                } else if let initialQuestion {
                    model.ask(initialQuestion)
                } else {
                    composerFocused = true
                }
            }
        }
    }

    private func thread(_ viewModel: AskFlintViewModel) -> some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                        if viewModel.turns.isEmpty, !viewModel.isLoadingConversation {
                            introduction(viewModel)
                        }
                        ForEach(viewModel.turns) { turn in
                            ChatTurnView(
                                turn: turn,
                                isLatest: turn.id == viewModel.turns.last?.id,
                                activity: turn.isStreaming ? viewModel.activity : nil,
                                undoingReceiptIDs: viewModel.undoingReceiptIDs,
                                onOpen: onOpen,
                                onUndo: { change in Task { await viewModel.undo(change) } },
                                onFollowUp: { question in viewModel.ask(question) }
                            )
                            .id(turn.id)
                        }
                        if let errorMessage = viewModel.errorMessage, !viewModel.isResponding {
                            Label(errorMessage, systemImage: "exclamationmark.triangle")
                                .font(SparkTypography.caption)
                                .foregroundStyle(Color.sparkError)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        // Room under a new question, so it can sit at the top
                        // while its answer is written below it.
                        if pinnedQuestionID != nil {
                            Color.clear.frame(height: max(0, viewport.size.height * 0.6))
                        }
                        Color.clear.frame(height: 1).id(Self.bottomAnchor)
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, SparkSpacing.lg)
                    .padding(.vertical, SparkSpacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)
                .overlay {
                    if viewModel.isLoadingConversation {
                        ProgressView()
                    }
                }
                .onChange(of: viewModel.turns.count) {
                    // A question just asked moves to the top; the answer
                    // grows under it without pulling the page along.
                    guard let question = viewModel.turns.last(where: { $0.role == .user }),
                        viewModel.turns.last?.isStreaming == true
                    else { return }
                    pinnedQuestionID = question.id
                    withAnimation(.snappy) { proxy.scrollTo(question.id, anchor: .top) }
                }
                .onChange(of: viewModel.isLoadingConversation) { _, isLoading in
                    guard !isLoading else { return }
                    proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
                }
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

// MARK: - A change

struct AskFlintChangeCard: View {
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

enum AskFlintGlyph {
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
