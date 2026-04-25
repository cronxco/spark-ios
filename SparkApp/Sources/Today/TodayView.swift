import SparkKit
import SparkUI
import SwiftData
import SwiftUI

struct TodayView: View {
    let date: Date
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: TodayViewModel?
    @State private var showCheckIn = false

    var body: some View {
        let snapshot = TodaySnapshot(summary: viewModel?.cached, date: date)

        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                hero(snapshot: snapshot)

                anomalyPill(for: snapshot)

                if let health = snapshot.health, health.hasSleep {
                    SleepCard(health: health)
                }

                if shouldShowActivityMoneyRow(snapshot) {
                    HStack(alignment: .top, spacing: SparkSpacing.md) {
                        if let activity = snapshot.activity, activity.hasAny {
                            ActivityCard(activity: activity)
                        }
                        if let money = snapshot.money, money.hasAny {
                            MoneyCard(money: money)
                        }
                    }
                }

                if let media = snapshot.media, media.hasAny {
                    MediaCard(media: media)
                }

                if let next = snapshot.knowledge?.nextCalendarEvent {
                    UpNextCard(event: next)
                }

                CheckInCard(status: snapshot.checkInStatus) {
                    showCheckIn = true
                }

                if !snapshot.hasAnyDomainData {
                    loadingOrEmptyState
                }

                HeatmapSection(rows: snapshot.heatmapRows)
                    .padding(.top, SparkSpacing.md)
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.vertical, SparkSpacing.xl)
        }
        .scrollContentBackground(.hidden)
        .background(TodayBackground(snapshot.timeOfDay))
        .refreshable { await viewModel?.refresh() }
        .sheet(isPresented: $showCheckIn) { CheckInPlaceholderView() }
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
    }

    // MARK: - Hero

    private func hero(snapshot: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Text(snapshot.dateLabel.uppercased())
                .font(SparkTypography.monoSmall)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(heroTitle(snapshot: snapshot))
                .font(SparkFonts.display(.largeTitle, weight: .bold))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let subtitle = heroSubtitle(snapshot: snapshot) {
                Text(subtitle)
                    .font(SparkTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func heroTitle(snapshot: TodaySnapshot) -> String {
        if Calendar.current.isDateInToday(date) {
            return "\(snapshot.timeOfDay.greeting),\n\(firstName)."
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday."
        } else {
            return snapshot.dateLabel
        }
    }

    private var firstName: String {
        // TODO: source from /me endpoint when Settings → Profile lands.
        "Will"
    }

    private func heroSubtitle(snapshot: TodaySnapshot) -> String? {
        var parts: [String] = []
        if let dur = snapshot.health?.sleepDurationMinutes {
            parts.append("slept \(dur / 60)h \(dur % 60)m")
        }
        if let steps = snapshot.activity?.steps {
            parts.append("walked \(formatSteps(steps)) steps")
        }
        if let display = snapshot.money?.spentTodayDisplay {
            parts.append("spent \(display)")
        }
        guard !parts.isEmpty else { return nil }
        return "You " + parts.joined(separator: ", ") + " so far."
    }

    private func formatSteps(_ count: Int) -> String {
        if count >= 1_000 {
            return String(format: "%.1fk", Double(count) / 1_000)
        }
        return String(count)
    }

    // MARK: - Anomaly pill

    @ViewBuilder
    private func anomalyPill(for snapshot: TodaySnapshot) -> some View {
        if snapshot.anomalies.isEmpty {
            StatusPill(.ok, message: "Baselines holding", trailing: "0 anomalies")
        } else {
            StatusPill(
                .warning,
                message: snapshot.anomalies.first?.description ?? "Anomaly detected",
                trailing: "\(snapshot.anomalies.count) anomal\(snapshot.anomalies.count == 1 ? "y" : "ies")"
            )
        }
    }

    private func shouldShowActivityMoneyRow(_ snapshot: TodaySnapshot) -> Bool {
        (snapshot.activity?.hasAny ?? false) || (snapshot.money?.hasAny ?? false)
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

private extension TodaySnapshot {
    var hasAnyDomainData: Bool {
        (health?.hasSleep ?? false)
            || (activity?.hasAny ?? false)
            || (money?.hasAny ?? false)
            || (media?.hasAny ?? false)
            || (knowledge?.hasAny ?? false)
    }
}
