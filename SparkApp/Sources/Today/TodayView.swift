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
            SparkResolvedAppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    hero(snapshot: snapshot)

                    StatStripView(snapshot: snapshot)

                    anomalyPill(for: snapshot)

                    CheckInCard(status: snapshot.checkInStatus) {
                        showCheckIn = true
                    }

                    FeedSection(date: date)

                    if !snapshot.hasAnyDomainData {
                        loadingOrEmptyState
                    }
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.top, SparkSpacing.xl + 40)
                .padding(.bottom, deviceSafeAreaBottom + 66)
            }
            .scrollContentBackground(.hidden)
            .refreshable { await viewModel?.refresh() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                settingsToolbarButton
                notificationsToolbarButton
            }
        }
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

    // MARK: - Toolbar

    private var settingsToolbarButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(errorIntegrations.isEmpty ? Color.primary : Color.sparkError)
        }
        .accessibilityLabel("Settings")
    }

    private var notificationsToolbarButton: some View {
        Button {
            showNotifications = true
        } label: {
            notificationsToolbarLabel
        }
        .accessibilityLabel(
            unreadNotifications.isEmpty
                ? "Notifications"
                : "Notifications, \(unreadNotifications.count) unread"
        )
    }

    @ViewBuilder
    private var notificationsToolbarLabel: some View {
        let icon = Image(systemName: "bell")
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(unreadNotifications.isEmpty ? Color.primary : Color.sparkAccent)

        if unreadNotifications.isEmpty {
            icon
        } else {
            icon.badge(unreadNotifications.count)
        }
    }

    // MARK: - Hero

    private func hero(snapshot: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Text(heroTitle(snapshot: snapshot))
                .font(SparkFonts.display(.title, weight: .bold))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Color.primary)
                .accessibilityAddTraits(.isHeader)

            if let subtitle = heroSubtitle(snapshot: snapshot) {
                Text(subtitle)
                    .font(SparkTypography.body)
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var deviceSafeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first?
            .keyWindow?.safeAreaInsets.bottom ?? 34
    }

    private var firstName: String {
        let name = appModel.profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.split(separator: " ").first.map(String.init) ?? "Your"
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

    private static let dayTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE\nd MMMM yyyy"
        return f
    }()

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
