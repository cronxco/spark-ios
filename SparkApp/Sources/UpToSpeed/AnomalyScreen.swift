import SparkKit
import SparkUI
import SwiftUI

/// Renders an anomaly Up to Speed item in Flint's voice — an "unusual" flag, a
/// glass metric readout, the trend behind it, and chips to act.
struct AnomalyScreen: View {
    let item: UpToSpeedItem
    let viewModel: UpToSpeedViewModel
    var isActive: Bool = true

    @Environment(AppModel.self) private var appModel
    @State private var metricDetail: MetricDetail?
    @State private var isLoadingMetric = false
    @State private var showChart = false
    @State private var showSuppressSheet = false
    @State private var isAcknowledging = false
    @State private var acknowledged = false

    private var anomaly: Anomaly? {
        if case .anomaly(let a) = item.payload { return a }
        return nil
    }

    var body: some View {
        StoryScreenScaffold(flintByline: .init(meta: "Something unusual")) {
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                header
                metricGrid
                narrative
                chartDisclosure
                if acknowledged {
                    acknowledgedBadge
                } else {
                    actionChips
                }
            }
        }
        .task { await loadMetric() }
        .onChange(of: acknowledged) { _, newValue in
            guard newValue else { return }
            viewModel.markAnomalyRead(itemID: item.id)
        }
        .sheet(isPresented: $showSuppressSheet) {
            SuppressSheet(
                anomaly: anomaly,
                apiClient: appModel.apiClient,
                itemID: item.id,
                onDone: { acknowledged = true }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            Text("Unusual")
                .font(SparkTypography.caption)
                .tracking(1.4)
                .foregroundStyle(valenceTint)
                .padding(.horizontal, SparkSpacing.sm)
                .padding(.vertical, 3)
                .overlay(
                    Capsule().stroke(valenceTint.opacity(0.4), lineWidth: 1)
                )

            Text(headline)
                .font(SparkTypography.heroSmall)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Whether the move is welcome, which direction alone cannot say — a
    /// balance rising is good news, a cardiovascular age rising is not. Before
    /// this, every rising number was tinted as a warning.
    private var valenceTint: Color {
        switch anomaly?.valence ?? .neutral {
        case .good: .sparkSuccess
        case .bad: .sparkWarning
        case .neutral: .secondary
        }
    }

    private var valenceEmphasis: MetricDeltaCard.Emphasis {
        switch anomaly?.valence ?? .neutral {
        case .good: .reassuring
        case .bad: .flagged
        case .neutral: .neutral
        }
    }

    /// Plain statement of what moved. The old copy claimed a drop "isn't the
    /// obvious story", which asserts more than a single reading supports.
    private var headline: String {
        let name = anomaly?.displayName ?? anomaly?.metric ?? "A metric"
        guard let direction = anomaly?.direction?.lowercased() else {
            return "\(name) is off its usual range."
        }
        if direction.contains("down") || direction == "low" {
            return "\(name) is below its usual range."
        }
        if direction.contains("up") || direction == "high" {
            return "\(name) is above its usual range."
        }
        return "\(name) is off its usual range."
    }

    // MARK: - Metric grid

    private var metricGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: SparkSpacing.md), GridItem(.flexible(), spacing: SparkSpacing.md)],
            spacing: SparkSpacing.md
        ) {
            if let anomaly {
                MetricDeltaCard(
                    label: "Now",
                    value: anomaly.currentText ?? formatted(anomaly.currentValue),
                    delta: deviationText,
                    emphasis: valenceEmphasis
                )
                MetricDeltaCard(
                    label: "Baseline",
                    value: anomaly.baselineText ?? formatted(anomaly.baselineValue),
                    delta: "typical",
                    emphasis: .neutral
                )
                if let streak = anomaly.streakDays, streak > 1 {
                    MetricDeltaCard(
                        label: "Run",
                        value: "\(streak)",
                        unit: "days",
                        delta: "in a row",
                        emphasis: .neutral
                    )
                }
            }
        }
    }

    /// A percentage change against a fractional baseline is meaningless for a
    /// banded score — "Adequate" is not 37% below "Solid" — so an ordinal
    /// metric says how far it moved in bands instead.
    private var deviationText: String? {
        guard let anomaly else { return nil }

        if anomaly.isOrdinal {
            guard let current = anomaly.currentValue, let baseline = anomaly.baselineValue else { return nil }
            let steps = abs(current - baseline)
            guard steps.isFinite else { return nil }
            guard steps >= 0.5 else { return "off baseline" }
            // String(format:) rather than Int(), which traps out of range.
            return steps < 1.5 ? "a band off" : String(format: "%.0f bands off", steps)
        }

        if let pct = anomaly.percentChange {
            return String(format: "%+.0f%%", pct)
        }

        return anomaly.deviation.map { String(format: "%+.1f", $0) }
    }

    // MARK: - Narrative

    @ViewBuilder
    private var narrative: some View {
        if let streak = anomaly?.streakDays, streak > 1 {
            Text("That's \(streak) days in a row now, which is longer than I'd put down to noise.")
                .font(SparkTypography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("This is far enough off your baseline that I didn't want it to pass without a mention.")
                .font(SparkTypography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartDisclosure: some View {
        if let detail = metricDetail {
            DisclosureGroup(isExpanded: $showChart) {
                MetricTrendChart(
                    series: detail.series,
                    baseline: detail.baseline,
                    anomalies: detail.anomalies,
                    valueForAnomaly: { _ in anomaly?.currentValue }
                )
                .frame(height: 140)
                .padding(.top, SparkSpacing.sm)
            } label: {
                Text("See the week")
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(Color.ember7)
            }
        } else if isLoadingMetric {
            LoadingShimmer()
                .frame(height: 44)
                .cornerRadius(SparkRadii.md)
        }
    }

    // MARK: - Actions

    private var actionChips: some View {
        HStack(spacing: SparkSpacing.sm) {
            Button {
                Task { await acknowledge() }
            } label: {
                chipLabel("Not worth flagging")
            }
            .buttonStyle(.plain)
            .disabled(isAcknowledging)

            Button {
                showSuppressSheet = true
            } label: {
                chipLabel("Mute for a while")
            }
            .buttonStyle(.plain)
        }
    }

    private func chipLabel(_ text: String) -> some View {
        Text(text)
            .font(SparkTypography.captionStrong)
            .foregroundStyle(.primary)
            .padding(.horizontal, SparkSpacing.md)
            .padding(.vertical, SparkSpacing.sm)
            .sparkGlass(.capsule)
    }

    private var acknowledgedBadge: some View {
        Label("Noted — I'll ease off on this one", systemImage: "checkmark.circle.fill")
            .font(SparkTypography.bodySmall)
            .foregroundStyle(Color.sparkSuccess)
            .padding(SparkSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: SparkRadii.md)
                    .fill(Color.sparkSuccess.opacity(0.1))
            )
    }

    // MARK: - Data

    private func formatted(_ value: Double?) -> String {
        // Int(value) traps for out-of-range or non-finite doubles (a
        // mis-scaled/corrupted backend value shouldn't crash this screen).
        guard let value, value.isFinite else { return "—" }
        return value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    private func loadMetric() async {
        guard let metric = anomaly?.metric, metricDetail == nil else { return }
        isLoadingMetric = true
        do {
            metricDetail = try await appModel.apiClient.request(MetricsEndpoint.detail(identifier: metric))
        } catch {}
        isLoadingMetric = false
    }

    private func acknowledge() async {
        isAcknowledging = true
        do {
            _ = try await appModel.apiClient.request(
                AnomaliesEndpoint.acknowledge(id: item.id, note: nil)
            )
            acknowledged = true
        } catch {}
        isAcknowledging = false
    }
}

// MARK: - SuppressSheet

private struct SuppressSheet: View {
    let anomaly: Anomaly?
    let apiClient: APIClient
    let itemID: String
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var suppressUntil: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var note: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Mute anomaly alerts until") {
                    DatePicker("Date", selection: $suppressUntil, displayedComponents: .date)
                }
                Section("Note (optional)") {
                    TextField("Add a note…", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Mute Anomaly")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mute") {
                        Task { await suppress() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func suppress() async {
        isSaving = true
        do {
            _ = try await apiClient.request(
                AnomaliesEndpoint.acknowledge(
                    id: itemID,
                    note: note.isEmpty ? nil : note,
                    suppressUntil: suppressUntil
                )
            )
            onDone()
            dismiss()
        } catch {}
        isSaving = false
    }
}
