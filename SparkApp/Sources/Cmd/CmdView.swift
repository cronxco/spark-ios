import SparkKit
import SparkUI
import SwiftUI

struct CmdView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: CmdViewModel
    @FocusState private var focused: Bool

    init(apiClient: APIClient) {
        _viewModel = State(
            initialValue: CmdViewModel(
                classifier: ServerCmdClassifier(apiClient: apiClient),
                submitter: ServerCmdSubmitter(apiClient: apiClient)
            ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.md) {
                    SparkMainPageHeader(title: "CMD")
                        .padding(.horizontal, SparkSpacing.lg)
                        .padding(.top, SparkSpacing.md)
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
        .sheet(isPresented: $viewModel.isAsking) { askSheet }
        .sheet(item: $viewModel.logPrefill) { prefill in
            LogSheetView(apiClient: appModel.apiClient, prefill: prefill)
        }
        .task {
            consumePendingSearch()
            await viewModel.flushQueue()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.flushQueue() } }
        }
        .onChange(of: appModel.pendingSearchQuery) { _, _ in consumePendingSearch() }
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

                TextField("Log, note, command…", text: $viewModel.input, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit { viewModel.submit() }
                    .textInputAutocapitalization(.sentences)

                intentChip
            }
            .padding(SparkSpacing.md)
            .glassEffect(.regular, in: Capsule())
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.bottom, SparkSpacing.sm)
    }

    @ViewBuilder
    private var intentChip: some View {
        if let intent = viewModel.effectiveIntent {
            Menu {
                ForEach(CmdIntent.allCases, id: \.self) { option in
                    Button {
                        viewModel.choose(option)
                    } label: {
                        Label(option.label, systemImage: option.systemImage)
                    }
                }
            } label: {
                Label(intent.label, systemImage: intent.systemImage)
                    .font(.caption.weight(.semibold))
            }
            .accessibilityLabel("Intent: \(intent.label)")
        }
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

    // MARK: Ask sheet

    /// Low confidence: nothing is written until one of these is tapped.
    private var askSheet: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            Text("Which one?")
                .font(.headline)
            Text(viewModel.classification?.text ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            ForEach(CmdIntent.allCases, id: \.self) { intent in
                Button {
                    viewModel.resolveAsk(intent)
                } label: {
                    Label(intent.label, systemImage: intent.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(SparkSpacing.lg)
        .presentationDetents([.medium])
    }
}

private struct SearchRequest: Identifiable, Equatable {
    let text: String
    var id: String { text }
}
