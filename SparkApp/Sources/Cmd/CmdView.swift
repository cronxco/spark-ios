import SparkKit
import SparkUI
import SwiftUI

struct CmdView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: CmdViewModel
    @State private var chat: FlintChatRequest?
    @FocusState private var focused: Bool

    init(apiClient: APIClient) {
        _viewModel = State(initialValue: CmdViewModel(submitter: ServerCmdSubmitter(apiClient: apiClient)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.md) {
                    SparkMainPageHeader(title: "Command")
                        .padding(.horizontal, SparkSpacing.lg)
                        .padding(.top, SparkSpacing.md)
                    AskFlintEntry { chat = FlintChatRequest(question: nil) }
                        .padding(.horizontal, SparkSpacing.lg)
                    recentsList
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable { viewModel.openSearch() }
            .sparkAppBackground()
            .safeAreaInset(edge: .bottom, spacing: 0) { inputBar }
            .sparkMainAppToolbar()
        }
        .sheet(item: searchBinding) { query in
            SearchView(initialQuery: query.text)
        }
        .sheet(item: $chat) { request in
            FlintChatSheet(apiClient: appModel.apiClient, question: request.question)
        }
        .sheet(item: $viewModel.logPrefill) { prefill in
            LogSheetView(apiClient: appModel.apiClient, prefill: prefill) { request in
                viewModel.queueLog(request, text: prefill.text)
            }
        }
        .task {
            consumePendingSearch()
            await viewModel.flushQueue()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.flushQueue() } }
        }
        .onChange(of: appModel.pendingSearchQuery) { _, _ in consumePendingSearch() }
        .onChange(of: viewModel.pendingAsk) { _, question in
            guard let question else { return }
            viewModel.pendingAsk = nil
            focused = false
            chat = FlintChatRequest(question: question)
        }
        .onChange(of: viewModel.pendingNavigation) { _, destination in
            guard let destination else { return }
            viewModel.pendingNavigation = nil
            appModel.pendingDestination = destination
        }
    }

    /// Siri and Spotlight hand a query over through `pendingSearchQuery`.
    private func consumePendingSearch() {
        guard let query = appModel.pendingSearchQuery else { return }
        appModel.pendingSearchQuery = nil
        viewModel.openSearch(query)
    }

    private var searchBinding: Binding<SearchRequest?> {
        Binding(
            get: { viewModel.searchQuery.map(SearchRequest.init(text:)) },
            set: { if $0 == nil { viewModel.searchQuery = nil } }
        )
    }

    // MARK: Recents

    @ViewBuilder
    private var recentsList: some View {
        if viewModel.recents.isEmpty {
            Text("Type a line. Enter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, SparkSpacing.lg)
        } else {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                Text("Recent")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(viewModel.recents, id: \.at) { item in
                    Button {
                        viewModel.useRecent(item)
                        focused = true
                    } label: {
                        Label(item.text, systemImage: item.intent.systemImage)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
        }
    }

    // MARK: Input bar

    private var inputBar: some View {
        VStack(spacing: SparkSpacing.sm) {
            if let receipt = viewModel.receipt { receiptRow(receipt) }
            if viewModel.queuedCount > 0 {
                Text("\(viewModel.queuedCount) queued")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: SparkSpacing.sm) {
                Button {
                    viewModel.openSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search")

                TextField("Log it, go to, or ask Flint…", text: $viewModel.input, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit { _ = viewModel.submit() }
                    .onChange(of: viewModel.input) { old, _ in viewModel.inputChanged(from: old) }
                    .textInputAutocapitalization(.sentences)

                if viewModel.isRouting {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Working out where that goes")
                }
            }
            .padding(SparkSpacing.md)
            .glassEffect(.regular, in: Capsule())
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.bottom, SparkSpacing.sm)
    }

    private func receiptRow(_ receipt: CmdViewModel.Receipt) -> some View {
        HStack {
            Text(receipt.summary)
            Spacer()
            if receipt.pendingConfirmation != nil {
                Button("Confirm") { viewModel.confirmPending() }
            }
            if receipt.undoToken != nil {
                Button("Undo") { viewModel.undo() }
            }
            Button {
                viewModel.dismissReceipt()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Dismiss")
        }
        .font(.footnote)
        .padding(SparkSpacing.md)
        .glassEffect(.regular, in: Capsule())
    }
}

/// One opening of the Flint chat from Command: on a line that was routed to
/// Flint, or empty from the Ask Flint row.
private struct FlintChatRequest: Identifiable {
    let id = UUID()
    let question: String?
}

/// The Flint conversation as a sheet over Command, on its own stack so the
/// records Flint links to open inside it.
private struct FlintChatSheet: View {
    let apiClient: APIClient
    let question: String?

    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            AskFlintView(apiClient: apiClient, initialQuestion: question) { path.append($0) }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .sparkDetailDestinations()
        }
        .sparkOpensDetailRoutes(on: $path)
    }
}

private struct SearchRequest: Identifiable, Equatable {
    let text: String
    var id: String { text }
}
