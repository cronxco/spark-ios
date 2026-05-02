import SparkKit
import SparkUI
import SwiftData
import SwiftUI
import UIKit

struct TodayView: View {
    let date: Date
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: TodayViewModel?
    @State private var showCheckIn = false
    @State private var showSettings = false
    @State private var showNotifications = false

    @Query(filter: #Predicate<CachedNotification> { !$0.isRead })
    private var unreadNotifications: [CachedNotification]
    @Query private var allIntegrations: [CachedIntegration]

    private var errorIntegrations: [CachedIntegration] {
        let healthy: Set<String> = ["up_to_date", "ok", "active", "syncing", "running"]
        return allIntegrations.filter { !healthy.contains($0.status) }
    }

    var body: some View {
        let snapshot = TodaySnapshot(summary: viewModel?.cached, date: date)

        ZStack {
            TodayBackground(snapshot.timeOfDay)
                .ignoresSafeArea()

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

                    FeedSection(date: date)

                    if !snapshot.hasAnyDomainData {
                        loadingOrEmptyState
                    }

                    HeatmapSection(rows: snapshot.heatmapRows)
                        .padding(.top, SparkSpacing.md)
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.top, deviceSafeAreaTop + SparkSpacing.xl)
                .padding(.bottom, deviceSafeAreaBottom + 66)
            }
            .scrollContentBackground(.hidden)
            .refreshable { await viewModel?.refresh() }

            headerButtons
        }
        .environment(\.colorScheme, snapshot.timeOfDay.prefersDarkTreatment ? .dark : .light)
        .sheet(isPresented: $showCheckIn) {
            let snapshot = TodaySnapshot(summary: viewModel?.cached, date: date)
            if case .pending(let slot) = snapshot.checkInStatus {
                CheckInModalView(slot: slot.rawValue, date: date)
            } else {
                CheckInModalView(slot: SparkTimeOfDay.from(date: .now).rawValue, date: date)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsRootView()
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsInboxView()
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
    }

    // MARK: - Header buttons

    private var headerButtons: some View {
        SparkGlassStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(errorIntegrations.isEmpty ? Color.primary : Color.sparkError)
                        .frame(width: 36, height: 36)
                        .sparkGlass(.circle)
                }
                .accessibilityLabel("Settings")

                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 1, height: 22)

                Button {
                    showNotifications = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(unreadNotifications.isEmpty ? Color.primary : Color.sparkAccent)
                            .frame(width: 36, height: 36)
                            .sparkGlass(.circle)
                        if !unreadNotifications.isEmpty {
                            Circle()
                                .fill(Color.sparkError)
                                .frame(width: 9, height: 9)
                                .offset(x: 3, y: -3)
                        }
                    }
                }
                .accessibilityLabel(
                    unreadNotifications.isEmpty
                        ? "Notifications"
                        : "Notifications, \(unreadNotifications.count) unread"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, deviceSafeAreaTop + SparkSpacing.xl)
        .padding(.trailing, SparkSpacing.lg)
    }

    // MARK: - Hero

    private func hero(snapshot: TodaySnapshot) -> some View {
        let isDark = snapshot.timeOfDay.prefersDarkTreatment
        return VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Text(heroTitle(snapshot: snapshot))
                .font(SparkFonts.display(.title, weight: .bold))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(isDark ? Color.white : Color.primary)
                .accessibilityAddTraits(.isHeader)

            if let subtitle = heroSubtitle(snapshot: snapshot) {
                Text(subtitle)
                    .font(SparkTypography.body)
                    .foregroundStyle(isDark ? Color.white.opacity(0.7) : Color.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func heroTitle(snapshot: TodaySnapshot) -> String {
        if Calendar.current.isDateInToday(date) {
            return "\(snapshot.timeOfDay.greeting),\n\(firstName)."
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday."
        } else if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now),
                  Calendar.current.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow."
        } else {
            return snapshot.dateLabel
        }
    }

    private var deviceSafeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first?
            .keyWindow?.safeAreaInsets.top ?? 59
    }

    private var deviceSafeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first?
            .keyWindow?.safeAreaInsets.bottom ?? 34
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
                message: snapshot.anomalies.first?.displayName
                    ?? snapshot.anomalies.first?.metric
                    ?? "Anomaly detected",
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
