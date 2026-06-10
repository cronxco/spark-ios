import Charts
import SparkKit
import SparkUI
import SwiftUI

struct MetricsExploreView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: MetricsExploreViewModel?
    @State private var filterDomain: String? = nil
    @State private var domainSelection: String = Self.allDomainsFilterID
    @State private var sortMode: MetricSortMode = .anomalies
    @State private var searchText = ""
    @State private var heroRange: HeroMetricRange = .week
    @State private var path: [DetailRoute] = []

    private var visibleMetrics: [MetricPresentation] {
        let metrics = (viewModel?.metrics ?? []).map { metric in
            MetricPresentation(
                metric: metric,
                detail: viewModel?.snapshots[metric.identifier]
            )
        }
        let domainFiltered = metrics.filter { metric in
            guard let filterDomain else { return true }
            return metric.domain == filterDomain
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searched = query.isEmpty ? domainFiltered : domainFiltered.filter { $0.matches(query: query) }
        return searched.sorted { sortMode.areInIncreasingOrder($0, $1) }
    }

    private var heroMetric: MetricPresentation? {
        visibleMetrics.first
    }

    private var rowMetrics: [MetricPresentation] {
        Array(visibleMetrics.dropFirst())
    }

    private var availableDomains: [String] {
        Array(Set((viewModel?.metrics ?? []).map { MetricPresentation.domain(for: $0) })).sorted {
            displayLabel(forDomain: $0) < displayLabel(forDomain: $1)
        }
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

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                        TextField("Search service or action", text: $searchText)
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.primary)
                            .tint(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .sparkGlass(.capsule)
                    .padding(.horizontal, SparkSpacing.lg)

                    sortControls
                        .padding(.horizontal, SparkSpacing.lg)

                    domainFilter
                        .padding(.horizontal, SparkSpacing.lg)

                    content

                    if heroMetric != nil {
                        historySection
                            .padding(.horizontal, SparkSpacing.lg)
                    }

                    if let viewModel, case .loaded = viewModel.loadState, !viewModel.rawFeedEntries.isEmpty {
                        RawFeedJSONView(entries: viewModel.rawFeedEntries)
                            .padding(.horizontal, SparkSpacing.lg)
                    }
                }
                .padding(.top, SparkSpacing.md)
                .padding(.bottom, SparkSpacing.xl)
            }
            .sparkAppBackground()
            .sparkMainNavigationTitle("Metrics")
            .navigationDestination(for: DetailRoute.self) { route in
                switch route {
                case .metric(let identifier):
                    MetricDetailView(identifier: identifier)
                default:
                    EmptyView()
                }
            }
            .refreshable { await viewModel?.refresh() }
            .sparkMainAppToolbar()
        }
        .task {
            if viewModel == nil {
                viewModel = MetricsExploreViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    // MARK: - Page header

    private var pageHeader: some View {
        SparkMainPageHeader(title: "Metrics", subtitle: headerSubtitle)
    }

    // MARK: - Domain filter

    @ViewBuilder
    private var domainFilter: some View {
        if !availableDomains.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                Picker("Domain", selection: $domainSelection) {
                    Text("All").tag(Self.allDomainsFilterID)
                    ForEach(availableDomains, id: \.self) { domain in
                        Text(displayLabel(forDomain: domain)).tag(domain)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 360)
                .onChange(of: domainSelection) { _, newValue in
                    filterDomain = newValue == Self.allDomainsFilterID ? nil : newValue
                }
                .onChange(of: availableDomains) { _, domains in
                    guard domainSelection != Self.allDomainsFilterID,
                          !domains.contains(domainSelection)
                    else { return }
                    domainSelection = Self.allDomainsFilterID
                    filterDomain = nil
                }
            }
        }
    }

    private var sortControls: some View {
        HStack(spacing: SparkSpacing.sm) {
            Menu {
                ForEach(MetricSortMode.allCases, id: \.self) { mode in
                    Button {
                        sortMode = mode
                    } label: {
                        Label(mode.title, systemImage: mode.systemImage)
                    }
                }
            } label: {
                HStack(spacing: SparkSpacing.xs) {
                    Image(systemName: sortMode.systemImage)
                    Text(sortMode.title)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .font(SparkTypography.captionStrong)
                .foregroundStyle(Color.sparkTextPrimary)
                .padding(.horizontal, SparkSpacing.md)
                .padding(.vertical, SparkSpacing.xs + 2)
                .sparkGlass(.capsule)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel?.loadState {
        case .idle, .loading, .none:
            loadingContent
        case .error(let message):
            EmptyState(
                systemImage: "exclamationmark.triangle.fill",
                title: "Couldn't load metrics",
                message: message,
                actionTitle: "Retry"
            ) { Task { await viewModel?.refresh() } }
            .padding(.horizontal, SparkSpacing.lg)
        case .loaded:
            if viewModel?.metrics.isEmpty == true {
                EmptyState(
                    systemImage: "chart.line.uptrend.xyaxis",
                    title: "No active metrics",
                    message: "Connected metrics will appear here once Spark receives events for them."
                )
                .padding(.horizontal, SparkSpacing.lg)
            } else if visibleMetrics.isEmpty {
                EmptyState(
                    systemImage: "magnifyingglass",
                    title: "No matching metrics",
                    message: searchText.isEmpty ? "Try another domain." : "Try a different service, action, or metric name."
                )
                .padding(.horizontal, SparkSpacing.lg)
            } else {
                heroChartCard
                    .padding(.horizontal, SparkSpacing.lg)

                metricsStack
                    .padding(.horizontal, SparkSpacing.lg)
            }
        }
    }

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.lg) {
            LoadingShimmerCard()
                .frame(height: 210)
            LoadingShimmerCard()
                .frame(height: 104)
            LoadingShimmerCard()
                .frame(height: 104)
        }
        .padding(.horizontal, SparkSpacing.lg)
    }

    // MARK: - Hero chart card

    @ViewBuilder
    private var heroChartCard: some View {
        if let metric = heroMetric {
            GlassCard(radius: 28, padding: SparkSpacing.xl, tint: metric.tint.opacity(0.08)) {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    HStack(alignment: .top, spacing: SparkSpacing.sm) {
                        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                            HStack(spacing: SparkSpacing.sm) {
                                DomainGlyph(icon: metric.icon, tint: metric.tint, size: 26)
                                Text(metric.title)
                                    .font(SparkTypography.bodyStrong)
                                    .foregroundStyle(headerTextColor)
                                AnomalyDot(active: metric.latestAnomalyAt != nil)
                            }

                            if let detail = metric.detail {
                                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                                    if let today = detail.today {
                                        valueLine(today, unit: detail.unit, tint: metric.tint, size: 60)
                                    }
                                    if let delta = delta(for: detail) {
                                        deltaChip(delta, suffix: "vs 30-day avg")
                                    }
                                }
                            } else {
                                LoadingShimmerCard()
                                    .frame(width: 140, height: 74)
                            }
                        }

                        Spacer(minLength: SparkSpacing.md)

                        rangePicker(tint: metric.tint)
                    }

                    if let detail = metric.detail {
                        SparklineMiniChart(series: series(for: detail), tint: metric.tint)
                            .frame(maxWidth: .infinity)
                            .frame(height: 118)
                    } else {
                        LoadingShimmerCard()
                            .frame(height: 118)
                    }
                }
                .frame(minHeight: 236, alignment: .topLeading)
            }
            .contentShape(RoundedRectangle(cornerRadius: 28))
            .onTapGesture {
                path.append(.metric(identifier: metric.identifier))
            }
        }
    }

    // MARK: - Metric rows (full-bleed sparkline)

    private var metricsStack: some View {
        VStack(spacing: SparkSpacing.sm) {
            ForEach(rowMetrics, id: \.identifier) { metric in
                Button {
                    path.append(.metric(identifier: metric.identifier))
                } label: {
                    FullBleedMetricRow(
                        metric: metric,
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
            SparkSectionHeader(title: "Last 45 days", icon: "waveform", tint: .domainKnowledge)

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

    private func valueLine(_ value: Double, unit: String?, tint: Color, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
            Text(formatValue(value, unit: unit))
                .font(SparkFonts.display(size: size))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            if let unit = unitLabel(unit) {
                Text(unit)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
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

    private var headerTextColor: Color {
        colorScheme == .dark ? Color.spark100 : Color.sparkTextPrimary
    }

    private var headerSubtitle: String {
        switch viewModel?.metadataState {
        case .loaded(let summary):
            guard let lastSyncAt = summary.lastSyncAt else { return "No metrics synced yet" }
            return lastSyncedSubtitle(for: lastSyncAt)
        case .unavailable:
            return "Metrics unavailable"
        case .idle, .none:
            return "Loading metrics"
        }
    }

    private func rangePicker(tint: Color) -> some View {
        HStack(spacing: 4) {
            ForEach(HeroMetricRange.allCases, id: \.self) { range in
                let isSelected = heroRange == range
                Button {
                    heroRange = range
                } label: {
                    Text(range.label)
                        .font(SparkTypography.monoSmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? Color.sparkTextPrimary : Color.secondary)
                        .frame(minWidth: 34)
                        .padding(.vertical, SparkSpacing.xs + 2)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(tint)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .sparkGlass(.capsule)
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

    private func unitLabel(_ unit: String?) -> String? {
        switch unit {
        case nil, "score", "steps":
            nil
        case "percent":
            "percent"
        case "GBP":
            "GBP"
        default:
            unit
        }
    }

    private func lastSyncedSubtitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Last synced today at \(Self.syncTimeFormatter.string(from: date))"
        }
        if calendar.isDateInYesterday(date) {
            return "Last synced yesterday at \(Self.syncTimeFormatter.string(from: date))"
        }
        return "Last synced \(Self.syncDateFormatter.string(from: date))"
    }

    private func displayLabel(forDomain domain: String) -> String {
        domain.replacingOccurrences(of: "_", with: " ").sparkActionTitle
    }

    private static let syncTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let syncDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let allDomainsFilterID = "__all__"
}

// MARK: - Full-bleed metric row

private struct FullBleedMetricRow: View {
    let metric: MetricPresentation
    let isLoading: Bool

    private var recentSeries: [MetricDetail.Point] {
        Array((metric.detail?.series ?? []).suffix(14))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if !recentSeries.isEmpty {
                SparklineMiniChart(series: recentSeries, tint: metric.tint)
                    .opacity(0.24)
                    .frame(maxWidth: .infinity)
                    .frame(height: 118)
                    .offset(x: 52, y: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                LinearGradient(
                    stops: [
                        .init(color: Color.sparkElevated.opacity(0.95), location: 0),
                        .init(color: Color.sparkElevated.opacity(0.78), location: 0.34),
                        .init(color: Color.sparkElevated.opacity(0), location: 0.74),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 118)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                LinearGradient(
                    stops: [
                        .init(color: Color.sparkElevated.opacity(0), location: 0.0),
                        .init(color: Color.sparkElevated.opacity(0.66), location: 0.56),
                        .init(color: Color.sparkElevated.opacity(0.92), location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 118)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }

            HStack(alignment: .center, spacing: SparkSpacing.md) {
                leadingContent
                Spacer(minLength: SparkSpacing.sm)
                trailingDelta
            }
            .padding(.horizontal, SparkSpacing.lg)
        }
        .frame(height: 118)
        .sparkGlass(.roundedRect(20))
        .overlay(alignment: .topTrailing) {
            AnomalyDot(active: metric.latestAnomalyAt != nil)
                .padding(8)
        }
    }

    private var leadingContent: some View {
        HStack(spacing: SparkSpacing.md) {
            DomainGlyph(icon: metric.icon, tint: metric.tint, size: 44)

            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                Text(metric.title)
                    .font(SparkTypography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let today = metric.detail?.today {
                    HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
                        Text(formatValue(today, unit: metric.detail?.unit))
                            .font(SparkFonts.display(size: 34))
                            .foregroundStyle(metric.tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        if let unit = unitLabel(metric.detail?.unit) {
                            Text(unit)
                                .font(SparkTypography.bodySmall)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                } else if isLoading {
                    Text("--")
                        .font(SparkTypography.monoBody)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.trailing, SparkSpacing.sm)
    }

    @ViewBuilder
    private var trailingDelta: some View {
        if let delta = delta(for: metric.detail) {
            HStack(spacing: 3) {
                Image(systemName: delta.isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                Text(deltaLabel(delta.value))
                    .font(SparkTypography.monoSmall)
            }
            .fontWeight(.semibold)
            .foregroundStyle(delta.isPositive ? Color.sparkSuccess : Color.sparkWarning)
            .padding(.horizontal, SparkSpacing.sm)
            .padding(.vertical, SparkSpacing.xs)
            .sparkGlass(.capsule)
        }
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

private enum MetricSortMode: String, CaseIterable {
    case anomalies
    case recent
    case name
    case service

    var title: String {
        switch self {
        case .anomalies: "Anomalies"
        case .recent: "Most Recent"
        case .name: "Name"
        case .service: "Service"
        }
    }

    var systemImage: String {
        switch self {
        case .anomalies: "exclamationmark.triangle.fill"
        case .recent: "clock.fill"
        case .name: "textformat"
        case .service: "server.rack"
        }
    }

    func areInIncreasingOrder(_ lhs: MetricPresentation, _ rhs: MetricPresentation) -> Bool {
        switch self {
        case .anomalies:
            return compare(lhs, rhs, dates: [\.latestAnomalyAt, \.lastEventAt])
        case .recent:
            return compare(lhs, rhs, dates: [\.lastEventAt])
        case .name:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        case .service:
            let service = lhs.service.localizedCaseInsensitiveCompare(rhs.service)
            if service != .orderedSame { return service == .orderedAscending }
            let action = lhs.action.localizedCaseInsensitiveCompare(rhs.action)
            if action != .orderedSame { return action == .orderedAscending }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private func compare(
        _ lhs: MetricPresentation,
        _ rhs: MetricPresentation,
        dates: [KeyPath<MetricPresentation, Date?>]
    ) -> Bool {
        for keyPath in dates {
            let left = lhs[keyPath: keyPath]
            let right = rhs[keyPath: keyPath]
            switch (left, right) {
            case let (left?, right?) where left != right:
                return left > right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                break
            }
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
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

private struct MetricPresentation {
    let metric: Metric
    let detail: MetricDetail?

    var identifier: String { metric.identifier }
    var title: String { metric.displayName }
    var service: String { metric.service }
    var action: String { metric.action }
    var domain: String { Self.domain(for: metric) }
    var lastEventAt: Date? { metric.lastEventAt }
    var latestAnomalyAt: Date? {
        guard let detail,
              let latestPointDate = detail.series.last?.date,
              detail.anomalies.contains(where: { $0.date == latestPointDate })
        else { return nil }
        return latestPointDate
    }

    var icon: String {
        EntityPresentation.icon(domain: domain, service: service, action: action)
    }

    var tint: Color {
        EntityPresentation.tint(domain: domain)
    }

    func matches(query: String) -> Bool {
        let fields = [title, identifier, service, action, domain]
        return fields.contains { field in
            field.localizedCaseInsensitiveContains(query)
        }
    }

    static func domain(for metric: Metric) -> String {
        guard let domain = metric.domain?.trimmingCharacters(in: .whitespacesAndNewlines),
              !domain.isEmpty
        else {
            return metric.service
        }
        return domain
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
