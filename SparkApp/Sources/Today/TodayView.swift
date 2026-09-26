import SparkKit
import SparkUI
import SwiftData
import SwiftUI

struct TodayView: View {
    let date: Date
    var showsToolbar = true
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: TodayViewModel?
    @State private var checkInSelection: CheckInSheetSelection?
    @State private var showHistory = false
    @State private var checkInHistoryVM: CheckInHistoryViewModel?
    @State private var showUpToSpeed = false
    @State private var upToSpeedViewModel: UpToSpeedViewModel?
    @State private var selectedThread: FlintTopic?
    @State private var hasScrolledPastTop = false

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        let snapshot = TodaySnapshot(
            summary: viewModel?.cached,
            date: date,
            checkInStatus: viewModel?.checkInDayStatus ?? .allPending
        )

        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    let unreadCount = upToSpeedViewModel?.unreadCount ?? 0

                    hero(snapshot: snapshot, unreadCount: unreadCount)
                        .sparkAppEntityIdentifier(type: "day", identifier: TodayViewModel.isoKey(for: date))

                    // Flint's own words first: the numbers below are what it
                    // is talking about, not a dashboard the digest happens to
                    // sit near.
                    // The digest, questions and threads are "now", not this
                    // date's; the view model only loads them for today, and a
                    // page that was today before midnight stops showing them.
                    if isToday, let digest = viewModel?.latestDigest {
                        DigestOpenerCard(digest: digest) { showUpToSpeed = true }
                    }

                    MetricsGrid(metrics: viewModel?.metrics ?? DayMetrics(summary: nil))

                    anomalySummary(for: snapshot)

                    if isToday, let vm = viewModel, !vm.recentQuestions.isEmpty {
                        FlintQuestionStack(
                            questions: vm.recentQuestions,
                            onAnswer: { question, option in
                                Task { await vm.answer(question: question, with: option) }
                            },
                            onOpen: { showUpToSpeed = true }
                        )
                    }

                    CheckInCard(
                        date: date,
                        status: snapshot.checkInStatus,
                        onTapMorning: {
                            checkInSelection = CheckInSheetSelection(date: date, period: .morning)
                        },
                        onTapAfternoon: {
                            checkInSelection = CheckInSheetSelection(date: date, period: .afternoon)
                        }
                    )

                    if isToday, let vm = viewModel, !vm.topics.isEmpty {
                        ThreadsStrip(topics: vm.topics) { selectedThread = $0 }
                    }

                    CheckInHeatmapCard(historyVM: checkInHistoryVM, showHistory: $showHistory)

                    FeedSection(date: date)

                    if !snapshot.hasAnyDomainData {
                        loadingOrEmptyState
                    }

                    #if DEBUG
                        if let vm = viewModel, !vm.rawAPIEntries.isEmpty {
                            RawFeedJSONView(title: "Raw API response", entries: vm.rawAPIEntries)
                        }
                    #endif
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.top, SparkSpacing.sm)
                .padding(.bottom, SparkSpacing.xl)
                .containerRelativeFrame(.horizontal)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > SparkSpacing.sm
            } action: { _, hasScrolled in
                hasScrolledPastTop = hasScrolled
            }
            // The page-style TabView stops the scroll view at the navigation
            // bar. Fade cards before that boundary so their borders do not
            // appear abruptly sliced beneath the toolbar.
            .mask(alignment: .top) {
                if hasScrolledPastTop {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: 28)
                        Color.black
                    }
                } else {
                    Color.black
                }
            }
            .refreshable {
                await viewModel?.refresh()
                await checkInHistoryVM?.load()
            }
        }
        .sparkMainAppToolbar(isVisible: showsToolbar)
        .sheet(item: $checkInSelection, onDismiss: {
            Task { await checkInHistoryVM?.load() }
        }) { selection in
            if let vm = viewModel {
                CheckInModalView(viewModel: vm, date: selection.date, initialPeriod: selection.period)
            }
        }
        .sheet(item: $selectedThread) { topic in
            ThreadDetailSheet(topic: topic)
        }
        .sheet(isPresented: $showHistory, onDismiss: {
            Task { await viewModel?.loadCheckIns() }
        }) {
            if let checkInHistoryVM {
                CheckInHistoryView(apiClient: appModel.apiClient, container: appModel.container, historyVM: checkInHistoryVM)
            }
        }
        .fullScreenCover(isPresented: $showUpToSpeed, onDismiss: {
            Task { await upToSpeedViewModel?.load() }
        }) {
            UpToSpeedView(isPresented: $showUpToSpeed, viewModel: upToSpeedViewModel)
                .environment(appModel)
        }
        .task(id: date) {
            checkInHistoryVM = CheckInHistoryViewModel(
                apiClient: appModel.apiClient,
                container: appModel.container,
                endDate: date
            )
            if viewModel == nil {
                viewModel = TodayViewModel(
                    date: date,
                    apiClient: appModel.apiClient,
                    container: appModel.container
                )
            }
            async let dayLoad: Void = viewModel?.load() ?? ()
            async let historyLoad: Void = checkInHistoryVM?.load() ?? ()
            _ = await (dayLoad, historyLoad)
        }
        .task {
            if upToSpeedViewModel == nil {
                upToSpeedViewModel = UpToSpeedViewModel(
                    apiClient: appModel.apiClient,
                    profileName: appModel.profile?.name
                )
            }
            await upToSpeedViewModel?.load()
        }
        .onChange(of: appModel.lastSyncAt) {
            Task { await viewModel?.backgroundRevalidate() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel?.backgroundRevalidate() }
            }
        }
    }

    // MARK: - Hero

    private func hero(snapshot: TodaySnapshot, unreadCount: Int) -> some View {
        let title = heroTitle(snapshot: snapshot)
        let titleLines = title.components(separatedBy: "\n")

        return VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            if unreadCount > 0 {
                heroTitleWithAction(titleLines: titleLines, unreadCount: unreadCount)
            } else {
                heroTitleStack(titleLines: titleLines)
            }

            if let subtitle = viewModel?.briefingSummaryLine {
                Text(subtitle)
                    .font(SparkTypography.body)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func heroTitleWithAction(titleLines: [String], unreadCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: SparkSpacing.md) {
                    if let firstLine = titleLines.first {
                        heroTitleText(firstLine, index: 0)
                    }

                    Spacer(minLength: SparkSpacing.md)

                    GetUpToSpeedButton(
                        unreadCount: unreadCount,
                        onTap: { showUpToSpeed = true }
                    )
                }
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    if let firstLine = titleLines.first {
                        heroTitleText(firstLine, index: 0)
                    }
                    GetUpToSpeedButton(unreadCount: unreadCount, onTap: { showUpToSpeed = true })
                }
            }

            if titleLines.count > 1 {
                ForEach(Array(titleLines.dropFirst().enumerated()), id: \.offset) { offset, line in
                    heroTitleText(line, index: offset + 1)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func heroTitleStack(titleLines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(titleLines.enumerated()), id: \.offset) { index, line in
                heroTitleText(line, index: index)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(titleLines.joined(separator: " "))
        .accessibilityAddTraits(.isHeader)
    }

    private func heroTitleText(_ line: String, index: Int) -> some View {
        Text(line)
            .font(heroTitleFont)
            .foregroundStyle(index == 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .lineLimit(1)
            .minimumScaleFactor(0.88)
    }

    private var heroTitleFont: Font {
        Font.custom(SparkFonts.displayPostScriptName, size: 32, relativeTo: .largeTitle)
            .weight(.bold)
    }

    private func heroTitle(snapshot: TodaySnapshot) -> String {
        if Calendar.current.isDateInToday(date) {
            return "\(firstName),\nyour day so far."
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday\nin review"
        } else if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now),
                  Calendar.current.isDate(date, inSameDayAs: tomorrow) {
            return "Looking ahead"
        } else {
            return Self.dayTitleFormatter.string(from: date)
        }
    }

    private var firstName: String {
        let name = appModel.profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.split(separator: " ").first.map(String.init) ?? "Your"
    }

    private static let dayTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE\nd MMMM yyyy"
        return f
    }()

    // MARK: - Anomaly summary

    @ViewBuilder
    private func anomalySummary(for snapshot: TodaySnapshot) -> some View {
        if snapshot.anomalies.isEmpty {
            anomalySummaryRow(message: "Baselines holding", count: nil, tint: .sparkSuccess)
        } else {
            anomalySummaryRow(
                message: snapshot.anomalies.first?.displayName
                    ?? snapshot.anomalies.first?.metric
                    ?? "Anomaly detected",
                count: "\(snapshot.anomalies.count) anomal\(snapshot.anomalies.count == 1 ? "y" : "ies")",
                tint: .sparkWarning
            )
            .sparkAppEntityIdentifier(type: "anomaly", identifier: snapshot.anomalies.first?.id)
        }
    }

    private func anomalySummaryRow(message: String, count: String?, tint: Color) -> some View {
        HStack(spacing: SparkSpacing.sm) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
            if let count {
                Spacer(minLength: SparkSpacing.sm)
                Text(count)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, SparkSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count.map { "\(message), \($0)" } ?? message)
    }

    // MARK: - Loading / empty

    @ViewBuilder
    private var loadingOrEmptyState: some View {
        switch viewModel?.networkState {
        case .loading:
            VStack(spacing: SparkSpacing.md) {
                LoadingShimmerCard()
                LoadingShimmerCard()
            }
        case .error(let msg):
            EmptyState(
                systemImage: "exclamationmark.triangle.fill",
                title: "Couldn't load today",
                message: msg,
                actionTitle: "Retry"
            ) { Task { await viewModel?.refresh() } }
        default:
            EmptyState(
                systemImage: "sparkles",
                title: "Nothing yet for today",
                message: "We'll fill this in as integrations sync."
            )
        }
    }
}

private struct CheckInSheetSelection: Identifiable {
    let date: Date
    let period: CheckInPeriod

    var id: String {
        "\(Self.formatter.string(from: date))-\(period.rawValue)"
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - GetUpToSpeedButton

private struct GetUpToSpeedButton: View {
    let unreadCount: Int
    let onTap: () -> Void

    private static let darkInk = Color(red: 0.086, green: 0.086, blue: 0.086)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text("\(unreadCount)")
                    .font(Font.custom(SparkFonts.displayPostScriptName, size: 12).bold())
                    .foregroundStyle(Self.darkInk)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Self.darkInk.opacity(0.12), in: .capsule)

                Text("Get Up to Speed")
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(Self.darkInk)
            }
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .frame(minHeight: 44)
            .background(Color.sparkAccent, in: .capsule)
            .shadow(color: Color.sparkAccent.opacity(0.22), radius: 7, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private extension TodaySnapshot {
    var hasAnyDomainData: Bool {
        (health?.hasSleep ?? false)
            || (activity?.hasAny ?? false)
            || (money?.hasAny ?? false)
            || (media?.hasAny ?? false)
            || (knowledge?.hasAny ?? false)
    }
}
