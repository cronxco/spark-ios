import SparkKit
import SparkUI
import SwiftData
import SwiftUI

struct TodayView: View {
    let date: Date
    var showsToolbar = true
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: TodayViewModel?
    @State private var checkInSelection: CheckInSheetSelection?
    @State private var showHistory = false
    @State private var checkInHistoryVM: CheckInHistoryViewModel?
    @State private var showUpToSpeed = false
    @State private var upToSpeedViewModel: UpToSpeedViewModel?
    @State private var selectedThread: FlintTopic?

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    /// A day that has not started yet gets its own forward-looking page;
    /// nothing on the Today layout can have data for it.
    private var isFuture: Bool {
        Calendar.current.compare(date, to: .now, toGranularity: .day) == .orderedDescending
    }

    var body: some View {
        if isFuture {
            LookingAheadView(date: date, showsToolbar: showsToolbar)
        } else {
            todayBody
        }
    }

    @ViewBuilder
    private var todayBody: some View {
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
                    // is talking about, not a dashboard the summary happens to
                    // sit near.
                    if let summary = viewModel?.briefingSummaryLine {
                        DaySummaryCard(summary: summary)
                    }

                    // In the evening, once there is something to say about
                    // tomorrow, a way across to it.
                    if isToday, let tomorrow = viewModel?.tomorrowAhead {
                        TomorrowGlanceCard(ahead: tomorrow) {
                            if let next = Calendar.current.date(byAdding: .day, value: 1, to: date) {
                                appModel.pendingRoute = .day(next)
                            }
                        }
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

                    CheckInsSection(
                        date: date,
                        status: snapshot.checkInStatus,
                        historyVM: checkInHistoryVM,
                        showHistory: $showHistory,
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
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            // Clear the minimised tab bar at the end of the page.
            .contentMargins(.bottom, SparkSpacing.xxxl, for: .scrollContent)
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
        .task(id: date) {
            // The tomorrow card appears from 17:00; a page left open across
            // that hour would otherwise wait for the next sync to show it.
            guard isToday,
                  let boundary = Calendar.current.date(
                      bySettingHour: TodayViewModel.tomorrowGlanceHour, minute: 0, second: 0, of: .now
                  )
            else { return }
            let delay = boundary.timeIntervalSinceNow
            guard delay > 0 else { return }
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard scenePhase == .active else { return }
            await viewModel?.backgroundRevalidate()
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
            .foregroundStyle(index == 0 ? heroLeadStyle : AnyShapeStyle(.secondary))
            .lineLimit(1)
            .minimumScaleFactor(0.88)
    }

    /// The hero's first line is the Day tab's title, so it takes the same
    /// yellow in dark mode as the titles on the other tabs.
    private var heroLeadStyle: AnyShapeStyle {
        colorScheme == .dark ? AnyShapeStyle(Color.spark2) : AnyShapeStyle(.primary)
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

    /// A status line (`docs/design-language.md` section 7.4): a glyph and a
    /// sentence on a content surface, with no chip unless action is needed.
    private func anomalySummaryRow(message: String, count: String?, tint: Color) -> some View {
        HStack(spacing: SparkSpacing.sm) {
            SparkGlyph(count == nil ? .success : .warning, size: 15)
                .foregroundStyle(tint)
            Text(message)
                .font(SparkTypography.body.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: SparkSpacing.sm)
            if let count {
                Text(count)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, SparkSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .sparkContentSurface(radius: SparkRadii.md)
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

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text("\(unreadCount)")
                    .font(Font.custom(SparkFonts.displayPostScriptName, size: 12).bold())
                    .foregroundStyle(Color.sparkOnAccent)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Color.sparkOnAccent.opacity(0.12), in: .capsule)

                Text("Get Up to Speed")
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(Color.sparkOnAccent)
            }
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .frame(minHeight: 44)
            .background(Color.sparkAccent, in: .capsule)
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

/// Turns scroll offsets into "show the bar" or "hide the bar". Not wired
/// up at the moment: hiding the bar's buttons on scroll froze the day page
/// three times over, so the buttons stay put until there is a way to hide
/// them that doesn't resize the bar.
///
/// Turns scroll offsets into "show the bar" or "hide the bar". While the
/// bar shows, it measures down from the highest point reached since it
/// appeared; while it is hidden, up from the lowest point. A slow scroll, or
/// one that wobbles back a little as it goes, still adds up to the
/// threshold.
///
/// Showing or hiding the bar's buttons can resize the bar, which moves the
/// page by about the bar's height. Read as a scroll, that move flipped the
/// bar straight back, every frame, and the page froze. So after each flip
/// the tracker ignores offsets for a moment and then measures from wherever
/// the page settled.
@MainActor
final class ScrollDirectionTracker {
    /// Scroll distance, in points, that counts as a change of direction.
    static let threshold: CGFloat = 8
    /// Near the top of the page the bar always shows.
    static let revealOffset: CGFloat = 40
    /// How long after a flip offsets are ignored, in seconds: longer than
    /// the bar's own animation.
    static let settleTime: TimeInterval = 0.5

    /// The smallest offset since the bar last showed.
    private var low = CGFloat.infinity
    /// The largest offset since the bar last hid.
    private var high = -CGFloat.infinity
    /// Offsets before this time are the page settling after a flip.
    private var settlesAt: TimeInterval = -.infinity

    /// `true` to show the bar, `false` to hide it, `nil` to leave it.
    /// `isShown` is the bar's state now, which the pager can also change.
    func update(from old: CGFloat, to new: CGFloat, isShown: Bool, now: TimeInterval) -> Bool? {
        if now < settlesAt {
            low = new
            high = new
            return nil
        }
        if new <= Self.revealOffset {
            low = new
            high = -.infinity
            if isShown { return nil }
            settlesAt = now + Self.settleTime
            return true
        }
        if isShown {
            low = min(low, old, new)
            if new - low > Self.threshold {
                high = new
                low = .infinity
                settlesAt = now + Self.settleTime
                return false
            }
        } else {
            high = max(high, old, new)
            if high - new > Self.threshold {
                low = new
                high = -.infinity
                settlesAt = now + Self.settleTime
                return true
            }
        }
        return nil
    }
}
