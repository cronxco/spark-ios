import Charts
import SparkKit
import SparkUI
import SwiftUI

struct HealthExploreView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: HealthExploreViewModel?
    @State private var path: [DetailRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    pageHeader
                        .padding(.horizontal, SparkSpacing.lg)

                    if let vm = viewModel {
                        rangePicker(vm)
                            .padding(.horizontal, SparkSpacing.lg)
                    }

                    content
                }
                .padding(.top, SparkSpacing.md)
                .padding(.bottom, SparkSpacing.xl)
            }
            .sparkAppBackground()
            .sparkMainNavigationTitle("Health")
            .sparkDetailDestinations()
            .refreshable {
                await viewModel?.refresh()
            }
            .sparkMainAppToolbar()
        }
        .task {
            if viewModel == nil {
                viewModel = HealthExploreViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    private var pageHeader: some View {
        SparkMainPageHeader(title: "Health", subtitle: headerSubtitle)
    }

    @ViewBuilder
    private var content: some View {
        if let vm = viewModel {
            switch vm.loadState {
            case .idle, .loading:
                if let dashboard = vm.dashboard {
                    dashboardContent(dashboard)
                } else {
                    loadingContent
                        .padding(.horizontal, SparkSpacing.lg)
                }
            case .error(let message):
                if let dashboard = vm.dashboard {
                    dashboardContent(dashboard)
                } else {
                    EmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Couldn't load health",
                        message: message,
                        actionTitle: "Retry"
                    ) { Task { await vm.refresh() } }
                    .padding(.horizontal, SparkSpacing.lg)
                }
            case .loaded:
                if let dashboard = vm.dashboard {
                    dashboardContent(dashboard)
                } else {
                    EmptyState(
                        systemImage: "heart.text.square.fill",
                        title: "No health data",
                        message: "Connected health signals will appear here once Spark receives them."
                    )
                    .padding(.horizontal, SparkSpacing.lg)
                }
            }
        } else {
            loadingContent
                .padding(.horizontal, SparkSpacing.lg)
        }
    }

    private func dashboardContent(_ dashboard: HealthDashboard) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.lg) {
            heroSection(dashboard)
                .padding(.horizontal, SparkSpacing.lg)

            fitnessSummary(dashboard.fitness.today)
                .padding(.horizontal, SparkSpacing.lg)

            if !dashboard.fitness.workouts.isEmpty {
                workoutsSection(dashboard.fitness.workouts)
                    .padding(.horizontal, SparkSpacing.lg)
            }

            if !dashboard.bodyMetrics.isEmpty {
                bodyMetricsSection(dashboard.bodyMetrics)
                    .padding(.horizontal, SparkSpacing.lg)
            }

            if !dashboard.trends.isEmpty {
                trendsSection(dashboard.trends)
                    .padding(.horizontal, SparkSpacing.lg)
            }

            if !dashboard.insights.isEmpty {
                insightsSection(dashboard.insights)
                    .padding(.horizontal, SparkSpacing.lg)
            }

            if let vm = viewModel, !vm.rawFeedEntries.isEmpty {
                RawFeedJSONView(entries: vm.rawFeedEntries)
                    .padding(.horizontal, SparkSpacing.lg)
            }
        }
    }

    private func rangePicker(_ vm: HealthExploreViewModel) -> some View {
        HStack(spacing: 4) {
            ForEach(HealthExploreViewModel.DashboardRange.allCases, id: \.self) { range in
                let isSelected = vm.selectedRange == range
                Button {
                    Task { await vm.selectRange(range) }
                } label: {
                    Text(range.label)
                        .font(SparkTypography.monoSmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? Color.sparkTextPrimary : .secondary)
                        .frame(minWidth: 42)
                        .padding(.vertical, SparkSpacing.xs + 2)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color.domainHealth)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(range.label) range")
            }
        }
        .padding(4)
        .sparkGlass(.capsule)
    }

    @ViewBuilder
    private func heroSection(_ dashboard: HealthDashboard) -> some View {
        if let hero = dashboard.hero {
            let tint = Color.domainHealth
            GlassCard(radius: 28, padding: SparkSpacing.xl, tint: tint.opacity(0.08)) {
                VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                    HStack(alignment: .top, spacing: SparkSpacing.md) {
                        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                            HStack(spacing: 6) {
                                Label(hero.kind.replacingOccurrences(of: "_", with: " ").capitalized, systemImage: icon(forHeroKind: hero.kind))
                                    .font(SparkTypography.bodyStrong)
                                    .foregroundStyle(tint)
                                AnomalyDot(active: hero.status == "critical" || hero.status == "low")
                            }

                            Text(hero.title)
                                .font(SparkFonts.display(.title2, weight: .bold))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(hero.subtitle)
                                .font(SparkTypography.bodySmall)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: SparkSpacing.sm)

                        VStack(spacing: SparkSpacing.xs) {
                            if let score = hero.score {
                                Text("\(score)")
                                    .font(SparkFonts.display(size: 72))
                                    .foregroundStyle(tint)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.55)
                                Text(hero.status.replacingOccurrences(of: "_", with: " "))
                                    .font(SparkTypography.monoSmall)
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "heart.text.square.fill")
                                    .font(.system(size: 34, weight: .semibold))
                                    .foregroundStyle(tint)
                                    .frame(width: 62, height: 62)
                                    .sparkGlass(.circle, tint: tint.opacity(0.18))
                            }
                        }
                        .frame(minWidth: 88)
                    }

                    if !hero.factors.isEmpty {
                        FlowLayout(spacing: SparkSpacing.xs) {
                            ForEach(hero.factors) { factor in
                                factorChip(factor)
                            }
                        }
                    }
                }
                .frame(minHeight: 198, alignment: .topLeading)
                .contentShape(RoundedRectangle(cornerRadius: 28))
            }
            .onTapGesture {
                if let id = hero.primaryEventId {
                    path.append(.event(id: id))
                }
            }
        } else {
            GlassCard(radius: 28, padding: SparkSpacing.xl, tint: Color.domainHealth.opacity(0.08)) {
                HStack(spacing: SparkSpacing.md) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.domainHealth)
                        .frame(width: 54, height: 54)
                        .sparkGlass(.circle, tint: Color.domainHealth.opacity(0.16))

                    VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                        Text("Health signals are steady")
                            .font(SparkTypography.bodyStrong)
                            .foregroundStyle(.primary)
                        Text("Readiness will appear here when Spark has current recovery data.")
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func factorChip(_ factor: HealthDashboard.Hero.Factor) -> some View {
        HStack(spacing: SparkSpacing.xs) {
            Text(factor.label)
                .lineLimit(1)
                .foregroundStyle(.secondary)
            if let value = factor.value {
                Text(formatSigned(value, unit: factor.unit))
                    .font(SparkTypography.monoSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.domainHealth)
            }
        }
        .font(SparkTypography.caption)
        .padding(.horizontal, SparkSpacing.sm)
        .padding(.vertical, SparkSpacing.xs + 1)
        .sparkGlass(.capsule)
    }

    private func fitnessSummary(_ today: HealthDashboard.Today) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            sectionHeader("Today", icon: "figure.run", tint: Color.domainActivity)

            LazyVGrid(columns: metricColumns, spacing: SparkSpacing.sm) {
                if let steps = today.steps {
                    fitnessTile("Steps", icon: "figure.walk", quantity: steps, tint: Color.domainActivity)
                }
                if let distance = today.distance {
                    fitnessTile("Distance", icon: "map.fill", quantity: distance, tint: Color.sparkOcean)
                }
                if let activeEnergy = today.activeEnergy {
                    fitnessTile("Active", icon: "flame.fill", quantity: activeEnergy, tint: Color.spark500)
                }
                if let exercise = today.exercise {
                    fitnessTile("Exercise", icon: "timer", quantity: exercise, tint: Color.domainHealth)
                }
                if let stand = today.stand {
                    fitnessTile("Stand", icon: "arrow.up.circle.fill", quantity: stand, tint: Color.sparkInfo)
                }
                fitnessTile(
                    "Workouts",
                    icon: "bolt.heart.fill",
                    value: "\(today.workoutCount)",
                    unit: today.workoutCount == 1 ? "session" : "sessions",
                    delta: nil,
                    tint: Color.domainActivity
                )
            }
        }
    }

    private var metricColumns: [GridItem] {
        [GridItem(.flexible(), spacing: SparkSpacing.sm), GridItem(.flexible(), spacing: SparkSpacing.sm)]
    }

    private func fitnessTile(
        _ title: String,
        icon: String,
        quantity: HealthDashboard.Quantity,
        tint: Color
    ) -> some View {
        fitnessTile(
            title,
            icon: icon,
            value: formatNumber(quantity.value, unit: quantity.unit),
            unit: unitLabel(quantity.unit),
            delta: quantity.vsBaselinePct,
            tint: tint
        )
    }

    private func fitnessTile(
        _ title: String,
        icon: String,
        value: String,
        unit: String?,
        delta: Double?,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(spacing: SparkSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
                Text(value)
                    .font(SparkFonts.display(size: 26))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                if let unit {
                    Text(unit)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let delta {
                baselineDelta(delta)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .padding(SparkSpacing.md)
        .sparkGlass(.roundedRect(18), tint: tint.opacity(0.08))
    }

    private func workoutsSection(_ workouts: [HealthDashboard.Workout]) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            sectionHeader("Workouts", icon: "bolt.heart.fill", tint: Color.domainActivity)

            VStack(spacing: SparkSpacing.sm) {
                ForEach(workouts) { workout in
                    Button {
                        path.append(.event(id: workout.eventId))
                    } label: {
                        workoutRow(workout)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func workoutRow(_ workout: HealthDashboard.Workout) -> some View {
        GlassCard(radius: 18, padding: SparkSpacing.md) {
            HStack(spacing: SparkSpacing.md) {
                DomainGlyph(icon: workout.kind == "strength" ? "dumbbell.fill" : "figure.run", tint: workoutTint(workout), size: 42)

                VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                    HStack(spacing: SparkSpacing.xs) {
                        Text(workout.title)
                            .font(SparkTypography.bodyStrong)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if workout.routeAvailable == true {
                            Image(systemName: "map.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.sparkOcean)
                                .accessibilityLabel("Route available")
                        }
                    }
                    Text(workoutSubtitle(workout))
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: SparkSpacing.xs)

                HStack(spacing: SparkSpacing.sm) {
                    ForEach(workoutCompactStats(workout)) { stat in
                        compactWorkoutStat(stat)
                    }
                }
            }
        }
    }

    private func cardioDetails(_ workout: HealthDashboard.Workout) -> some View {
        HStack(spacing: SparkSpacing.sm) {
            workoutStat("Time", value: formatDuration(workout.durationSeconds))
            if let energy = workout.energyKcal {
                workoutStat("Energy", value: "\(formatNumber(energy, unit: "kcal")) kcal")
            }
            if let distance = workout.distance {
                workoutStat("Distance", value: "\(formatNumber(distance.value, unit: distance.unit)) \(distance.unit ?? "")")
            }
        }
    }

    private func strengthDetails(_ workout: HealthDashboard.Workout) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(spacing: SparkSpacing.sm) {
                if let volume = workout.volume {
                    workoutStat("Volume", value: "\(formatNumber(volume.value, unit: volume.unit)) \(volume.unit ?? "")")
                }
                workoutStat("Time", value: formatDuration(workout.durationSeconds))
            }

            if let exercises = workout.exercises, !exercises.isEmpty {
                VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                    ForEach(exercises.prefix(3)) { exercise in
                        HStack(spacing: SparkSpacing.xs) {
                            Text(exercise.name)
                                .font(SparkTypography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: SparkSpacing.sm)
                            Text("\(exercise.sets) sets")
                                .font(SparkTypography.monoSmall)
                                .foregroundStyle(.secondary)
                            if let volume = exercise.volume {
                                Text("\(formatNumber(volume.value, unit: volume.unit)) \(volume.unit ?? "")")
                                    .font(SparkTypography.monoSmall)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func workoutStat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
            Text(label)
                .font(SparkTypography.caption)
                .foregroundStyle(.tertiary)
            Text(value.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(SparkTypography.monoSmall)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bodyMetricsSection(_ metrics: [HealthDashboard.BodyMetric]) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            sectionHeader("Body Metrics", icon: "waveform.path.ecg", tint: Color.domainHealth)

            LazyVGrid(columns: metricColumns, spacing: SparkSpacing.sm) {
                ForEach(metrics) { metric in
                    Button {
                        path.append(.metric(identifier: metric.id))
                    } label: {
                        bodyMetricTile(metric)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func bodyMetricTile(_ metric: HealthDashboard.BodyMetric) -> some View {
        let tint = Color.domainHealth
        return VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(spacing: SparkSpacing.xs) {
                DomainGlyph(icon: icon(forMetric: metric.label), tint: tint, size: 20)
                Text(metric.label)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
                Text(formatNumber(metric.value, unit: metric.unit))
                    .font(SparkFonts.display(size: 26))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                if let unit = unitLabel(metric.unit) {
                    Text(unit)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let delta = metric.vsBaselinePct {
                baselineDelta(delta)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .padding(SparkSpacing.md)
        .sparkGlass(.roundedRect(18))
        .overlay(alignment: .topTrailing) {
            AnomalyDot(active: metric.status == "critical")
                .padding(8)
        }
    }

    private func trendsSection(_ trends: [HealthDashboard.Trend]) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            sectionHeader("Trends", icon: "chart.line.uptrend.xyaxis", tint: Color.sparkOcean)

            VStack(spacing: SparkSpacing.sm) {
                ForEach(trends) { trend in
                    Button {
                        path.append(.metric(identifier: trend.metric))
                    } label: {
                        trendCard(trend)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func trendCard(_ trend: HealthDashboard.Trend) -> some View {
        GlassCard(radius: SparkRadii.lg, padding: SparkSpacing.md) {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                        Text(trend.label ?? trendTitle(trend))
                            .font(SparkTypography.bodyStrong)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let mean = trend.summary?.mean {
                            Text("Avg \(formatNumber(mean, unit: trend.unit)) \(trend.unit ?? "")")
                                .font(SparkTypography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: SparkSpacing.sm)
                    if let latest = trend.dailyValues.last?.value {
                        Text(formatNumber(latest, unit: trend.unit))
                            .font(SparkFonts.display(size: 34))
                            .foregroundStyle(trendTint(trend))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }

                DashboardTrendChart(trend: trend, tint: trendTint(trend))
                    .frame(height: 76)
            }
        }
    }

    private func insightsSection(_ insights: [HealthDashboard.Insight]) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            sectionHeader("Flint Insights", icon: "sparkles", tint: Color.sparkAccent)

            VStack(spacing: SparkSpacing.sm) {
                ForEach(insights) { insight in
                    Button {
                        path.append(.event(id: insight.eventId))
                    } label: {
                        GlassCard(radius: SparkRadii.lg, padding: SparkSpacing.md) {
                            HStack(alignment: .top, spacing: SparkSpacing.md) {
                                DomainGlyph(icon: "sparkles", tint: Color.sparkAccent, size: 34)

                                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                                    HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
                                        Text(insight.title)
                                            .font(SparkTypography.bodyStrong)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Spacer(minLength: SparkSpacing.sm)
                                        Text(timeLabel(insight.time))
                                            .font(SparkTypography.monoSmall)
                                            .foregroundStyle(.secondary)
                                    }

                                    if let content = insight.content, !content.isEmpty {
                                        Text(content)
                                            .font(SparkTypography.bodySmall)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(4)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.lg) {
            LoadingShimmerCard().frame(height: 220)
            LazyVGrid(columns: metricColumns, spacing: SparkSpacing.sm) {
                LoadingShimmerCard().frame(height: 96)
                LoadingShimmerCard().frame(height: 96)
                LoadingShimmerCard().frame(height: 96)
                LoadingShimmerCard().frame(height: 96)
            }
            LoadingShimmerCard().frame(height: 112)
            LoadingShimmerCard().frame(height: 168)
        }
    }

    private func sectionHeader(_ title: String, icon: String, tint: Color) -> some View {
        SparkSectionHeader(title: title, icon: icon, tint: tint)
    }

    private func baselineDelta(_ value: Double) -> some View {
        HStack(spacing: 3) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text("\(value >= 0 ? "+" : "")\(formatCompact(value))%")
                .font(SparkTypography.monoSmall)
        }
        .foregroundStyle(value >= 0 ? Color.sparkSuccess : Color.sparkWarning)
    }

    private var headerSubtitle: String {
        guard let vm = viewModel else { return "Loading health" }
        switch vm.loadState {
        case .loaded:
            guard let dashboard = vm.dashboard else { return "No health data yet" }
            return lastSyncedSubtitle(for: dashboard)
        case .loading:
            if let dashboard = vm.dashboard {
                return lastSyncedSubtitle(for: dashboard)
            }
            return "Loading health"
        case .error:
            return "Health data unavailable"
        case .idle:
            return "Loading health"
        }
    }

    private func lastSyncedSubtitle(for dashboard: HealthDashboard) -> String {
        guard let lastEventTime = dashboard.syncStatus.values.compactMap(\.lastEventTime).max() else {
            return "No health data synced yet"
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(lastEventTime) {
            return "Last synced today at \(SparkDateFormatting.shortTime(lastEventTime))"
        }
        if calendar.isDateInYesterday(lastEventTime) {
            return "Last synced yesterday at \(SparkDateFormatting.shortTime(lastEventTime))"
        }
        return "Last synced \(Self.syncDateFormatter.string(from: lastEventTime))"
    }

    private func workoutSubtitle(_ workout: HealthDashboard.Workout) -> String {
        let source = workout.source == "apple_health" ? "Apple Health" : workout.source.capitalized
        return "\(source) - \(timeLabel(workout.start))"
    }

    private func workoutTint(_ workout: HealthDashboard.Workout) -> Color {
        workout.kind == "strength" ? Color.domainHealth : Color.domainActivity
    }

    private func trendTint(_ trend: HealthDashboard.Trend) -> Color {
        switch trend.service {
        case "oura": Color.sparkOcean
        case "hevy": Color.domainHealth
        case "apple_health" where trend.action.contains("energy"): Color.spark500
        case "apple_health": Color.domainActivity
        default: Color.sparkInfo
        }
    }

    private func icon(forHeroKind kind: String) -> String {
        switch kind {
        case "readiness": "heart.text.square.fill"
        case "sleep_score": "moon.zzz.fill"
        default: "heart.fill"
        }
    }

    private func icon(forMetric label: String) -> String {
        let lower = label.lowercased()
        if lower.contains("sleep") { return "moon.zzz.fill" }
        if lower.contains("hrv") { return "waveform.path.ecg" }
        if lower.contains("heart") { return "heart.fill" }
        if lower.contains("temperature") { return "thermometer.medium" }
        if lower.contains("stress") { return "bolt.trianglebadge.exclamationmark.fill" }
        if lower.contains("vo2") { return "lungs.fill" }
        return "heart.text.square.fill"
    }

    private func trendTitle(_ trend: HealthDashboard.Trend) -> String {
        let stripped = trend.action.hasPrefix("had_") ? String(trend.action.dropFirst(4)) : trend.action
        return stripped.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
    }

    private func formatNumber(_ value: Double?, unit: String?) -> String {
        guard let value else { return "--" }
        if abs(value) >= 1000, unit != "kcal" {
            return String(format: "%.1fk", value / 1000)
        }
        if unit == "steps" || unit == "hours" || unit == "min" || unit == "kcal" {
            return String(Int(value.rounded()))
        }
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: value < 10 ? "%.2f" : "%.1f", value)
    }

    private func formatCompact(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private func formatSigned(_ value: Double, unit: String?) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(formatNumber(value, unit: unit))\(unit == "percent" ? "%" : "")"
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private func unitLabel(_ unit: String?) -> String? {
        switch unit {
        case nil, "steps", "percent":
            nil
        case "hours":
            "h"
        default:
            unit
        }
    }

    private func timeLabel(_ date: Date) -> String {
        SparkDateFormatting.shortTime(date)
    }

    private struct WorkoutStat: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    private func workoutCompactStats(_ workout: HealthDashboard.Workout) -> [WorkoutStat] {
        var stats = [WorkoutStat(label: "Time", value: formatDuration(workout.durationSeconds))]
        if let energy = workout.energyKcal {
            stats.append(WorkoutStat(label: "Energy", value: "\(formatNumber(energy, unit: "kcal")) kcal"))
        }
        if let distance = workout.distance {
            stats.append(WorkoutStat(label: "Distance", value: "\(formatNumber(distance.value, unit: distance.unit)) \(unitLabel(distance.unit) ?? distance.unit ?? "")"))
        } else if let volume = workout.volume {
            stats.append(WorkoutStat(label: "Volume", value: "\(formatNumber(volume.value, unit: volume.unit)) \(unitLabel(volume.unit) ?? volume.unit ?? "")"))
        }
        return Array(stats.prefix(3))
    }

    private func compactWorkoutStat(_ stat: WorkoutStat) -> some View {
        VStack(alignment: .trailing, spacing: SparkSpacing.xxs) {
            Text(stat.label)
                .font(SparkTypography.caption)
                .foregroundStyle(.tertiary)
            Text(stat.value.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(SparkTypography.monoSmall)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minWidth: 42, alignment: .trailing)
    }

    private static let syncDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct DashboardTrendChart: View {
    let trend: HealthDashboard.Trend
    let tint: Color

    private var points: [Point] {
        trend.dailyValues.compactMap { value in
            guard let date = Self.dateFormatter.date(from: value.date), let y = value.value else { return nil }
            return Point(date: date, value: y, isAnomaly: value.isAnomaly == true)
        }
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint.opacity(0.28), tint.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }

            if let baseline = trend.baseline?.mean {
                RuleMark(y: .value("Baseline", baseline))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    private struct Point: Identifiable {
        let date: Date
        let value: Double
        let isAnomaly: Bool
        var id: Date { date }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
