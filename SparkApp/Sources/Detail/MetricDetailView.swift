import SparkKit
import SparkUI
import SwiftUI

@MainActor
@Observable
final class MetricDetailViewModel {
    let identifier: String
    var range: MetricsEndpoint.Range
    private(set) var state: DetailLoadState<MetricDetail> = .loading

    private let apiClient: APIClient

    init(identifier: String, range: MetricsEndpoint.Range = .thirtyDays, apiClient: APIClient) {
        self.identifier = identifier
        self.range = range
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let detail = try await apiClient.request(
                MetricsEndpoint.detail(identifier: identifier, range: range)
            )
            state = .loaded(detail)
        } catch APIError.notModified {
            return
        } catch {
            SparkObservability.captureHandled(error)
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            state = .error(msg)
        }
    }

    func setRange(_ newRange: MetricsEndpoint.Range) async {
        guard newRange != range else { return }
        range = newRange
        await load()
    }
}

struct MetricDetailView: View {
    let identifier: String
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: MetricDetailViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                switch viewModel?.state {
                case .loaded(let detail):
                    content(for: detail)
                case .error(let msg):
                    EmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Couldn't load metric",
                        message: msg,
                        actionTitle: "Retry"
                    ) { Task { await viewModel?.load() } }
                default:
                    LoadingShimmerCard()
                    LoadingShimmerCard()
                }
            }
            .padding(SparkSpacing.lg)
        }
        .background(Color.sparkSurface.ignoresSafeArea())
        .navigationTitle("Metric")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: identifier) {
            if viewModel == nil {
                viewModel = MetricDetailViewModel(
                    identifier: identifier,
                    apiClient: appModel.apiClient
                )
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(for detail: MetricDetail) -> some View {
        heroSection(detail)
        rangePicker(detail)
        chartCard(detail)
        legend(detail)
        if let compares = detail.compares, !compares.isEmpty {
            compareSection(compares)
        }
        anomalyList(detail)
    }

    // MARK: - Hero

    private func heroSection(_ detail: MetricDetail) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SectionLabel("\(detail.domain) · \(detail.id)")
            Text(detail.title)
                .font(SparkFonts.display(.title, weight: .bold))
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.lg) {
                if let today = detail.today {
                    Text(format(value: today, unit: detail.unit))
                        .font(SparkFonts.display(.largeTitle, weight: .bold))
                        .foregroundStyle(Color.domainTint(for: detail.domain))
                        .accessibilityLabel("Today \(format(value: today, unit: detail.unit))")
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let avg = detail.average30d, let today = detail.today {
                        Text(deltaLabel(today: today, average: avg))
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(today >= avg ? Color.sparkSuccess : Color.sparkWarning)
                    }
                    if let avg = detail.average30d {
                        Text("30d avg \(format(value: avg, unit: detail.unit))")
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func deltaLabel(today: Double, average: Double) -> String {
        let diff = today - average
        let sign = diff >= 0 ? "+" : ""
        return "\(sign)\(formatNumber(diff)) vs avg"
    }

    // MARK: - Range picker

    private func rangePicker(_ detail: MetricDetail) -> some View {
        let bound = Binding<MetricsEndpoint.Range>(
            get: { viewModel?.range ?? .thirtyDays },
            set: { newValue in Task { await viewModel?.setRange(newValue) } }
        )

        return Picker("Range", selection: bound) {
            ForEach(MetricsEndpoint.Range.allCases, id: \.self) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Date range")
    }

    // MARK: - Chart

    private func chartCard(_ detail: MetricDetail) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                MetricTrendChart(
                    series: detail.series,
                    baseline: detail.baseline,
                    anomalies: detail.anomalies,
                    valueForAnomaly: { detail.valueForAnomaly($0) },
                    tint: Color.domainTint(for: detail.domain)
                )
            }
        }
    }

    private func legend(_ detail: MetricDetail) -> some View {
        HStack(spacing: SparkSpacing.lg) {
            HStack(spacing: SparkSpacing.xs + 2) {
                Rectangle()
                    .fill(Color.domainTint(for: detail.domain))
                    .frame(width: 14, height: 2)
                Text(detail.title.lowercased())
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
            if detail.baseline != nil {
                HStack(spacing: SparkSpacing.xs + 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(.secondary.opacity(0.4),
                                style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .frame(width: 14, height: 8)
                    Text("baseline")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !detail.anomalies.isEmpty {
                HStack(spacing: SparkSpacing.xs + 2) {
                    Circle()
                        .fill(Color.sparkWarning)
                        .frame(width: 8, height: 8)
                    Text("anomaly")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Compare grid

    private func compareSection(_ compares: [MetricDetail.Compare]) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SectionLabel("Compare")
            HStack(spacing: SparkSpacing.sm) {
                ForEach(compares.prefix(3)) { compare in
                    GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(compare.label.uppercased())
                                .font(SparkTypography.monoSmall)
                                .foregroundStyle(.secondary)
                            Text(formatNumber(compare.value))
                                .font(SparkFonts.display(.title3, weight: .bold))
                            if let delta = compare.delta {
                                Text("\(delta >= 0 ? "+" : "")\(formatNumber(delta))")
                                    .font(SparkTypography.captionStrong)
                                    .foregroundStyle(delta >= 0 ? Color.sparkSuccess : Color.sparkWarning)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Anomalies list

    @ViewBuilder
    private func anomalyList(_ detail: MetricDetail) -> some View {
        if !detail.anomalies.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("Recent anomalies")
                ForEach(detail.anomalies) { anomaly in
                    GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
                        HStack(spacing: SparkSpacing.md) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.sparkWarning)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(anomaly.note ?? "Anomaly")
                                    .font(SparkTypography.bodySmall)
                                Text(Self.dateFormatter.string(from: anomaly.date))
                                    .font(SparkTypography.monoSmall)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Text(anomaly.severity.uppercased())
                                .font(SparkTypography.monoSmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Formatting

    private func format(value: Double, unit: String?) -> String {
        let formatted = formatNumber(value)
        guard let unit, !unit.isEmpty else { return formatted }
        return "\(formatted) \(unit)"
    }

    private func formatNumber(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 100 || absValue == floor(absValue) {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()
}
