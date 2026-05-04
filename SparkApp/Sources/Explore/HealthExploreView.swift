import Charts
import SparkKit
import SparkUI
import SwiftUI

struct HealthExploreView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: HealthExploreViewModel?
    @State private var path: [DetailRoute] = []

    private static let categories: [HealthMetricCategory] = [
        .init(title: "Sleep Score", icon: "moon.zzz.fill", tint: .sparkOcean, identifier: "oura.sleep_score"),
        .init(title: "Heart Rate", icon: "heart.fill", tint: .domainHealth, identifier: "oura.heart_rate"),
        .init(title: "HRV", icon: "waveform.path.ecg", tint: .domainHealth, identifier: "oura.hrv"),
        .init(title: "Steps", icon: "figure.walk", tint: .domainActivity, identifier: "oura.steps"),
        .init(title: "Calories", icon: "flame.fill", tint: .domainActivity, identifier: "oura.calories"),
    ]

    private var heroCategory: HealthMetricCategory { Self.categories[0] }
    private var rowCategories: [HealthMetricCategory] { Array(Self.categories.dropFirst()) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    pageHeader
                        .padding(.horizontal, SparkSpacing.lg)

                    heroHealthCard
                        .padding(.horizontal, SparkSpacing.lg)

                    metricRows
                        .padding(.horizontal, SparkSpacing.lg)
                }
                .padding(.top, SparkSpacing.xl)
                .padding(.bottom, SparkSpacing.xl)
            }
            .sparkAppBackground()
            .navigationDestination(for: DetailRoute.self) { route in
                switch route {
                case .metric(let identifier):
                    MetricDetailView(identifier: identifier)
                case .event(let id):
                    EventDetailView(eventId: id)
                default:
                    EmptyView()
                }
            }
            .refreshable {
                await viewModel?.refresh()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = HealthExploreViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text("Health")
                .font(SparkTypography.heroXL)
                .foregroundStyle(headerTextColor)
            Text(headerSubtitle)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var heroHealthCard: some View {
        let category = heroCategory
        GlassCard(radius: 22, padding: SparkSpacing.xl) {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                HStack(alignment: .top, spacing: SparkSpacing.sm) {
                    VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                        HStack(spacing: SparkSpacing.sm) {
                            Image(systemName: category.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(category.tint)
                            Text(category.title)
                                .font(SparkTypography.bodyStrong)
                                .foregroundStyle(headerTextColor)
                        }

                        if let detail = viewModel?.snapshots[category.identifier] {
                            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                                if let today = detail.today {
                                    Text(formatValue(today, unit: detail.unit))
                                        .font(SparkFonts.display(.largeTitle, weight: .bold))
                                        .foregroundStyle(category.tint)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
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

                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(category.tint)
                        .frame(width: 48, height: 48)
                        .background {
                            Circle().fill(category.tint.opacity(0.12))
                        }
                }

                if let detail = viewModel?.snapshots[category.identifier] {
                    SparklineMiniChart(series: Array(detail.series.suffix(14)), tint: category.tint)
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
            path.append(.metric(identifier: category.identifier))
        }
    }

    private var metricRows: some View {
        VStack(spacing: SparkSpacing.sm) {
            ForEach(rowCategories) { category in
                Button {
                    path.append(.metric(identifier: category.identifier))
                } label: {
                    HealthMetricRow(
                        category: category,
                        detail: viewModel?.snapshots[category.identifier],
                        isLoading: isLoadingMetrics
                    )
                }
                .buttonStyle(.plain)
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

    private func delta(for detail: MetricDetail) -> (value: Double, isPositive: Bool)? {
        guard let today = detail.today, let avg = detail.average30d else { return nil }
        return (today - avg, today >= avg)
    }

    private func formatValue(_ v: Double, unit: String?) -> String {
        switch unit {
        case "score", "bpm", "percent", "ms":
            return String(Int(v))
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
        switch viewModel?.loadState {
        case .loaded:
            let count = viewModel?.snapshots.count ?? 0
            return "\(count) connected metric\(count == 1 ? "" : "s")"
        case .error:
            return "Health data unavailable"
        case .loading:
            return "Loading health signals"
        case .idle, .none:
            return "Health signals from your connected sources"
        }
    }

    private var isLoadingMetrics: Bool {
        guard let viewModel else { return true }
        if case .loading = viewModel.loadState { return true }
        return false
    }
}

private struct HealthMetricRow: View {
    let category: HealthMetricCategory
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
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
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
                        Text("--")
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
        case "score", "bpm", "percent", "ms":
            return String(Int(v))
        default:
            if v >= 1000 { return String(format: "%.1fk", v / 1000) }
            return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
        }
    }

    private func unitLabel(_ unit: String?) -> String? {
        switch unit {
        case "score", "steps", "percent", nil:
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

private struct HealthMetricCategory: Identifiable {
    let title: String
    let icon: String
    let tint: Color
    let identifier: String

    var id: String { identifier }
}

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
