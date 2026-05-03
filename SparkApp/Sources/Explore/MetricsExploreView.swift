import Charts
import SparkKit
import SparkUI
import SwiftUI

struct MetricsExploreView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: MetricsExploreViewModel?
    @State private var filterDomain: MetricDomain? = nil
    @State private var heroRange: HeroMetricRange = .week
    @State private var path: [DetailRoute] = []

    private static let categories: [MetricCategory] = [
        .init(domain: .health, title: "Sleep Score", icon: "moon.zzz.fill", tint: .sparkOcean, identifier: "oura.sleep_score"),
        .init(domain: .health, title: "Heart Rate", icon: "heart.fill", tint: .domainHealth, identifier: "oura.heart_rate"),
        .init(domain: .activity, title: "Steps", icon: "figure.walk", tint: .domainActivity, identifier: "oura.steps"),
        .init(domain: .activity, title: "Calories", icon: "flame.fill", tint: .domainActivity, identifier: "oura.calories"),
        .init(domain: .money, title: "Daily Spend", icon: "sterlingsign.circle.fill", tint: .domainMoney, identifier: "monzo.spend_daily"),
        .init(domain: .media, title: "Screen Time", icon: "iphone", tint: .domainMedia, identifier: "screen_time.daily"),
    ]

    private var allIdentifiers: [String] { Self.categories.map(\.identifier) }

    private var visibleCategories: [MetricCategory] {
        guard let filter = filterDomain else { return Self.categories }
        return Self.categories.filter { effectiveDomain(for: $0) == filter }
    }

    private var heroCategory: MetricCategory { Self.categories[0] }

    private var rowCategories: [MetricCategory] {
        visibleCategories.filter { $0.identifier != heroCategory.identifier }
    }

    private var heatmapRows: [DomainHeatmapRow] {
        let raw = HeatmapPlaceholder.generate()
        return [
            .init(id: "sleep", label: "Sleep", values: raw["sleep"] ?? [], tint: .domainHealth),
            .init(id: "motion", label: "Motion", values: raw["activity"] ?? [], tint: .domainActivity),
            .init(id: "spend", label: "Spend", values: raw["spend"] ?? [], tint: .domainMoney),
            .init(id: "mood", label: "Mood", values: raw["mood"] ?? [], tint: .sparkSuccess),
        ]
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    pageHeader
                        .padding(.horizontal, SparkSpacing.lg)

                    domainFilter
                        .padding(.horizontal, SparkSpacing.lg)

                    heroChartCard
                        .padding(.horizontal, SparkSpacing.lg)

                    metricsStack
                        .padding(.horizontal, SparkSpacing.lg)

                    historySection
                        .padding(.horizontal, SparkSpacing.lg)
                }
                .padding(.top, 92)
                .padding(.bottom, SparkSpacing.xl)
            }
            .background(metricsBackground.ignoresSafeArea())
            .navigationDestination(for: DetailRoute.self) { route in
                switch route {
                case .metric(let identifier):
                    MetricDetailView(identifier: identifier)
                default:
                    EmptyView()
                }
            }
            .refreshable {
                await viewModel?.refresh(identifiers: allIdentifiers)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = MetricsExploreViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load(identifiers: allIdentifiers)
        }
    }

    // MARK: - Page header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text("Metrics")
                .font(SparkTypography.heroXL)
                .foregroundStyle(headerTextColor)
            Text(headerSubtitle)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Domain filter

    private var domainFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SparkSpacing.sm) {
                Button { filterDomain = nil } label: {
                    MetricsFilterChip("All", isSelected: filterDomain == nil)
                }
                .buttonStyle(.plain)
                ForEach(MetricDomain.allCases, id: \.self) { domain in
                    Button { filterDomain = domain } label: {
                        MetricsFilterChip(domain.label, isSelected: filterDomain == domain)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Hero chart card

    @ViewBuilder
    private var heroChartCard: some View {
        let cat = heroCategory
        GlassCard(radius: 22, padding: SparkSpacing.xl) {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                HStack(alignment: .top, spacing: SparkSpacing.sm) {
                    VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                        HStack(spacing: SparkSpacing.sm) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(cat.tint)
                            Text(cat.title)
                                .font(SparkTypography.bodyStrong)
                                .foregroundStyle(headerTextColor)
                        }

                        if let detail = viewModel?.snapshots[cat.identifier] {
                            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                                if let today = detail.today {
                                    Text(formatValue(today, unit: detail.unit))
                                        .font(SparkFonts.display(.largeTitle, weight: .bold))
                                        .foregroundStyle(cat.tint)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                if let delta = delta(for: detail) {
                                    deltaChip(delta, suffix: "vs 7-day avg")
                                }
                            }
                        } else {
                            LoadingShimmerCard()
                                .frame(width: 140, height: 74)
                        }
                    }

                    Spacer(minLength: SparkSpacing.md)

                    rangePicker
                }

                if let detail = viewModel?.snapshots[cat.identifier] {
                    SparklineMiniChart(series: series(for: detail), tint: cat.tint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 96)
                } else {
                    LoadingShimmerCard()
                        .frame(height: 96)
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture {
            path.append(.metric(identifier: cat.identifier))
        }
    }

    // MARK: - Metric rows (full-bleed sparkline)

    private var metricsStack: some View {
        VStack(spacing: SparkSpacing.sm) {
            ForEach(rowCategories, id: \.identifier) { category in
                Button {
                    path.append(.metric(identifier: category.identifier))
                } label: {
                    FullBleedMetricRow(
                        category: category,
                        detail: viewModel?.snapshots[category.identifier],
                        isLoading: viewModel?.loadState == .loading || viewModel == nil
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - History / heatmap

    private var historySection: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            Text("Last 45 days")
                .font(SparkTypography.monoSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            GlassCard(radius: SparkRadii.lg, padding: SparkSpacing.lg) {
                Heatmap45(rows: heatmapRows)
            }
        }
    }

    // MARK: - Helpers

    private func delta(for detail: MetricDetail) -> (value: Double, isPositive: Bool)? {
        guard let today = detail.today, let avg = detail.average30d else { return nil }
        return (today - avg, today >= avg)
    }

    @ViewBuilder
    private func deltaChip(_ d: (value: Double, isPositive: Bool), suffix: String? = nil) -> some View {
        HStack(spacing: 3) {
            Image(systemName: d.isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text(deltaLabel(d.value))
                .font(SparkTypography.monoSmall)
            if let suffix {
                Text(suffix)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(d.isPositive ? Color.sparkSuccess : Color.sparkWarning)
    }

    private func formatValue(_ v: Double, unit: String?) -> String {
        switch unit {
        case "score", "bpm", "percent": return String(Int(v))
        case "ms": return "\(Int(v))"
        case "GBP", "USD", "EUR": return String(format: "£%.2f", v)
        default:
            if v >= 1000 { return String(format: "%.1fk", v / 1000) }
            return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
        }
    }

    private func deltaLabel(_ diff: Double) -> String {
        let sign = diff >= 0 ? "+" : ""
        if abs(diff) >= 1000 { return "\(sign)\(String(format: "%.1fk", diff / 1000))" }
        return "\(sign)\(diff.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(diff)) : String(format: "%.1f", diff))"
    }

    private var metricsBackground: some View {
        ZStack {
            Color.sparkSurface
            if colorScheme == .light {
                LinearGradient(
                    colors: [Color.ocean100.opacity(0.24), Color.spark100.opacity(0.18), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [Color.ocean800.opacity(0.75), Color.ocean950, Color.black.opacity(0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var headerTextColor: Color {
        colorScheme == .dark ? Color.spark100 : Color.sparkTextPrimary
    }

    private var headerSubtitle: String {
        switch viewModel?.metadataState {
        case .loaded(let summary):
            let sourceText = "\(summary.activeSourceCount) active sources"
            guard let lastSyncAt = summary.lastSyncAt else { return sourceText }
            return "\(sourceText) - last sync \(relativeSyncText(for: lastSyncAt)) ago"
        case .unavailable:
            return "Sources unavailable"
        case .idle, .none:
            return "Loading sources"
        }
    }

    private var rangePicker: some View {
        HStack(spacing: SparkSpacing.xs) {
            ForEach(HeroMetricRange.allCases, id: \.self) { range in
                Button {
                    heroRange = range
                } label: {
                    Text(range.label)
                        .font(SparkTypography.monoSmall)
                        .fontWeight(.semibold)
                        .frame(width: 34, height: 34)
                        .foregroundStyle(heroRange == range ? Color.sparkTextPrimary : Color.secondary)
                        .background {
                            Circle()
                                .fill(heroRange == range ? Color.spark100 : Color.primary.opacity(0.05))
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func series(for detail: MetricDetail) -> [MetricDetail.Point] {
        switch heroRange {
        case .day:
            return Array(detail.series.suffix(2))
        case .week:
            return Array(detail.series.suffix(7))
        case .month:
            return Array(detail.series.suffix(30))
        }
    }

    private func effectiveDomain(for category: MetricCategory) -> MetricDomain {
        guard let raw = viewModel?.metrics.first(where: { $0.identifier == category.identifier })?.domain,
              let domain = MetricDomain(rawValue: raw) else {
            return category.domain
        }
        return domain
    }

    private func relativeSyncText(for date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "\(max(1, seconds))s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}

// MARK: - Full-bleed metric row

private struct FullBleedMetricRow: View {
    let category: MetricCategory
    let detail: MetricDetail?
    let isLoading: Bool

    private var recentSeries: [MetricDetail.Point] {
        Array((detail?.series ?? []).suffix(14))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if !recentSeries.isEmpty {
                SparklineMiniChart(series: recentSeries, tint: category.tint)
                    .opacity(0.28)
                    .frame(maxWidth: .infinity)
                    .frame(height: 92)
                    .offset(x: 70, y: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                LinearGradient(
                    stops: [
                        .init(color: Color.sparkElevated.opacity(0.95), location: 0),
                        .init(color: Color.sparkElevated.opacity(0.72), location: 0.40),
                        .init(color: Color.sparkElevated.opacity(0), location: 0.75),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }

            HStack(spacing: SparkSpacing.md) {
                Image(systemName: category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: SparkRadii.sm)
                            .fill(category.tint)
                    )

                VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                    Text(category.title)
                        .font(SparkTypography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let today = detail?.today {
                        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
                            Text(formatValue(today, unit: detail?.unit))
                                .font(SparkFonts.display(.title, weight: .bold))
                                .foregroundStyle(category.tint)
                            if let unit = unitLabel(detail?.unit) {
                                Text(unit)
                                    .font(SparkTypography.bodySmall)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let delta = delta(for: detail) {
                            HStack(spacing: 3) {
                                Image(systemName: delta.isPositive ? "arrow.up.right" : "arrow.down.right")
                                    .font(.caption2)
                                Text(deltaLabel(delta.value))
                                    .font(SparkTypography.monoSmall)
                            }
                            .foregroundStyle(delta.isPositive ? Color.sparkSuccess : Color.sparkWarning)
                        }
                    } else if isLoading {
                        Text("—")
                            .font(SparkTypography.monoBody)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, SparkSpacing.lg)
        }
        .frame(height: 104)
        .sparkGlass(.roundedRect(20))
    }

    private func delta(for detail: MetricDetail?) -> (value: Double, isPositive: Bool)? {
        guard let detail, let today = detail.today, let avg = detail.average30d else { return nil }
        return (today - avg, today >= avg)
    }

    private func formatValue(_ v: Double, unit: String?) -> String {
        switch unit {
        case "score", "bpm", "percent": return String(Int(v))
        case "steps": return String(Int(v))
        case "kcal": return String(Int(v))
        case "GBP", "USD", "EUR": return String(format: "£%.2f", v)
        default:
            if v >= 1000 { return String(format: "%.1fk", v / 1000) }
            return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
        }
    }

    private func unitLabel(_ unit: String?) -> String? {
        switch unit {
        case "score", "steps", "percent", nil:
            return nil
        case "GBP":
            return nil
        default:
            return unit
        }
    }

    private func deltaLabel(_ diff: Double) -> String {
        let sign = diff >= 0 ? "+" : ""
        if abs(diff) >= 1000 { return "\(sign)\(String(format: "%.1fk", diff / 1000))" }
        return "\(sign)\(diff.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(diff)) : String(format: "%.1f", diff))"
    }
}

// MARK: - Supporting types

private enum MetricDomain: String, CaseIterable {
    case health, activity, money, media

    var label: String {
        switch self {
        case .health: "Health"
        case .activity: "Activity"
        case .money: "Money"
        case .media: "Media"
        }
    }
}

private enum HeroMetricRange: CaseIterable {
    case day, week, month

    var label: String {
        switch self {
        case .day: "D"
        case .week: "W"
        case .month: "M"
        }
    }
}

private struct MetricCategory {
    let domain: MetricDomain
    let title: String
    let icon: String
    let tint: Color
    let identifier: String
}

private struct MetricsFilterChip: View {
    let title: String
    let isSelected: Bool

    init(_ title: String, isSelected: Bool) {
        self.title = title
        self.isSelected = isSelected
    }

    var body: some View {
        Text(title)
            .font(SparkTypography.captionStrong)
            .padding(.horizontal, SparkSpacing.md)
            .padding(.vertical, SparkSpacing.xs + 2)
            .foregroundStyle(isSelected ? Color.sparkTextPrimary : Color.secondary)
            .background {
                Capsule()
                    .fill(isSelected ? Color.spark100 : Color.primary.opacity(0.04))
            }
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(isSelected ? 0 : 0.08), lineWidth: 1)
            }
    }
}

// MARK: - Sparkline mini chart

private struct SparklineMiniChart: View {
    let series: [MetricDetail.Point]
    let tint: Color

    var body: some View {
        Chart(series) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [tint.opacity(0.4), tint.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            LineMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(tint)
            .lineStyle(StrokeStyle(lineWidth: 1.5))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

extension MetricsExploreViewModel.LoadState: Equatable {
    static func == (lhs: MetricsExploreViewModel.LoadState, rhs: MetricsExploreViewModel.LoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.loaded, .loaded): return true
        case (.error(let l), .error(let r)): return l == r
        default: return false
        }
    }
}
