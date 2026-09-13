import SparkKit
import SparkUI
import SwiftUI

struct FlintView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.tabAccessoryCoordinator) private var tabAccessoryCoordinator
    @State private var viewModel: FlintViewModel?
    @State private var path: [DetailRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            tabScrollView
            .sparkMainNavigationTitle("Flint")
            .sparkAppBackground()
            .sparkMainAppToolbar()
            .sparkDetailDestinations()
            .environment(\.openURL, OpenURLAction { url in
                if let route = DeepLink.parse(url)?.detailRoute {
                    push(route)
                    return .handled
                }
                return .systemAction
            })
            .onAppear {
                registerTabAccessory()
            }
            .onChange(of: viewModel?.selectedTab) { _, _ in
                registerTabAccessory()
            }
            .onDisappear {
                tabAccessoryCoordinator?.clear(owner: .flint)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = FlintViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
            registerTabAccessory()
        }
    }

    private var tabScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                if let viewModel {
                    content(for: viewModel)
                } else {
                    loadingContent
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, SparkSpacing.md)
            .padding(.bottom, SparkSpacing.xxl * 2)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await refresh() }
    }

    private func refresh() async {
        guard let viewModel else { return }
        switch viewModel.selectedTab {
        case .today, .questions: await viewModel.refresh()
        case .threads: await viewModel.loadTopics()
        case .archive: await viewModel.selectArchiveDate(viewModel.archiveDate)
        }
    }

    private func registerTabAccessory() {
        guard let viewModel else { return }

        tabAccessoryCoordinator?.set(TabAccessory(
            owner: .flint,
            title: "Flint section",
            items: FlintViewModel.FlintTab.allCases.map { TabAccessoryItem(id: $0.id, title: $0.title) },
            selectedID: viewModel.selectedTab.id,
            select: { id in
                guard let tab = FlintViewModel.FlintTab(rawValue: id) else { return }
                viewModel.selectedTab = tab
                if tab == .threads {
                    Task { await viewModel.loadTopicsIfNeeded() }
                }
            }
        ))
    }

    @ViewBuilder
    private func content(for viewModel: FlintViewModel) -> some View {
        switch viewModel.selectedTab {
        case .today:
            todayContent(viewModel)
        case .questions:
            questionsContent(viewModel)
        case .threads:
            threadsContent(viewModel)
        case .archive:
            archiveContent(viewModel)
        }
    }

    // MARK: - Today

    @ViewBuilder
    private func todayContent(_ viewModel: FlintViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingContent
        case .loaded:
            FlintDigestTimeline(digests: viewModel.digests, viewModel: viewModel, onOpen: push)
        case .empty(let message):
            EmptyState(systemImage: "sparkles", title: "No digest yet", message: message)
        case .error(let message):
            errorContent(message) { Task { await viewModel.refresh() } }
        }
    }

    // MARK: - Questions

    @ViewBuilder
    private func questionsContent(_ viewModel: FlintViewModel) -> some View {
        if viewModel.openQuestions.isEmpty {
            EmptyState(
                systemImage: "checkmark.circle",
                title: "No open questions",
                message: "Flint will ask here when there's something worth clarifying."
            )
        } else {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                ForEach(viewModel.openQuestions) { question in
                    VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                        Text(questionContext(question.digest))
                            .font(SparkTypography.caption)
                            .foregroundStyle(.secondary)
                        FlintBlockRow(block: question.block, viewModel: viewModel, onOpen: push)
                    }
                }
            }
        }
    }

    private func questionContext(_ digest: FlintDigest) -> String {
        [digest.period?.displayName, digest.createdAt?.formatted(date: .omitted, time: .shortened)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    // MARK: - Threads

    @ViewBuilder
    private func threadsContent(_ viewModel: FlintViewModel) -> some View {
        switch viewModel.topicsState {
        case .idle, .loading:
            loadingContent
        case .loaded:
            VStack(spacing: 0) {
                ForEach(Array(viewModel.topics.enumerated()), id: \.element.id) { index, topic in
                    FlintTopicRow(topic: topic)
                    if index < viewModel.topics.count - 1 {
                        Divider().opacity(0.15)
                    }
                }
            }
            .padding(.vertical, SparkSpacing.xs)
            .sparkGlass(.roundedRect(SparkRadii.lg))
        case .empty(let message):
            EmptyState(systemImage: "point.3.connected.trianglepath.dotted", title: "No running threads", message: message)
        case .error(let message):
            errorContent(message) { Task { await viewModel.loadTopics() } }
        }
    }

    // MARK: - Archive

    @ViewBuilder
    private func archiveContent(_ viewModel: FlintViewModel) -> some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: SparkSpacing.lg) {
            DatePicker(
                "Date",
                selection: Binding(
                    get: { viewModel.archiveDate },
                    set: { newDate in Task { await viewModel.selectArchiveDate(newDate) } }
                ),
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()

            switch viewModel.archiveState {
            case .idle:
                Color.clear.frame(height: 1).task { await viewModel.selectArchiveDate(viewModel.archiveDate) }
            case .loading:
                loadingContent
            case .loaded:
                FlintDigestTimeline(digests: viewModel.archiveDigests, viewModel: viewModel, onOpen: push)
            case .empty(let message):
                EmptyState(systemImage: "calendar", title: "Nothing that day", message: message)
            case .error(let message):
                errorContent(message) { Task { await viewModel.selectArchiveDate(viewModel.archiveDate) } }
            }
        }
    }

    // MARK: - Shared

    private func errorContent(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: SparkSpacing.md) {
            EmptyState(systemImage: "wifi.exclamationmark", title: "Couldn't load Flint", message: message)
            PillButton("Retry", systemImage: "arrow.clockwise", tint: .sparkAccent, action: retry)
        }
    }

    private func push(_ route: DetailRoute) {
        if path.last == route { return }
        path.append(route)
    }

    private var loadingContent: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                LoadingShimmer(cornerRadius: SparkRadii.sm)
                    .frame(height: 18)
                    .frame(maxWidth: 220)
                LoadingShimmer(cornerRadius: SparkRadii.sm)
                    .frame(height: 84)
                LoadingShimmer(cornerRadius: SparkRadii.sm)
                    .frame(height: 18)
                    .frame(maxWidth: 280)
            }
            .accessibilityLabel("Loading Flint")
        }
    }
}

// MARK: - Today / Archive timeline

/// Digests for one day, newest first, as a tappable timeline — a time marker,
/// title, and a one-line lede; tapping expands the full digest in place.
private struct FlintDigestTimeline: View {
    let digests: [FlintDigest]
    let viewModel: FlintViewModel
    let onOpen: (DetailRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.lg) {
            ForEach(digests) { digest in
                FlintTimelineEntry(digest: digest, viewModel: viewModel, onOpen: onOpen)
            }
        }
    }
}

private struct FlintTimelineEntry: View {
    let digest: FlintDigest
    let viewModel: FlintViewModel
    let onOpen: (DetailRoute) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                header
            }
            .buttonStyle(.plain)

            if isExpanded {
                FlintDigestSection(digest: digest, viewModel: viewModel, onOpen: onOpen)
                    .padding(.leading, 56)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: SparkSpacing.md) {
            Text(timeText)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                Text(digest.displayTitle)
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.primary)

                if let lede {
                    Text(lede)
                        .font(SparkTypography.longFormBodySmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let count = digest.unansweredQuestionCount, count > 0 {
                    Text(count == 1 ? "1 question open" : "\(count) questions open")
                        .font(SparkTypography.caption)
                        .foregroundStyle(Color.sparkWarning)
                }
            }

            Spacer(minLength: SparkSpacing.sm)

            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .padding(.top, 2)
        }
        .contentShape(Rectangle())
    }

    private var timeText: String {
        digest.createdAt?.formatted(date: .omitted, time: .shortened) ?? ""
    }

    private var lede: String? {
        guard let summary = digest.summary else { return nil }
        let firstLine = summary
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("#") }
        return firstLine
    }
}

// MARK: - Threads row

private struct FlintTopicRow: View {
    let topic: FlintTopic

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            Circle()
                .fill(topic.status?.isActive == true ? Color.sparkAccent : Color.secondary.opacity(0.35))
                .frame(width: 7, height: 7)

            Text(topic.title)
                .font(SparkTypography.body)
                .foregroundStyle(topic.status?.isActive == true ? .primary : .secondary)
                .lineLimit(2)

            Spacer(minLength: SparkSpacing.sm)

            Text(meta)
                .font(SparkTypography.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.vertical, SparkSpacing.md)
    }

    private var meta: String {
        let statusText = topic.status.map(\.rawValue.capitalized) ?? ""
        guard let touched = topic.lastTouchedAt else { return statusText }
        let days = Calendar.current.dateComponents([.day], from: touched, to: .now).day ?? 0
        let age = days <= 0 ? "today" : "\(days)d"
        return statusText.isEmpty ? age : "\(statusText) · \(age)"
    }
}

private extension FlintDigest {
    var displayTitle: String {
        guard let period else { return title }

        let generatedPrefix = "\(period.displayName) Digest"
        guard title.hasPrefix(generatedPrefix) else { return title }

        let suffix = title.dropFirst(generatedPrefix.count)
        let separators = [" — ", " – ", " - "]
        if separators.contains(where: { suffix.hasPrefix($0) }) {
            return generatedPrefix
        }

        return title
    }
}

// MARK: - Digest section (shared by the timeline's expanded state)

private struct FlintDigestSection: View {
    let digest: FlintDigest
    let viewModel: FlintViewModel
    let onOpen: (DetailRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.lg) {
            if let summary = digest.summary, !summary.isEmpty {
                SparkLongFormContentView(text: summary, tint: .sparkAccent)
            }

            if digest.blocks.isEmpty {
                Text("This digest has no blocks yet.")
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
            } else {
                blockRows(insightBlocks)
                blockRows(questionBlocks)
            }

            FlintDigestCheckInPrompt(digest: digest)

            blockRows(editorialBlocks)
        }
    }

    private var insightBlocks: [FlintDigestBlock] {
        // flint_day_context has no content/icon here — it renders as its own
        // screen in Up to Speed's DayContextSection, not a generic insight row.
        digest.blocks.filter {
            !$0.isQuestion && $0.blockType != "flint_editorial_note" && $0.blockType != "flint_day_context"
        }
    }

    private var questionBlocks: [FlintDigestBlock] {
        digest.blocks.filter(\.isQuestion)
    }

    private var editorialBlocks: [FlintDigestBlock] {
        digest.blocks.filter { $0.blockType == "flint_editorial_note" }
    }

    @ViewBuilder
    private func blockRows(_ blocks: [FlintDigestBlock]) -> some View {
        if !blocks.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                ForEach(blocks) { block in
                    FlintBlockRow(block: block, viewModel: viewModel, onOpen: onOpen)
                }
            }
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
                        SectionLabel("CHECK-IN")
                        Spacer()
                        Text(period.rawValue.uppercased())
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

private struct FlintBlockRow: View {
    let block: FlintDigestBlock
    let viewModel: FlintViewModel
    let onOpen: (DetailRoute) -> Void
    @State private var isEditorialExpanded = false

    @ViewBuilder
    private var referenceRow: some View {
        if let references = block.references, !references.isEmpty {
            EntityRefChipRow(label: "Connecting:", references: references) { reference in
                if let route = reference.detailRoute {
                    onOpen(route)
                }
            }
        }
    }

    var body: some View {
        if block.blockType == "flint_editorial_note" {
            editorialDisclosure
        } else {
            standardRow
        }
    }

    private var standardRow: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            HStack(alignment: .top, spacing: SparkSpacing.md) {
                DomainGlyph(icon: icon, tint: tint, size: 26)

                VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                        Text(block.isQuestion ? (block.question ?? block.title) : block.title)
                            .font(SparkTypography.bodyStrong)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: SparkSpacing.sm)
                        if let badge {
                            Text(badge)
                                .font(SparkTypography.monoSmall)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let topic = block.topic, !topic.isEmpty {
                        Text(topic.capitalized)
                            .font(SparkTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if block.isQuestion {
                FlintAnswerFormView(
                    block: block,
                    isSubmitting: viewModel.answeringBlockIDs.contains(block.id),
                    errorMessage: viewModel.answerErrorByBlockID[block.id],
                    onSubmit: { answer, note in
                        await viewModel.answerQuestion(block: block, answer: answer, note: note)
                    }
                )
            } else if let content = block.content, !content.isEmpty {
                SparkRichContentText(text: content, font: SparkTypography.bodySmall, foregroundStyle: .secondary)
            }

            referenceRow
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkGlass(.roundedRect(SparkRadii.md), tint: tint.opacity(0.08))
    }

    private var editorialDisclosure: some View {
        DisclosureGroup(isExpanded: $isEditorialExpanded) {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                if let content = block.content, !content.isEmpty {
                    SparkRichContentText(text: content, font: SparkTypography.bodySmall, foregroundStyle: .secondary)
                }
                referenceRow
            }
            .padding(.top, SparkSpacing.md)
        } label: {
            HStack(alignment: .center, spacing: SparkSpacing.md) {
                DomainGlyph(icon: icon, tint: tint, size: 24)
                VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                    Text(block.title)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.primary)
                    Text("Editorial Note")
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: SparkSpacing.sm)
            }
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkGlass(.roundedRect(SparkRadii.md), tint: tint.opacity(0.08))
    }

    /// Only the types the server actually registers. This table had grown a
    /// dozen entries for blocks Flint has never written — flint_urgent_alert,
    /// flint_correlation, flint_news_briefing — while the types genuinely in
    /// use, flint_news and the reading picks, fell through to the default.
    private var icon: String {
        switch block.blockType {
        case "flint_user_question": "questionmark.circle.fill"
        case "flint_editorial_note": "pencil.and.scribble"
        case "flint_health_insight": "heart.fill"
        case "flint_day_context": "calendar"
        case "flint_news": "newspaper.fill"
        case "flint_reading_pick": "book.fill"
        case "flint_reading_drop": "trash"
        default: "sparkles"
        }
    }

    private var tint: Color {
        switch block.blockType {
        case "flint_user_question": .sparkAccent
        case "flint_health_insight": .sparkSuccess
        case "flint_news", "flint_reading_pick": .sparkOcean
        case "flint_reading_drop": .sparkTextSecondary
        default: .sparkAccent
        }
    }

    private var badge: String? {
        if let priority = block.priority {
            return "\(priority.displayName) priority"
        }
        return blockTypeTitle(block.blockType)
    }

    private func blockTypeTitle(_ raw: String) -> String? {
        let trimmed = raw.replacingOccurrences(of: "flint_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.capitalized
    }
}
