import SparkKit
import SparkUI
import SwiftUI

/// Where a Chat home row or a typed line leads.
enum ChatRoute: Hashable {
    /// A past conversation, carried on where it left off.
    case conversation(FlintAskConversation)
    /// A new conversation that opens by asking `question`. The id keeps two
    /// asks of the same line apart.
    case new(id: UUID, question: String)
}

/// The Chat tab: the conversations with Flint, grouped by day, the lines
/// logged from here, and one line to type into. A line is routed as it
/// always was: a log opens the Log sheet, "show money" goes to that screen,
/// and anything else starts a new conversation.
struct ChatHomeView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var input: CmdViewModel
    @State private var home: ChatHomeModel
    @State private var path = NavigationPath()
    @FocusState private var focused: Bool

    init(apiClient: APIClient) {
        _input = State(initialValue: CmdViewModel(submitter: ServerCmdSubmitter(apiClient: apiClient)))
        _home = State(initialValue: ChatHomeModel(service: AskFlintAPIService(apiClient: apiClient)))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    SparkMainPageHeader(title: "Chat")
                        .padding(.top, SparkSpacing.md)
                    searchField
                    conversationsContent
                    loggedSection
                }
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.bottom, SparkSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await home.load() }
            .sparkAppBackground()
            .safeAreaInset(edge: .bottom, spacing: 0) { inputBar }
            .sparkMainAppToolbar()
            .navigationDestination(for: ChatRoute.self) { route in
                conversationScreen(route)
            }
            .sparkDetailDestinations()
        }
        .sparkOpensDetailRoutes(on: $path)
        .sheet(item: searchBinding) { query in
            SearchView(initialQuery: query.text)
        }
        .sheet(item: $input.logPrefill) { prefill in
            LogSheetView(
                apiClient: appModel.apiClient,
                prefill: prefill,
                onQueue: { request in input.queueLog(request, text: prefill.text) },
                onLogged: { events in input.logged(events, text: prefill.text) }
            )
        }
        .task(id: home.trimmedSearch) {
            // Typing narrows the list once the typing pauses.
            if !home.trimmedSearch.isEmpty {
                guard (try? await Task.sleep(for: .milliseconds(300))) != nil else { return }
            }
            await home.load()
        }
        .task {
            consumePendingSearch()
            await input.flushQueue()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await input.flushQueue() } }
        }
        .onChange(of: path.isEmpty) { _, isHome in
            // Back on the home: the conversation just left has moved up.
            if isHome { Task { await home.load() } }
        }
        .onChange(of: appModel.pendingSearchQuery) { _, _ in consumePendingSearch() }
        .onChange(of: input.pendingAsk) { _, question in
            guard let question else { return }
            input.pendingAsk = nil
            focused = false
            path.append(ChatRoute.new(id: UUID(), question: question))
        }
        .onChange(of: input.pendingNavigation) { _, destination in
            guard let destination else { return }
            input.pendingNavigation = nil
            appModel.pendingDestination = destination
        }
    }

    private func conversationScreen(_ route: ChatRoute) -> some View {
        let onOpen: (DetailRoute) -> Void = { path.append($0) }
        return Group {
            switch route {
            case .conversation(let conversation):
                AskFlintView(apiClient: appModel.apiClient, conversation: conversation, onOpen: onOpen)
            case .new(_, let question):
                AskFlintView(apiClient: appModel.apiClient, initialQuestion: question, onOpen: onOpen)
            }
        }
    }

    /// Siri and Spotlight hand a query over through `pendingSearchQuery`.
    private func consumePendingSearch() {
        guard let query = appModel.pendingSearchQuery else { return }
        appModel.pendingSearchQuery = nil
        input.openSearch(query)
    }

    private var searchBinding: Binding<SearchRequest?> {
        Binding(
            get: { input.searchQuery.map(SearchRequest.init(text:)) },
            set: { if $0 == nil { input.searchQuery = nil } }
        )
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: SparkSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search conversations", text: $home.search)
                .font(SparkTypography.body)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
            if !home.search.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") { home.search = "" }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, SparkSpacing.md)
        .frame(minHeight: 44)
        .sparkGlass(.capsule)
    }

    // MARK: - Conversations

    @ViewBuilder
    private var conversationsContent: some View {
        switch home.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        case .failed(let message):
            EmptyState(
                systemImage: "wifi.exclamationmark",
                title: "Couldn't load conversations",
                message: message,
                actionTitle: "Retry",
                action: { Task { await home.load() } }
            )
        case .loaded where home.conversations.isEmpty:
            emptyConversations
        case .loaded:
            if let deleteError = home.deleteError {
                Label(deleteError, systemImage: "exclamationmark.triangle")
                    .font(SparkTypography.caption)
                    .foregroundStyle(Color.sparkError)
            }
            ForEach(home.sections) { section in
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    SectionLabel(section.title)
                    VStack(spacing: 0) {
                        ForEach(Array(section.conversations.enumerated()), id: \.element.id) { index, conversation in
                            if index > 0 { Divider().padding(.leading, SparkSpacing.lg) }
                            ChatConversationRow(conversation: conversation) {
                                path.append(ChatRoute.conversation(conversation))
                            }
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    Task { await home.delete(conversation) }
                                }
                            }
                        }
                    }
                    .background(Color.sparkSurface, in: .rect(cornerRadius: SparkRadii.lg))
                }
            }
        }
    }

    @ViewBuilder
    private var emptyConversations: some View {
        if home.trimmedSearch.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                FlintByline()
                Text("Ask about anything in Spark, or tell Flint what to change. Your conversations are kept here.")
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, SparkSpacing.md)
        } else {
            Text("No conversations match “\(home.trimmedSearch)”.")
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.secondary)
                .padding(.vertical, SparkSpacing.md)
        }
    }

    // MARK: - Logged

    @ViewBuilder
    private var loggedSection: some View {
        let logged = input.loggedRecents
        if home.trimmedSearch.isEmpty, !logged.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("Logged")
                VStack(spacing: 0) {
                    ForEach(Array(logged.enumerated()), id: \.element.at) { index, item in
                        if index > 0 { Divider().padding(.leading, SparkSpacing.lg) }
                        ChatLoggedRow(item: item) {
                            if let id = item.eventId, let route = DeepLink.event(id: id).detailRoute {
                                path.append(route)
                            } else {
                                input.useRecent(item)
                                focused = true
                            }
                        }
                    }
                }
                .background(Color.sparkSurface, in: .rect(cornerRadius: SparkRadii.lg))
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: SparkSpacing.sm) {
            if let receipt = input.receipt { receiptRow(receipt) }
            if input.queuedCount > 0 {
                Text("\(input.queuedCount) queued")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: SparkSpacing.sm) {
                Button {
                    input.openSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search Spark")

                TextField("Ask Flint, log it, or go to…", text: $input.input, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit { _ = input.submit() }
                    .onChange(of: input.input) { old, _ in input.inputChanged(from: old) }
                    .textInputAutocapitalization(.sentences)

                if input.isRouting {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Working out where that goes")
                }
            }
            .padding(SparkSpacing.md)
            .glassEffect(.regular, in: Capsule())
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.bottom, SparkSpacing.sm)
    }

    private func receiptRow(_ receipt: CmdViewModel.Receipt) -> some View {
        HStack {
            Text(receipt.summary)
            Spacer()
            if receipt.pendingConfirmation != nil {
                Button("Confirm") { input.confirmPending() }
            }
            if receipt.undoToken != nil {
                Button("Undo") { input.undo() }
            }
            Button {
                input.dismissReceipt()
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

// MARK: - Rows

/// One conversation: what was asked, how the latest answer opens, the
/// domains it touched, the changes Flint made, and when.
private struct ChatConversationRow: View {
    let conversation: FlintAskConversation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                    Text(conversation.title)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: SparkSpacing.sm)
                    if let date = conversation.updatedAt ?? conversation.createdAt {
                        Text(ChatHomeModel.time(date))
                            .font(SparkTypography.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                if let preview = conversation.preview, !preview.isEmpty {
                    Text(preview)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                if !conversation.domains.isEmpty || conversation.changeCount > 0 {
                    HStack(spacing: SparkSpacing.sm) {
                        ForEach(conversation.domains, id: \.self) { domain in
                            SparkGlyph(.domain(domain), size: 12, relativeTo: .caption)
                                .foregroundStyle(EntityPresentation.tint(domain: domain))
                        }
                        if conversation.changeCount > 0 {
                            Text(conversation.changeCount == 1 ? "1 change" : "\(conversation.changeCount) changes")
                                .font(SparkTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.vertical, SparkSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the conversation")
    }
}

/// A line logged from Chat. It opens the event it wrote, or, before the
/// server has written it, puts the line back in the field.
private struct ChatLoggedRow: View {
    let item: CmdRecentStore.Item
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SparkSpacing.md) {
                SparkGlyph(.edit, size: 14, relativeTo: .body)
                    .foregroundStyle(.secondary)
                Text(item.text)
                    .font(SparkTypography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: SparkSpacing.sm)
                Text(ChatHomeModel.time(item.at))
                    .font(SparkTypography.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, SparkSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(item.eventId == nil ? "Puts the line back in the field" : "Opens what was logged")
    }
}

private struct SearchRequest: Identifiable, Equatable {
    let text: String
    var id: String { text }
}
