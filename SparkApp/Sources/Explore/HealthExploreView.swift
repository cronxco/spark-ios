import SparkKit
import SparkUI
import SwiftUI

/// Explore's Health section: one hero (readiness), then today's activity,
/// workouts, body readings, trends and Flint's notes, each on an opaque
/// content surface (`docs/design-language.md` sections 5.3, 7 and 8).
///
/// The range picker belongs to Trends, the only part it changes.
struct HealthExploreView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: HealthExploreViewModel?
    @Binding var path: [DetailRoute]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                content
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, SparkSpacing.md)
            .padding(.bottom, SparkSpacing.xxl)
        }
        .refreshable {
            await viewModel?.refresh()
        }
        .task {
            if viewModel == nil {
                viewModel = HealthExploreViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let vm = viewModel, let dashboard = vm.dashboard {
            dashboardContent(dashboard, vm: vm)
        } else if let vm = viewModel, case .error(let message) = vm.loadState {
            EmptyState(
                systemImage: "exclamationmark.triangle.fill",
                title: "Couldn't load health",
                message: message,
                actionTitle: "Retry"
            ) { Task { await vm.refresh() } }
        } else if let vm = viewModel, case .loaded = vm.loadState {
            EmptyState(
                systemImage: "heart.text.square.fill",
                title: "No health data yet",
                message: "Connect Oura or Apple Health and your readings will appear here."
            )
        } else {
            loadingContent
        }
    }

    @ViewBuilder
    private func dashboardContent(_ dashboard: HealthDashboard, vm: HealthExploreViewModel) -> some View {
        let heroMetric = dashboard.bodyMetrics.first { $0.eventId == dashboard.hero?.primaryEventId }
        let tiles = HealthDisplay.activityTiles(dashboard.fitness.today, trends: dashboard.trends)
        let bodyRows = dashboard.bodyMetrics.filter { $0.eventId != heroMetric?.eventId }.map(HealthDisplay.bodyRow)
        let trends = dashboard.trends.compactMap { HealthDisplay.trendCard($0, days: vm.selectedRange.days) }

        if let note = freshnessNote(dashboard) {
            Text(note)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
        }

        if let hero = dashboard.hero {
            HealthHeroCard(hero: hero, metric: heroMetric) {
                if let id = hero.primaryEventId { path.append(.event(id: id)) }
            }
        }

        if !tiles.isEmpty {
            section(isToday(dashboard) ? "Activity so far today" : "Activity", icon: .activity) {
                HealthActivityGrid(tiles: tiles) { tile in
                    if let id = tile.metricIdentifier { path.append(.metric(identifier: id)) }
                }
            }
        }

        if !dashboard.fitness.workouts.isEmpty {
            section("Workouts", count: dashboard.fitness.workouts.count, icon: .workout) {
                HealthRowList(items: dashboard.fitness.workouts) { workout in
                    path.append(.event(id: workout.eventId))
                } row: { workout in
                    HealthWorkoutRow(workout: workout)
                }
            }
        }

        if !bodyRows.isEmpty {
            section("Body", count: bodyRows.count, icon: .health) {
                HealthRowList(items: bodyRows) { row in
                    path.append(.metric(identifier: row.id))
                } row: { row in
                    HealthBodyRow(row: row)
                }
            }
        }

        if !dashboard.trends.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                HStack(alignment: .center, spacing: SparkSpacing.sm) {
                    SparkDetailSectionHeader("Trends", icon: .chart)
                    RangeChipBar(
                        HealthExploreViewModel.DashboardRange.allCases,
                        selected: vm.selectedRange,
                        tint: Color.domainHealth,
                        label: \.label
                    ) { range in
                        Task { await vm.selectRange(range) }
                    }
                    .fixedSize()
                }
                ForEach(trends) { card in
                    Button {
                        path.append(.metric(identifier: card.id))
                    } label: {
                        HealthTrendCard(card: card)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        if !dashboard.insights.isEmpty {
            section("From Flint", icon: .flint) {
                VStack(spacing: SparkSpacing.md) {
                    ForEach(dashboard.insights) { insight in
                        Button {
                            path.append(.event(id: insight.eventId))
                        } label: {
                            HealthInsightCard(insight: insight)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func section<Content: View>(
        _ title: String,
        count: Int? = nil,
        icon: SparkIcon,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            SparkDetailSectionHeader(title, count: count, icon: icon)
            content()
        }
    }

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xl) {
            LoadingShimmerCard().frame(height: 320)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: SparkSpacing.md), GridItem(.flexible())], spacing: SparkSpacing.md) {
                ForEach(0..<4, id: \.self) { _ in LoadingShimmerCard().frame(height: 150) }
            }
            LoadingShimmerCard().frame(height: 240)
        }
        .accessibilityLabel("Loading health")
    }

    private func isToday(_ dashboard: HealthDashboard) -> Bool {
        dashboard.date == Self.dayFormatter.string(from: .now)
    }

    /// Said only when something is missing: Apple Health sends the day in
    /// pieces, so a partial day is named rather than shown as complete
    /// (section 9).
    private func freshnessNote(_ dashboard: HealthDashboard) -> String? {
        guard dashboard.syncStatus["apple_health"]?.coverage == "partial" else { return nil }
        if let last = dashboard.syncStatus["apple_health"]?.lastEventTime {
            let relative = RelativeDateTimeFormatter().localizedString(for: last, relativeTo: .now)
            return "Apple Health last sent data \(relative)"
        }
        return "Apple Health hasn't sent today's data yet"
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Hero

/// The page's one hero: the readiness event as a ring, with the lowest
/// contributor blocks as bars under it. Opens the readiness event.
private struct HealthHeroCard: View {
    let hero: HealthDashboard.Hero
    let metric: HealthDashboard.BodyMetric?
    let open: () -> Void

    private var tint: Color { .domainHealth }

    private var label: String {
        metric?.label ?? hero.kind.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Contributors are 0–100; the lowest are the ones holding the score back.
    private var contributors: [HealthDashboard.Hero.Factor] {
        hero.factors
            .filter { ($0.value ?? -1) >= 0 && ($0.value ?? 101) <= 100 }
            .sorted { ($0.value ?? 0) < ($1.value ?? 0) }
            .prefix(4)
            .map { $0 }
    }

    private var comparison: MetricComparison? {
        guard let metric, let value = metric.value else { return nil }
        let action = HealthDisplay.parts(of: metric.id).action
        return HealthDisplay.comparison(
            value: value,
            vsBaselinePct: metric.vsBaselinePct,
            higherIsBetter: HealthDisplay.kind(action: action).higherIsBetter,
            status: metric.status
        ) { HealthDisplay.whole($0) }
    }

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                HStack(spacing: SparkSpacing.sm) {
                    SparkGlyph(.score, size: 13, relativeTo: .caption)
                        .foregroundStyle(tint)
                    Text(label)
                        .font(SparkTypography.captionStrong)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: SparkSpacing.sm)
                    Text("Today")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: SparkSpacing.md) {
                    if let score = hero.score {
                        ScoreRing(
                            fraction: Double(score) / 100,
                            text: "\(score)",
                            tint: tint,
                            diameter: 128,
                            threshold: 0.85,
                            valueColor: .sparkHero(domain: "health")
                        )
                    }
                    Text(hero.title)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                if !contributors.isEmpty {
                    VStack(alignment: .leading, spacing: SparkSpacing.md) {
                        Text("Lowest contributors")
                            .font(SparkTypography.captionStrong)
                            .foregroundStyle(.secondary)
                        ForEach(contributors) { factor in
                            SparkDetailScoreBar(label: factor.label, value: factor.value ?? 0, tint: tint)
                        }
                    }
                }

                if let comparison {
                    HealthComparisonLine(comparison: comparison)
                }
            }
            .padding(SparkSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sparkContentSurface(radius: SparkRadii.lg)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the \(label.lowercased()) event")
    }
}

// MARK: - Activity

/// Today's activity as compact cards: value, against-the-mean bar, one
/// comparison line (sections 7.2 and 8). Two across, one at large text sizes.
private struct HealthActivityGrid: View {
    let tiles: [HealthDisplay.ActivityTile]
    let open: (HealthDisplay.ActivityTile) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        let count = dynamicTypeSize >= .xxxLarge ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: SparkSpacing.md), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: SparkSpacing.md) {
            ForEach(tiles) { tile in
                Button {
                    open(tile)
                } label: {
                    HealthActivityCard(tile: tile)
                }
                .buttonStyle(.plain)
                .disabled(tile.metricIdentifier == nil)
            }
        }
    }
}

private struct HealthActivityCard: View {
    let tile: HealthDisplay.ActivityTile

    private var tint: Color { .domainActivity }

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(spacing: SparkSpacing.xs) {
                SparkGlyph(tile.icon, size: 13, relativeTo: .caption)
                    .foregroundStyle(tint)
                Text(tile.label)
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xxs) {
                Text(tile.value)
                    .font(SparkTypography.compactValue)
                    .foregroundStyle(Color.sparkHero(domain: "activity"))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit = tile.unit {
                    Text(unit)
                        .font(SparkTypography.compactUnit)
                        .foregroundStyle(.secondary)
                }
            }

            if tile.bar.fill != nil {
                MeanBar(geometry: tile.bar, tint: tint)
            }

            Spacer(minLength: 0)

            if let comparison = tile.comparison {
                HealthComparisonLine(comparison: comparison, font: SparkTypography.caption)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(SparkSpacing.md)
        .sparkContentSurface(radius: SparkRadii.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tile.accessibilityLabel)
    }
}

// MARK: - Rows

/// Rows on one content surface, each opening its item (section 12.3).
private struct HealthRowList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    let open: (Item) -> Void
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider().padding(.leading, SparkSpacing.lg + 30 + SparkSpacing.md)
                }
                Button {
                    open(item)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                        row(item)
                        SparkGlyph(.forward, size: 11, relativeTo: .caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, SparkSpacing.lg)
                    .padding(.vertical, SparkSpacing.md)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .sparkContentSurface(radius: SparkRadii.lg)
    }
}

private struct HealthWorkoutRow: View {
    let workout: HealthDashboard.Workout

    var body: some View {
        HStack(alignment: .top, spacing: SparkSpacing.md) {
            DomainGlyph(HealthDisplay.workoutIcon(workout), tint: .domainActivity, size: 30)
            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                    Text(workout.title)
                        .font(SparkTypography.bodyStrong)
                        .lineLimit(1)
                    Spacer(minLength: SparkSpacing.sm)
                    SparkTimeText(workout.start)
                }
                HealthFactLine(facts: HealthDisplay.workoutFacts(workout))
            }
        }
    }
}

private struct HealthBodyRow: View {
    let row: HealthDisplay.BodyRow

    var body: some View {
        HStack(alignment: .top, spacing: SparkSpacing.md) {
            DomainGlyph(row.icon, tint: row.isAnomaly ? .domainAnomaly : .domainHealth, size: 30)
            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                    Text(row.label)
                        .font(SparkTypography.bodyStrong)
                        .lineLimit(1)
                    Spacer(minLength: SparkSpacing.sm)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(row.value)
                            .font(SparkTypography.bodyStrong)
                            .monospacedDigit()
                        if let unit = row.unit {
                            Text(unit)
                                .font(SparkTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let comparison = row.comparison {
                    HealthComparisonLine(comparison: comparison, font: SparkTypography.caption)
                } else {
                    Text(row.context)
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }
}

/// Facts side by side with a gap, wrapping when they run out of room
/// (section 9). No dividers.
private struct HealthFactLine: View {
    let facts: [String]

    var body: some View {
        FlowLayout(spacing: SparkSpacing.md) {
            ForEach(facts, id: \.self) { fact in
                Text(fact)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Trends

private struct HealthTrendCard: View {
    let card: HealthDisplay.TrendCard

    private var tint: Color { EntityPresentation.tint(domain: card.domain) }

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(spacing: SparkSpacing.xs) {
                SparkGlyph(card.icon, size: 13, relativeTo: .caption)
                    .foregroundStyle(tint)
                Text(card.label)
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(.secondary)
                Spacer(minLength: SparkSpacing.sm)
                Text(card.rangeLabel)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xxs) {
                Text(card.average)
                    .font(SparkTypography.compactValue)
                    .foregroundStyle(Color.sparkHero(domain: card.domain))
                    .monospacedDigit()
                if let unit = card.unit {
                    Text(unit)
                        .font(SparkTypography.compactUnit)
                        .foregroundStyle(.secondary)
                }
            }

            DailyTrendChart(
                points: card.points,
                style: card.style,
                tint: tint,
                usualRange: card.usualRange,
                latestLabel: card.points.count <= 31 ? card.latest : nil
            )

            if let comparison = card.comparison {
                HealthComparisonLine(comparison: comparison, font: SparkTypography.caption)
            }
        }
        .padding(SparkSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkContentSurface(radius: SparkRadii.lg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Flint

/// A Flint note on the generated surface (section 3.5): the sparkles glyph
/// and the word "Flint" in the eyebrow, the text in the body face.
private struct HealthInsightCard: View {
    let insight: HealthDashboard.Insight

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(spacing: SparkSpacing.xs) {
                SparkGlyph(.flint, size: 13, relativeTo: .caption)
                Text("Flint")
                    .font(SparkTypography.captionStrong)
                Spacer(minLength: SparkSpacing.sm)
                SparkTimeText(insight.time)
            }
            .foregroundStyle(.secondary)

            Text(insight.title)
                .font(SparkTypography.bodyStrong)
                .foregroundStyle(.primary)

            if let content = insight.content, !content.isEmpty {
                Text(content)
                    .font(SparkTypography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SparkSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkGeneratedSurface(radius: SparkRadii.lg)
    }
}

// MARK: - Comparison

/// Arrow, amount, direction and window (section 3.4). The arrow carries the
/// polarity colour; the words stay secondary.
private struct HealthComparisonLine: View {
    let comparison: MetricComparison
    var font: Font = SparkTypography.bodySmall

    private var colour: Color {
        switch comparison.isGood {
        case true?: .sparkSuccess
        case false?: .sparkError
        case nil: .secondary
        }
    }

    private var icon: SparkIcon? {
        switch comparison.direction {
        case .up?: .increase
        case .down?: .decrease
        case .steady?: .steady
        case nil: nil
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
            if let icon {
                SparkGlyph(icon, size: 11, relativeTo: .caption)
                    .foregroundStyle(colour)
            }
            Text(comparison.text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(font)
        .accessibilityElement(children: .combine)
    }
}
