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
                VStack(spacing: SparkSpacing.lg) {
                    let hasData = viewModel?.snapshots.isEmpty == false
                    switch viewModel?.loadState {
                    case .none, .idle:
                        shimmerGroup
                    case .loading where !hasData:
                        shimmerGroup
                    default:
                        if let vm = viewModel {
                            sleepRecoveryCard(vm: vm)
                            activityCard(vm: vm)
                            heartCard(vm: vm)
                        }
                    }
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.vertical, SparkSpacing.xl)
            }
            .background(Color.sparkSurface.ignoresSafeArea())
            .navigationTitle("Health")
            .navigationBarTitleDisplayMode(.large)
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

    // MARK: - Card groups

    private func sleepRecoveryCard(vm: HealthExploreViewModel) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                GlassCardHeader(icon: "moon.zzz.fill", tint: .sparkOcean, title: "Sleep & Recovery")
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: SparkSpacing.sm) {
                    tileOrShimmer(identifier: "oura.sleep_score", tint: .sparkOcean, vm: vm)
                    tileOrShimmer(identifier: "oura.hrv", tint: .sparkOcean, vm: vm)
                }
            }
        }
    }

    private func activityCard(vm: HealthExploreViewModel) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                GlassCardHeader(icon: "figure.walk", tint: .domainActivity, title: "Activity")
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: SparkSpacing.sm) {
                    tileOrShimmer(identifier: "oura.steps", tint: .domainActivity, vm: vm)
                    tileOrShimmer(identifier: "oura.calories", tint: .domainActivity, vm: vm)
                }
            }
        }
    }

    private func heartCard(vm: HealthExploreViewModel) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                GlassCardHeader(icon: "heart.fill", tint: .domainHealth, title: "Heart")
                tileOrShimmer(identifier: "oura.heart_rate", tint: .domainHealth, vm: vm)
            }
        }
    }

    @ViewBuilder
    private func tileOrShimmer(identifier: String, tint: Color, vm: HealthExploreViewModel) -> some View {
        if let detail = vm.snapshots[identifier] {
            Button {
                path.append(.metric(identifier: identifier))
            } label: {
                MetricTileCard(detail: detail, tint: tint)
            }
            .buttonStyle(.plain)
        } else if case .loading = vm.loadState {
            LoadingShimmerCard()
        }
        // If loaded and nil → metric not connected; show nothing.
    }

    // MARK: - Shimmers

    private var shimmerGroup: some View {
        VStack(spacing: SparkSpacing.lg) {
            ForEach(0..<3, id: \.self) { _ in
                GlassCard {
                    VStack(alignment: .leading, spacing: SparkSpacing.md) {
                        LoadingShimmerCard().frame(height: 16).frame(maxWidth: 120)
                        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: SparkSpacing.sm) {
                            LoadingShimmerCard().frame(height: 110)
                            LoadingShimmerCard().frame(height: 110)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Metric Tile Card

private struct MetricTileCard: View {
    let detail: MetricDetail
    let tint: Color

    private var recentSeries: [MetricDetail.Point] {
        Array(detail.series.suffix(7))
    }

    private var delta: (value: Double, isPositive: Bool)? {
        guard let today = detail.today, let avg = detail.average30d else { return nil }
        return (today - avg, today >= avg)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            HStack {
                Text(detail.title)
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let unit = detail.unit {
                    Text(unit)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.tertiary)
                }
            }

            if let today = detail.today {
                Text(formatValue(today, unit: detail.unit))
                    .font(SparkFonts.display(.title2, weight: .bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text("—")
                    .font(SparkFonts.display(.title2, weight: .bold))
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

            if !recentSeries.isEmpty {
                SparklineMiniChart(series: recentSeries, tint: tint)
                    .frame(height: 32)
                    .padding(.top, SparkSpacing.xxs)
            }
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkGlass(.roundedRect(SparkRadii.md))
    }

    private func formatValue(_ v: Double, unit: String?) -> String {
        switch unit {
        case "score", "bpm", "percent":
            return String(Int(v))
        case "ms":
            return "\(Int(v))"
        default:
            if v >= 1000 { return String(format: "%.1fk", v / 1000) }
            return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
        }
    }

    private func deltaLabel(_ diff: Double) -> String {
        let sign = diff >= 0 ? "+" : ""
        if abs(diff) >= 1000 { return "\(sign)\(String(format: "%.1fk", diff / 1000))" }
        return "\(sign)\(diff.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(diff)) : String(format: "%.1f", diff)) vs avg"
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
                    colors: [tint.opacity(0.3), tint.opacity(0.0)],
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
