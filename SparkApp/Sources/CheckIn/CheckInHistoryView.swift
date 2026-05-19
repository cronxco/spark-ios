import SparkKit
import SparkUI
import SwiftData
import SwiftUI

struct CheckInHistoryView: View {
    let apiClient: APIClient
    let container: ModelContainer

    @Environment(\.dismiss) private var dismiss
    @State private var historyVM: CheckInHistoryViewModel
    @State private var selectedCheckIn: CheckInHistorySelection?

    init(apiClient: APIClient, container: ModelContainer, todayViewModel: TodayViewModel) {
        self.apiClient = apiClient
        self.container = container
        _historyVM = State(initialValue: CheckInHistoryViewModel(apiClient: apiClient, container: container))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SparkResolvedAppBackground().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                        overview
                        daysList
                    }
                    .padding(.horizontal, SparkSpacing.lg)
                    .padding(.vertical, SparkSpacing.xl)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Check-in History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
            .sheet(item: $selectedCheckIn, onDismiss: {
                Task { await historyVM.load() }
            }) { selection in
                CheckInHistoryLogSheet(
                    selection: selection,
                    apiClient: apiClient,
                    container: container
                )
            }
            .task { await historyVM.load() }
        }
    }

    private var overview: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                        Text("Last 28 days")
                            .font(SparkTypography.bodyStrong)
                            .foregroundStyle(.primary)
                        Text("\(historyVM.streakCount) day streak")
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(loggedPeriodCount)/56")
                        .font(SparkTypography.monoSmall)
                        .bold()
                        .foregroundStyle(.secondary)
                }

                CheckInHeatmap(days: heatmapDays)
            }
        }
    }

    private var loggedPeriodCount: Int {
        historyVM.days.reduce(0) { total, day in
            total + (day.morning.completed ? 1 : 0) + (day.afternoon.completed ? 1 : 0)
        }
    }

    private var heatmapDays: [CheckInHeatmapDay] {
        historyVM.days.reversed().map { day in
            CheckInHeatmapDay(
                id: day.date,
                date: day.date,
                label: Self.dayNumberLabel(day.date),
                morningScore: day.morning.combined,
                afternoonScore: day.afternoon.combined
            )
        }
    }

    @ViewBuilder
    private var daysList: some View {
        if case .loading = historyVM.state, historyVM.days.isEmpty {
            ForEach(0..<5, id: \.self) { _ in
                LoadingShimmerCard()
            }
        } else if case .error(let msg) = historyVM.state, historyVM.days.isEmpty {
            EmptyState(
                systemImage: "exclamationmark.triangle",
                title: "Couldn't load history",
                message: msg,
                actionTitle: "Retry"
            ) { Task { await historyVM.load() } }
        } else {
            LazyVStack(spacing: SparkSpacing.sm) {
                ForEach(historyVM.days, id: \.date) { day in
                    CheckInHistoryDayRow(day: day) { date, period in
                        selectedCheckIn = CheckInHistorySelection(date: date, period: period)
                    }
                }
            }
        }
    }

    private static func dayNumberLabel(_ key: String) -> String {
        guard let date = Self.dateParser.date(from: key) else { return key }
        return String(Calendar.current.component(.day, from: date))
    }

    fileprivate static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

private struct CheckInHistorySelection: Identifiable {
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

private struct CheckInHistoryLogSheet: View {
    let selection: CheckInHistorySelection
    let apiClient: APIClient
    let container: ModelContainer

    @State private var viewModel: TodayViewModel?

    var body: some View {
        Group {
            if let viewModel {
                CheckInModalView(
                    viewModel: viewModel,
                    date: selection.date,
                    initialPeriod: selection.period
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SparkResolvedAppBackground().ignoresSafeArea())
                    .task {
                        let vm = TodayViewModel(
                            date: selection.date,
                            apiClient: apiClient,
                            container: container
                        )
                        await vm.loadCheckIns()
                        viewModel = vm
                    }
            }
        }
    }
}

private struct CheckInHistoryDayRow: View {
    let day: CheckInHistoryDay
    let onLog: (Date, CheckInPeriod) -> Void

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()

    private var date: Date? {
        CheckInHistoryView.dateParser.date(from: day.date)
    }

    private var dateLabel: String {
        date.map { Self.formatter.string(from: $0) } ?? day.date
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                HStack {
                    Text(dateLabel)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(dayScoreLabel)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(dayScore == nil ? Color.secondary : Color.primary)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                    CheckInPeriodSummaryRow(
                        title: "Morning",
                        status: day.morning.periodStatus,
                        onTap: { log(.morning) }
                    )
                    CheckInPeriodSummaryRow(
                        title: "Afternoon",
                        status: day.afternoon.periodStatus,
                        onTap: { log(.afternoon) }
                    )
                }
            }
        }
    }

    private var dayScoreLabel: String {
        dayScore.map(String.init) ?? "not logged"
    }

    private var dayScore: Int? {
        let scores = [day.morning.combined, day.afternoon.combined].compactMap(\.self)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +)
    }

    private func log(_ period: CheckInPeriod) {
        guard let date else { return }
        onLog(date, period)
    }
}

private extension CheckInHistoryPeriod {
    var periodStatus: PeriodStatus {
        guard completed, let physical, let mental else { return .pending }
        return .completed(physical: physical, mental: mental, notes: notes)
    }
}
