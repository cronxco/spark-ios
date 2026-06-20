import SparkKit
import SparkUI
import SwiftData
import SwiftUI
import UIKit

struct TodayView: View {
    let date: Date
    var showsToolbar = true
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: TodayViewModel?
    @State private var checkInSelection: CheckInSheetSelection?
    @State private var showHistory = false
    @State private var showUpToSpeed = false
    @State private var upToSpeedViewModel: UpToSpeedViewModel?

    var body: some View {
        let snapshot = TodaySnapshot(
            summary: viewModel?.cached,
            date: date,
            checkInStatus: viewModel?.checkInDayStatus ?? .allPending
        )

        ZStack {
            SparkResolvedAppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    let unreadCount = upToSpeedViewModel?.unreadCount ?? 0

                    hero(snapshot: snapshot, unreadCount: unreadCount)

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

                    CheckInHeatmapCard(date: date, showHistory: $showHistory)

                    FeedSection(date: date)

                    if !snapshot.hasAnyDomainData {
                        loadingOrEmptyState
                    }

                    if let vm = viewModel, !vm.rawAPIEntries.isEmpty {
                        RawFeedJSONView(title: "Raw API response", entries: vm.rawAPIEntries)
                    }
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.vertical, SparkSpacing.xl)
            }
            .scrollContentBackground(.hidden)
            .refreshable { await viewModel?.refresh() }
        }
        .sparkScrollingNavigationBar()
        .sparkMainAppToolbar(isVisible: showsToolbar)
        .sheet(item: $checkInSelection) { selection in
            if let vm = viewModel {
                CheckInModalView(viewModel: vm, date: selection.date, initialPeriod: selection.period)
            }
        }
        .sheet(isPresented: $showHistory) {
            if let vm = viewModel {
                CheckInHistoryView(apiClient: appModel.apiClient, container: appModel.container, todayViewModel: vm)
            }
        }
        .fullScreenCover(isPresented: $showUpToSpeed, onDismiss: {
            Task { await upToSpeedViewModel?.load() }
        }) {
            UpToSpeedView(isPresented: $showUpToSpeed, viewModel: upToSpeedViewModel)
                .environment(appModel)
        }
        .task(id: date) {
            if viewModel == nil {
                viewModel = TodayViewModel(
                    date: date,
                    apiClient: appModel.apiClient,
                    container: appModel.container
                )
            }
            await viewModel?.load()
        }
        .task {
            if upToSpeedViewModel == nil {
                upToSpeedViewModel = UpToSpeedViewModel(apiClient: appModel.apiClient)
            }
            await upToSpeedViewModel?.load()
        }
        .onChange(of: appModel.lastSyncAt) {
            Task { await viewModel?.backgroundRevalidate() }
        }
        .onChange(of: appModel.timezoneRefreshRevision) {
            Task {
                await viewModel?.load()
                await upToSpeedViewModel?.reloadQueue()
            }
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
            HStack(alignment: .top, spacing: SparkSpacing.md) {
                if let firstLine = titleLines.first {
                    heroTitleText(firstLine, index: 0)
                }

                Spacer(minLength: SparkSpacing.md)

                GetUpToSpeedButton(
                    unreadCount: unreadCount,
                    onTap: { showUpToSpeed = true }
                )
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
            .foregroundStyle(index == 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
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
    @ScaledMetric(relativeTo: .caption) private var countMinSize = 24.0
    @ScaledMetric(relativeTo: .caption) private var buttonHeight = 32.0

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text("\(unreadCount)")
                    .font(SparkFonts.display(.caption2, weight: .bold))
                    .foregroundStyle(Color.sparkOnAccent)
                    .padding(.horizontal, 6)
                    .frame(minWidth: countMinSize, minHeight: countMinSize)
                    .background(Color.sparkOnAccent.opacity(0.12), in: .capsule)

                Text("Get Up to Speed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.sparkOnAccent)
            }
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .frame(minHeight: buttonHeight)
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
