import SparkKit
import SparkUI
import SwiftUI

struct FlintView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.tabAccessoryCoordinator) private var tabAccessoryCoordinator
    @State private var viewModel: FlintViewModel?
    @State private var path = NavigationPath()
    @State private var noteComposerContext: FlintNoteContext?

    var body: some View {
        NavigationStack(path: $path) {
            page
                .navigationTitle("Flint")
                .navigationBarTitleDisplayMode(.large)
                .sparkAppBackground()
                .sparkMainAppToolbar()
                .sparkDetailDestinations()
                .navigationDestination(for: FlintRoute.self, destination: destination)
                .environment(\.openURL, OpenURLAction { url in
                    if let route = DeepLink.parse(url)?.detailRoute {
                        path.append(route)
                        return .handled
                    }
                    return .systemAction
                })
                .onAppear { tabAccessoryCoordinator?.clear(owner: .flint) }
        }
        .task {
            if viewModel == nil {
                viewModel = FlintViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
        .sheet(item: $noteComposerContext) { context in
            FlintNoteComposerView(context: context, apiClient: appModel.apiClient)
        }
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                if let viewModel {
                    sectionPicker(viewModel)
                    content(viewModel)
                } else {
                    loadingContent
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, SparkSpacing.sm)
            .padding(.bottom, SparkSpacing.xxl * 2)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await refresh() }
    }

    @ViewBuilder
    private func sectionPicker(_ viewModel: FlintViewModel) -> some View {
        @Bindable var viewModel = viewModel

        if dynamicTypeSize.isAccessibilitySize {
            Menu {
                Picker("Flint section", selection: $viewModel.selectedTab) {
                    ForEach(FlintViewModel.FlintTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
            } label: {
                Label(viewModel.selectedTab.title, systemImage: "chevron.up.chevron.down")
                    .font(SparkTypography.bodyStrong)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Flint section")
            .accessibilityValue(viewModel.selectedTab.title)
            .onChange(of: viewModel.selectedTab) { _, tab in sectionChanged(to: tab, viewModel: viewModel) }
        } else {
            Picker("Flint section", selection: $viewModel.selectedTab) {
                ForEach(FlintViewModel.FlintTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Flint section")
            .onChange(of: viewModel.selectedTab) { _, tab in sectionChanged(to: tab, viewModel: viewModel) }
        }
    }

    private func sectionChanged(to tab: FlintViewModel.FlintTab, viewModel: FlintViewModel) {
        Task {
            switch tab {
            case .overview, .threads:
                await viewModel.loadTopicsIfNeeded()
            case .questions:
                await viewModel.loadQuestionsIfNeeded()
            case .history:
                await viewModel.loadHistoryIfNeeded()
            }
        }
    }

    private func refresh() async {
        guard let viewModel else { return }
        switch viewModel.selectedTab {
        case .overview:
            await viewModel.refresh()
        case .questions:
            await viewModel.loadQuestions()
        case .threads:
            await viewModel.loadTopics()
        case .history:
            await viewModel.loadHistory()
        }
    }

    @ViewBuilder
    private func content(_ viewModel: FlintViewModel) -> some View {
        switch viewModel.selectedTab {
        case .overview: overview(viewModel)
        case .questions: questions(viewModel)
        case .threads: threads(viewModel)
        case .history: history(viewModel)
        }
    }

    @ViewBuilder
    private func overview(_ viewModel: FlintViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingContent
        case .empty(let message):
            EmptyState(systemImage: "sparkles", title: "Nothing new yet", message: message)
        case .error(let message):
            errorContent(message) { Task { await viewModel.refresh() } }
        case .loaded:
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                overviewSection("Notes to Flint") {
                    FlintNotesOverviewSurface(
                        onCompose: { noteComposerContext = .generic },
                        onViewNotes: { path.append(FlintRoute.notes) }
                    )
                }

                if let focus = viewModel.topics.first(where: { $0.status?.isActive == true }) {
                    overviewSection("Current focus") {
                        NavigationLink(value: FlintRoute.thread(focus.id)) { FlintFocusSurface(topic: focus) }
                            .buttonStyle(.plain)
                    }
                }

                if let insight = leadingInsight(in: viewModel.digests.first) {
                    overviewSection("What Flint noticed") {
                        FlintBlockSurface(block: insight, viewModel: viewModel, onOpen: push)
                    }
                }

                if let question = viewModel.openQuestions.first {
                    overviewSection("A question for you") {
                        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                            Text(questionContext(question.question))
                                .font(SparkTypography.caption)
                                .foregroundStyle(.secondary)
                            FlintBlockSurface(
                                block: question.block,
                                question: question.question,
                                viewModel: viewModel,
                                onOpen: push
                            )
                        }
                    }
                }

                overviewSection("Latest digests") {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.digests.prefix(3).enumerated()), id: \.element.id) { index, digest in
                            FlintDigestLink(digest: digest)
                            if index < min(viewModel.digests.count, 3) - 1 { Divider() }
                        }
                    }
                    .sparkFlintMaterialSurface()
                }
            }
        }
    }

    private func leadingInsight(in digest: FlintDigest?) -> FlintDigestBlock? {
        digest?.blocks.first {
            !$0.isQuestion
                && !["flint_editorial_note", "flint_day_context", "flint_news", "flint_reading_pick", "flint_reading_drop"].contains($0.blockType)
        }
    }

    private func overviewSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            FlintSectionHeader(title)
            content()
        }
    }

    @ViewBuilder
    private func questions(_ viewModel: FlintViewModel) -> some View {
        switch viewModel.questionsState {
        case .idle where viewModel.openQuestions.isEmpty,
             .loading where viewModel.openQuestions.isEmpty:
            loadingContent.task { await viewModel.loadQuestionsIfNeeded() }
        default:
            if viewModel.openQuestions.isEmpty {
                EmptyState(
                    systemImage: "checkmark.circle",
                    title: "No open questions",
                    message: "Flint will ask here when there is one clear thing worth clarifying."
                )
            } else {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    ForEach(viewModel.openQuestions) { question in
                        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                            Text(questionContext(question.question))
                                .font(SparkTypography.caption)
                                .foregroundStyle(.secondary)
                            FlintBlockSurface(
                                block: question.block,
                                question: question.question,
                                viewModel: viewModel,
                                onOpen: push
                            )
                        }
                    }
                }
            }
        }
    }

    private func questionContext(_ question: FlintQuestion) -> String {
        [question.sourceDigest.period?.displayName, question.askedAt?.formatted(date: .abbreviated, time: .shortened)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    @ViewBuilder
    private func threads(_ viewModel: FlintViewModel) -> some View {
        switch viewModel.topicsState {
        case .idle, .loading:
            loadingContent
        case .empty(let message):
            EmptyState(systemImage: "point.3.connected.trianglepath.dotted", title: "No Threads yet", message: message)
        case .error(let message):
            errorContent(message) { Task { await viewModel.loadTopics() } }
        case .loaded:
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                threadGroup("Active", topics: viewModel.topics.filter { $0.status?.isActive == true })
                threadGroup("Other threads", topics: viewModel.topics.filter { $0.status?.isActive != true })
            }
        }
    }

    @ViewBuilder
    private func threadGroup(_ title: String, topics: [FlintTopic]) -> some View {
        if !topics.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                FlintSectionHeader(title)
                VStack(spacing: 0) {
                    ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                        NavigationLink(value: FlintRoute.thread(topic.id)) { FlintTopicRow(topic: topic) }
                            .buttonStyle(.plain)
                        if index < topics.count - 1 { Divider() }
                    }
                }
                .sparkFlintMaterialSurface()
            }
        }
    }

    @ViewBuilder
    private func history(_ viewModel: FlintViewModel) -> some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: SparkSpacing.lg) {
            DisclosureGroup("Filter by date") {
                DatePicker(
                    "History date",
                    selection: Binding(
                        get: { viewModel.historyFilterDate ?? .now },
                        set: { viewModel.historyFilterDate = $0 }
                    ),
                    in: Calendar.current.date(byAdding: .day, value: -29, to: .now)! ... Date.now,
                    displayedComponents: .date
                )
                Button("Show all 30 days") { viewModel.historyFilterDate = nil }
                    .frame(minHeight: 44)
            }
            .font(SparkTypography.bodyStrong)
            .padding(SparkSpacing.md)
            .sparkFlintMaterialSurface()

            switch viewModel.historyState {
            case .idle, .loading:
                loadingContent.task { await viewModel.loadHistoryIfNeeded() }
            case .empty(let message):
                EmptyState(systemImage: "calendar", title: "No recent history", message: message)
            case .error(let message):
                errorContent(message) { Task { await viewModel.loadHistory() } }
            case .loaded:
                let groups = historyGroups(viewModel)
                if groups.isEmpty {
                    EmptyState(systemImage: "calendar", title: "Nothing that day", message: "Choose another date or show all 30 days.")
                } else {
                    ForEach(groups, id: \.date) { group in
                        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                            Text(group.label)
                                .font(SparkTypography.title)
                                .accessibilityAddTraits(.isHeader)
                            VStack(spacing: 0) {
                                ForEach(Array(group.digests.enumerated()), id: \.element.id) { index, digest in
                                    FlintDigestLink(summary: digest)
                                    if index < group.digests.count - 1 { Divider() }
                                }
                            }
                            .sparkFlintMaterialSurface()
                        }
                    }
                }
            }
        }
    }

    private func historyGroups(_ viewModel: FlintViewModel) -> [FlintHistoryGroup] {
        let filtered = viewModel.historyDigests.filter { digest in
            guard let filter = viewModel.historyFilterDate else { return true }
            return digest.localDate == FlintViewModel.isoKey(for: filter)
        }
        return Dictionary(grouping: filtered, by: \.localDate)
            .map { FlintHistoryGroup(date: $0.key, digests: $0.value) }
            .sorted { $0.date > $1.date }
    }

    @ViewBuilder
    private func destination(_ route: FlintRoute) -> some View {
        if let viewModel {
            switch route {
            case .thread(let id):
                FlintThreadDestination(id: id, viewModel: viewModel)
            case .digest(let id):
                FlintDigestDestination(id: id, viewModel: viewModel, onOpen: push)
            case .notes:
                FlintNotesView(apiClient: appModel.apiClient)
            }
        }
    }

    private func push(_ route: DetailRoute) { path.append(route) }

    private func errorContent(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: SparkSpacing.md) {
            EmptyState(systemImage: "wifi.exclamationmark", title: "Couldn't load Flint", message: message)
            PillButton("Retry", systemImage: "arrow.clockwise", tint: .sparkAccent, action: retry)
        }
    }

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            LoadingShimmer(cornerRadius: SparkRadii.sm).frame(height: 18).frame(maxWidth: 220)
            LoadingShimmer(cornerRadius: SparkRadii.sm).frame(height: 84)
            LoadingShimmer(cornerRadius: SparkRadii.sm).frame(height: 18).frame(maxWidth: 280)
        }
        .padding(SparkSpacing.md)
        .sparkFlintMaterialSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading Flint")
    }
}

enum FlintRoute: Hashable {
    case thread(String)
    case digest(String)
    case notes
}

private struct FlintNotesOverviewSurface: View {
    let onCompose: () -> Void
    let onViewNotes: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            Text("Give Flint context it can remember and use later.")
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.secondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: SparkSpacing.sm) { actions }
                VStack(alignment: .leading, spacing: SparkSpacing.sm) { actions }
            }
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkFlintMaterialSurface()
    }

    @ViewBuilder
    private var actions: some View {
        Button(action: onCompose) {
            Label("Leave a note", systemImage: "square.and.pencil")
                .frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.sparkAccent)

        Button(action: onViewNotes) {
            Label("View notes", systemImage: "note.text")
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
    }
}

private struct FlintHistoryGroup {
    let date: String
    let digests: [FlintDigestSummary]

    var label: String {
        guard let parsed = Self.formatter.date(from: date) else { return date }
        if Calendar.current.isDateInToday(parsed) { return "Today" }
        if Calendar.current.isDateInYesterday(parsed) { return "Yesterday" }
        return parsed.formatted(date: .complete, time: .omitted)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension View {
    func sparkFlintMaterialSurface() -> some View {
        background(.thinMaterial, in: RoundedRectangle(cornerRadius: SparkRadii.lg))
            .overlay {
                RoundedRectangle(cornerRadius: SparkRadii.lg)
                    .strokeBorder(Color.primary.opacity(0.10))
            }
            .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
    }
}

private struct FlintSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(SparkTypography.captionStrong)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct FlintFocusSurface: View {
    let topic: FlintTopic

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(topic.title).font(SparkTypography.bodyStrong).foregroundStyle(.primary)
                Spacer(minLength: SparkSpacing.sm)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            if let content = topic.content, !content.isEmpty {
                Text(content).font(SparkTypography.bodySmall).foregroundStyle(.secondary).lineLimit(3)
            }
            Text(topic.lastTouchedAt?.formatted(.relative(presentation: .named)) ?? "Recently active")
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkFlintMaterialSurface()
    }
}

private struct FlintDigestLink: View {
    let id: String
    let title: String
    let summary: String?
    let period: FlintDigestPeriod?
    let generatedAt: Date?
    let unansweredQuestionCount: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(digest: FlintDigest) {
        id = digest.id
        title = digest.title
        summary = digest.summary
        period = digest.period
        generatedAt = digest.createdAt
        unansweredQuestionCount = digest.unansweredQuestionCount ?? 0
    }

    init(summary: FlintDigestSummary) {
        id = summary.id
        title = summary.title
        self.summary = summary.summary
        period = summary.period
        generatedAt = summary.generatedAt
        unansweredQuestionCount = summary.unansweredQuestionCount
    }

    var body: some View {
        NavigationLink(value: FlintRoute.digest(id)) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: SparkSpacing.xs) { digestText; metadata }
                } else {
                    HStack(alignment: .top, spacing: SparkSpacing.md) { digestText; Spacer(minLength: SparkSpacing.sm); metadata }
                }
            }
            .padding(SparkSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var digestText: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text(displayTitle).font(SparkTypography.bodyStrong).foregroundStyle(.primary)
            if let lede {
                Text(lede).font(SparkTypography.bodySmall).foregroundStyle(.secondary).lineLimit(2)
            }
        }
    }

    private var metadata: some View {
        HStack(spacing: SparkSpacing.sm) {
            if unansweredQuestionCount > 0 {
                Label("\(unansweredQuestionCount) open", systemImage: "questionmark.circle.fill").foregroundStyle(Color.sparkWarning)
            }
            Text(generatedAt?.formatted(date: .omitted, time: .shortened) ?? "")
            Image(systemName: "chevron.right")
        }
        .font(SparkTypography.caption)
        .foregroundStyle(.secondary)
    }

    private var displayTitle: String {
        guard let period else { return title }
        let generatedPrefix = "\(period.displayName) Digest"
        guard title.hasPrefix(generatedPrefix) else { return title }
        let suffix = title.dropFirst(generatedPrefix.count)
        return [" — ", " – ", " - "].contains(where: { suffix.hasPrefix($0) }) ? generatedPrefix : title
    }

    private var lede: String? {
        summary?
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("#") }
    }
}

private struct FlintTopicRow: View {
    let topic: FlintTopic
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) { title; status }
            } else {
                HStack(alignment: .top, spacing: SparkSpacing.md) { title; Spacer(minLength: SparkSpacing.sm); status }
            }
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text(topic.title).font(SparkTypography.bodyStrong).foregroundStyle(.primary)
            if let content = topic.content, !content.isEmpty {
                Text(content).font(SparkTypography.bodySmall).foregroundStyle(.secondary).lineLimit(2)
            }
        }
    }

    private var status: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: SparkSpacing.xs) {
            Label(topic.status?.displayName ?? "Unknown", systemImage: topic.status?.icon ?? "questionmark.circle")
                .font(SparkTypography.captionStrong)
            if let touched = topic.lastTouchedAt {
                Text(touched.formatted(.relative(presentation: .named))).font(SparkTypography.caption)
            }
            Image(systemName: "chevron.right").font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

private struct FlintThreadDestination: View {
    let id: String
    let viewModel: FlintViewModel

    var body: some View {
        Group {
            if let topic = viewModel.topicDetails[id] {
                FlintThreadDetailView(topic: topic)
            } else if let state = viewModel.topicDetailState[id], case .error(let message) = state {
                EmptyState(systemImage: "exclamationmark.triangle", title: "Thread unavailable", message: message)
            } else {
                ProgressView("Loading thread…")
            }
        }
        .task(id: id) { await viewModel.loadTopicDetail(id: id) }
    }
}

private struct FlintThreadDetailView: View {
    let topic: FlintTopic
    @Environment(AppModel.self) private var appModel
    @State private var showsNoteComposer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                Label(topic.status?.displayName ?? "Unknown status", systemImage: topic.status?.icon ?? "questionmark.circle")
                    .font(SparkTypography.bodyStrong)

                if let content = topic.content, !content.isEmpty {
                    SparkLongFormContentView(text: content, paragraphFont: SparkTypography.longFormBody)
                }

                ViewThatFits(in: .horizontal) {
                    HStack { dateFact("First seen", topic.firstSeenAt); Spacer(); dateFact("Last discussed", topic.lastTouchedAt) }
                    VStack(alignment: .leading) { dateFact("First seen", topic.firstSeenAt); dateFact("Last discussed", topic.lastTouchedAt) }
                }

                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    FlintSectionHeader("Discussed in")
                    if topic.mentions?.isEmpty != false {
                        Text("No source mentions are available for this thread.")
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(topic.mentions ?? []) { mention in
                            mentionRow(mention)
                        }
                    }
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(SparkSpacing.lg)
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .sparkAppBackground()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showsNoteComposer = true } label: {
                    Label("Note to Flint", systemImage: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showsNoteComposer) {
            FlintNoteComposerView(
                context: .topic(id: topic.id, label: topic.title),
                apiClient: appModel.apiClient
            )
        }
    }

    private func dateFact(_ label: String, _ date: Date?) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text(label).font(SparkTypography.caption).foregroundStyle(.secondary)
            Text(date?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown").font(SparkTypography.bodyStrong)
        }
    }

    @ViewBuilder
    private func mentionRow(_ mention: FlintTopicMention) -> some View {
        let label = VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text(mention.title).font(SparkTypography.bodyStrong)
            if let excerpt = mention.excerpt, !excerpt.isEmpty {
                Text(excerpt).font(SparkTypography.bodySmall).foregroundStyle(.secondary).lineLimit(2)
            }
            Text(mention.occurredAt?.formatted(date: .abbreviated, time: .shortened) ?? mention.localDate ?? "")
                .font(SparkTypography.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, SparkSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)

        if mention.sourceDeleted {
            label.opacity(0.65)
        } else if mention.sourceType == "digest_block", let blockID = mention.blockID {
            NavigationLink(value: DetailRoute.block(id: blockID)) { label }.buttonStyle(.plain)
        } else {
            NavigationLink(value: FlintRoute.digest(mention.digestID)) { label }.buttonStyle(.plain)
        }
    }
}

private struct FlintDigestDestination: View {
    let id: String
    let viewModel: FlintViewModel
    let onOpen: (DetailRoute) -> Void

    var body: some View {
        Group {
            if let digest = viewModel.digest(id: id) {
                FlintDigestReader(digest: digest, viewModel: viewModel, onOpen: onOpen)
            } else if let state = viewModel.digestDetailState[id], case .error(let message) = state {
                EmptyState(systemImage: "doc.text", title: "Digest unavailable", message: message)
            } else {
                ProgressView("Loading digest…")
            }
        }
        .task(id: id) { await viewModel.loadDigest(id: id) }
    }
}

private struct FlintDigestReader: View {
    let digest: FlintDigest
    let viewModel: FlintViewModel
    let onOpen: (DetailRoute) -> Void
    @Environment(AppModel.self) private var appModel
    @State private var showsNoteComposer = false

    var body: some View {
        ScrollView {
            FlintDigestSection(digest: digest, viewModel: viewModel, onOpen: onOpen)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(SparkSpacing.lg)
        }
        .navigationTitle(digest.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sparkAppBackground()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showsNoteComposer = true } label: {
                    Label("Note to Flint", systemImage: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showsNoteComposer) {
            FlintNoteComposerView(
                context: .digest(id: digest.id, label: digest.displayTitle),
                apiClient: appModel.apiClient
            )
        }
    }
}

private struct FlintDigestSection: View {
    let digest: FlintDigest
    let viewModel: FlintViewModel
    let onOpen: (DetailRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xl) {
            if let summary = digest.summary, !summary.isEmpty {
                SparkLongFormContentView(text: summary, tint: .sparkAccent)
            }
            ForEach(digest.blocks) { block in
                if block.blockType != "flint_day_context" {
                    FlintBlockSurface(
                        block: block,
                        question: viewModel.question(id: block.id),
                        viewModel: viewModel,
                        onOpen: onOpen
                    )
                }
            }

            FlintDigestCheckInPrompt(digest: digest)
        }
    }
}

private struct FlintDigestCheckInPrompt: View {
    let digest: FlintDigest

    @Environment(AppModel.self) private var appModel
    @State private var checkInViewModel: TodayViewModel?
    @State private var showCheckIn = false

    private var checkInPeriod: CheckInPeriod? {
        switch digest.period {
        case .morning:
            return .morning
        case .afternoon, .evening:
            return .afternoon
        case nil:
            return nil
        }
    }

    private var digestDate: Date? {
        Self.dateFormatter.date(from: digest.date)
    }

    var body: some View {
        if let period = checkInPeriod, let digestDate {
            GlassCard {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    HStack {
                        SectionLabel("Check-in")
                        Spacer()
                        Text(period.rawValue.sparkSentenceCase)
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }

                    CheckInPeriodSummaryRow(
                        title: "\(period.rawValue.capitalized) Check-in",
                        status: status(for: period),
                        onTap: { showCheckIn = true }
                    )
                }
            }
            .sheet(isPresented: $showCheckIn, onDismiss: {
                Task { await checkInViewModel?.loadCheckIns() }
            }) {
                if let checkInViewModel {
                    CheckInModalView(
                        viewModel: checkInViewModel,
                        date: digestDate,
                        initialPeriod: period
                    )
                }
            }
            .task(id: digest.date) {
                let vm = TodayViewModel(
                    date: digestDate,
                    apiClient: appModel.apiClient,
                    container: appModel.container
                )
                await vm.loadCheckIns()
                checkInViewModel = vm
            }
        }
    }

    private func status(for period: CheckInPeriod) -> PeriodStatus {
        guard let checkInViewModel else { return .pending }
        switch period {
        case .morning:
            return checkInViewModel.checkInDayStatus.morning
        case .afternoon:
            return checkInViewModel.checkInDayStatus.afternoon
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

private struct FlintBlockSurface: View {
    let block: FlintDigestBlock
    var question: FlintQuestion? = nil
    let viewModel: FlintViewModel
    let onOpen: (DetailRoute) -> Void
    @State private var isEditorialExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            HStack(alignment: .top, spacing: SparkSpacing.md) {
                DomainGlyph(icon: icon, tint: tint, size: 26)
                VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                    Text(block.isQuestion ? (block.question ?? block.title) : block.title)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let topic = block.topic, !topic.isEmpty {
                        Text(topic).font(SparkTypography.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if block.isQuestion {
                if block.answered {
                    FlintAnswerFormView(
                        block: block,
                        isSubmitting: false,
                        errorMessage: nil,
                        onSubmit: { _, _ in }
                    )
                } else if let question {
                    FlintAnswerFormView(
                        block: block,
                        isSubmitting: viewModel.answeringBlockIDs.contains(block.id),
                        errorMessage: viewModel.answerErrorByBlockID[block.id],
                        onSubmit: { answer, note in
                            await viewModel.answerQuestion(question: question, answer: answer, note: note)
                        },
                        onNotRelevant: { await viewModel.skipQuestion(question) }
                    )
                } else {
                    Text("Refresh Flint to answer this question.")
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            } else if let content = block.content, !content.isEmpty {
                if block.blockType == "flint_editorial_note" {
                    DisclosureGroup("Read note", isExpanded: $isEditorialExpanded) {
                        SparkLongFormContentView(text: content, paragraphFont: SparkTypography.longFormBodySmall)
                            .padding(.top, SparkSpacing.sm)
                    }
                } else {
                    SparkLongFormContentView(text: content, paragraphFont: SparkTypography.longFormBodySmall)
                }
            }

            if let references = block.references, !references.isEmpty {
                EntityRefChipRow(label: "Connecting:", references: references) { reference in
                    if let route = reference.detailRoute { onOpen(route) }
                }
            }
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkFlintMaterialSurface()
    }

    private var icon: String {
        switch block.blockType {
        case "flint_user_question": "questionmark.circle.fill"
        case "flint_editorial_note": "pencil.and.scribble"
        case "flint_health_insight": "heart.fill"
        case "flint_news": "newspaper.fill"
        case "flint_reading_pick": "book.fill"
        case "flint_reading_drop": "trash"
        default: "sparkles"
        }
    }

    private var tint: Color {
        switch block.blockType {
        case "flint_health_insight": .sparkSuccess
        case "flint_news", "flint_reading_pick": .sparkOcean
        case "flint_reading_drop": .sparkTextSecondary
        default: .sparkAccent
        }
    }
}

private extension FlintDigest {
    var displayTitle: String {
        guard let period else { return title }
        let generatedPrefix = "\(period.displayName) Digest"
        guard title.hasPrefix(generatedPrefix) else { return title }
        let suffix = title.dropFirst(generatedPrefix.count)
        return [" — ", " – ", " - "].contains(where: { suffix.hasPrefix($0) }) ? generatedPrefix : title
    }

    var lede: String? {
        summary?
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("#") }
    }
}

private extension FlintTopicStatus {
    var displayName: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .active: "circle.fill"
        case .dormant: "pause.circle"
        case .resolved: "checkmark.circle"
        case .expired: "clock.badge.xmark"
        }
    }
}
