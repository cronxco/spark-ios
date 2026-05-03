import Charts
import SparkKit
import SparkUI
import SwiftUI

struct MetricsExploreView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: MetricsExploreViewModel?
    @State private var filterDomain: MetricDomain? = nil
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
        return Self.categories.filter { $0.domain == filter }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: SparkSpacing.lg) {
                    domainFilter
                        .padding(.horizontal, SparkSpacing.lg)

                    ForEach(visibleCategories, id: \.identifier) { category in
                        GlassCard {
                            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                                GlassCardHeader(
                                    icon: category.icon,
                                    tint: category.tint,
                                    title: category.title
                                )
                                tileContent(for: category)
                            }
                        }
                        .padding(.horizontal, SparkSpacing.lg)
                    }
                }
                .padding(.vertical, SparkSpacing.xl)
            }
            .background(Color.sparkSurface.ignoresSafeArea())
            .navigationTitle("Metrics")
            .navigationBarTitleDisplayMode(.large)
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

    private var domainFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SparkSpacing.sm) {
                Button { filterDomain = nil } label: {
                    TagChip("All", isGhost: filterDomain != nil)
                }
                .buttonStyle(.plain)
                ForEach(MetricDomain.allCases, id: \.self) { domain in
                    Button { filterDomain = domain } label: {
                        TagChip(domain.label, isGhost: filterDomain != domain)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func tileContent(for category: MetricCategory) -> some View {
        if let detail = viewModel?.snapshots[category.identifier] {
            Button {
                path.append(.metric(identifier: category.identifier))
            } label: {
                MetricsTileCard(detail: detail, tint: category.tint)
            }
            .buttonStyle(.plain)
        } else if viewModel?.loadState == .loading || viewModel == nil {
            LoadingShimmerCard()
        } else {
            EmptyState(
                systemImage: category.icon,
                title: "No data yet",
                message: "Metrics will appear here once your integration syncs."
            )
        }
    }
}

// MARK: - Supporting types

private enum MetricDomain: CaseIterable {
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

private struct MetricCategory {
    let domain: MetricDomain
    let title: String
    let icon: String
    let tint: Color
    let identifier: String
}

// MARK: - Compact metric tile for Metrics Explore

private struct MetricsTileCard: View {
    let detail: MetricDetail
    let tint: Color

    private var recentSeries: [MetricDetail.Point] { Array(detail.series.suffix(7)) }

    private var delta: (value: Double, isPositive: Bool)? {
        guard let today = detail.today, let avg = detail.average30d else { return nil }
        return (today - avg, today >= avg)
    }

    var body: some View {
        HStack(alignment: .top, spacing: SparkSpacing.lg) {
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                if let today = detail.today {
                    Text(formatValue(today, unit: detail.unit))
                        .font(SparkFonts.display(.title, weight: .bold))
                        .foregroundStyle(tint)
                } else {
                    Text("—")
                        .font(SparkFonts.display(.title, weight: .bold))
                        .foregroundStyle(.tertiary)
                }

                if let d = delta {
                    HStack(spacing: 3) {
                        Image(systemName: d.isPositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text(deltaLabel(d.value))
                            .font(SparkTypography.monoSmall)
                    }
                    .foregroundStyle(d.isPositive ? Color.sparkSuccess : Color.sparkWarning)
                }
            }

            Spacer(minLength: 0)

            if !recentSeries.isEmpty {
                SparklineMiniChart(series: recentSeries, tint: tint)
                    .frame(width: 100, height: 50)
            }
        }
        .padding(.top, SparkSpacing.xs)
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
}

// MARK: - Sparkline mini chart (shared with HealthExploreView)

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
                    colors: [tint.opacity(0.3), tint.opacity(0)],
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
