import SparkKit
import SparkUI
import SwiftData
import SwiftUI

struct CheckInHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var historyVM: CheckInHistoryViewModel

    init(apiClient: APIClient, container: ModelContainer, todayViewModel: TodayViewModel) {
        _historyVM = State(initialValue: CheckInHistoryViewModel(apiClient: apiClient, container: container))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SparkResolvedAppBackground().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                        streakHeader
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
            .task { await historyVM.load() }
        }
    }

    // MARK: - Streak header

    private var streakHeader: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                    Text("\(historyVM.streakCount)")
                        .font(.custom(SparkFonts.displayPostScriptName, size: 40, relativeTo: .largeTitle))
                        .foregroundStyle(Color.sparkAccent)
                    Text("day streak")
                        .font(SparkTypography.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(historyVM.streakCount > 0 ? Color.sparkAccent : Color.secondary.opacity(0.4))
            }
        }
    }

    // MARK: - Days list

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
                    CheckInHistoryDayRow(day: day)
                }
            }
        }
    }
}

// MARK: - Day row

private struct CheckInHistoryDayRow: View {
    let day: CheckInHistoryDay

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()

    private var dateLabel: String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        if let date = parser.date(from: day.date) {
            return Self.formatter.string(from: date)
        }
        return day.date
    }

    var body: some View {
        GlassCard {
            HStack {
                Text(dateLabel)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: SparkSpacing.sm) {
                    PeriodChip(label: "AM", period: day.morning)
                    PeriodChip(label: "PM", period: day.afternoon)
                }
            }
        }
    }
}

private struct PeriodChip: View {
    let label: String
    let period: CheckInHistoryPeriod

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(SparkTypography.monoSmall)
            if period.completed, let combined = period.combined {
                Text("\(combined)")
                    .font(SparkTypography.monoSmall)
                    .bold()
            }
        }
        .foregroundStyle(period.completed ? Color.sparkAccent : .secondary)
        .padding(.horizontal, SparkSpacing.sm)
        .padding(.vertical, 3)
        .background(period.completed ? Color.sparkAccent.opacity(0.12) : Color.primary.opacity(0.05))
        .clipShape(.capsule)
        .overlay {
            if !period.completed {
                Capsule().strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            }
        }
        .accessibilityLabel(period.completed ? "\(label) logged, \(period.combined ?? 0) out of 10" : "\(label) not logged")
    }
}
