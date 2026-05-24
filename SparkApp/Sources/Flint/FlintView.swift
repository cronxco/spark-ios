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
            digestScrollView
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
                registerPeriodAccessory()
            }
            .onChange(of: viewModel?.selectedPeriod) { _, _ in
                registerPeriodAccessory()
            }
            .onChange(of: viewModel?.availablePeriodSelections.map(\.id) ?? []) { _, _ in
                registerPeriodAccessory()
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
            registerPeriodAccessory()
        }
    }

    private var digestScrollView: some View {
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
        .refreshable { await viewModel?.refresh() }
    }

    private func registerPeriodAccessory() {
        guard let viewModel else { return }

        tabAccessoryCoordinator?.set(TabAccessory(
            owner: .flint,
            title: "Digest period",
            items: viewModel.availablePeriodSelections.map {
                TabAccessoryItem(id: $0.id, title: $0.title)
            },
            selectedID: viewModel.selectedPeriod.id,
            select: { id in
                guard let period = FlintViewModel.PeriodSelection(rawValue: id) else { return }
                Task { await viewModel.selectPeriod(period) }
            }
        ))
    }

    @ViewBuilder
    private func content(for viewModel: FlintViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingContent
        case .loaded:
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                if let digest = viewModel.digests.first {
                    FlintDigestHeader(digest: digest)
                }

                ForEach(viewModel.digests) { digest in
                    FlintDigestSection(digest: digest, viewModel: viewModel, onOpen: push)
                }
            }
        case .empty(let message):
            EmptyState(
                systemImage: "sparkles",
                title: "No digest yet",
                message: message
            )
        case .error(let message):
            VStack(spacing: SparkSpacing.md) {
                EmptyState(
                    systemImage: "wifi.exclamationmark",
                    title: "Couldn't load Flint",
                    message: message
                )
                PillButton("Retry", systemImage: "arrow.clockwise", tint: .sparkAccent) {
                    Task { await viewModel.refresh() }
                }
            }
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
            .accessibilityLabel("Loading Flint digest")
        }
    }

}

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
        digest.blocks.filter { !$0.isQuestion && $0.blockType != "flint_editorial_note" }
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

private struct FlintDigestHeader: View {
    let digest: FlintDigest

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Text(digest.displayTitle)
                .font(SparkTypography.heroXL)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: SparkSpacing.sm) {
                Label(createdAtText, systemImage: "clock")
                if let count = digest.unansweredQuestionCount, count > 0 {
                    Text("\(count) unanswered")
                        .foregroundStyle(Color.sparkWarning)
                }
            }
            .font(SparkTypography.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var createdAtText: String {
        guard let createdAt = digest.createdAt else { return digest.date }
        return createdAt.formatted(
            Date.FormatStyle()
                .weekday(.abbreviated)
                .day()
                .month(.abbreviated)
                .hour()
                .minute()
        )
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

    private var icon: String {
        switch block.blockType {
        case "flint_user_question": "questionmark.circle.fill"
        case "flint_editorial_note": "pencil.and.scribble"
        case "flint_health_insight", "flint_coaching_check_in": "heart.fill"
        case "flint_money_insight": "sterlingsign.circle.fill"
        case "flint_media_insight": "play.circle.fill"
        case "flint_knowledge_insight", "flint_articles_waiting": "book.fill"
        case "flint_online_insight": "network"
        case "flint_cross_domain_insight", "flint_correlation": "arrow.left.arrow.right"
        case "flint_pattern_detected": "chart.line.uptrend.xyaxis"
        case "flint_prioritized_action": "flag.fill"
        case "flint_urgent_alert": "bell.badge.fill"
        case "flint_digest": "doc.text.fill"
        case "flint_news_briefing": "newspaper.fill"
        case "flint_coaching_insight": "brain.head.profile"
        default: "sparkles"
        }
    }

    private var tint: Color {
        switch block.blockType {
        case "flint_user_question", "flint_prioritized_action": .sparkAccent
        case "flint_urgent_alert": .sparkError
        case "flint_health_insight", "flint_coaching_check_in", "flint_coaching_insight": .sparkSuccess
        case "flint_money_insight": .sparkWarning
        case "flint_media_insight": .sparkInfo
        case "flint_knowledge_insight", "flint_news_briefing", "flint_articles_waiting": .sparkOcean
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

