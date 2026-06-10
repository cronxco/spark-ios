import SparkKit
import SparkUI
import SwiftUI

/// Renders an anomaly Up to Speed item with a metric trend chart
/// and controls to acknowledge or suppress the anomaly.
struct AnomalyScreen: View {
    let item: UpToSpeedItem
    let viewModel: UpToSpeedViewModel

    @Environment(AppModel.self) private var appModel
    @State private var metricDetail: MetricDetail?
    @State private var isLoadingMetric = false
    @State private var showSuppressSheet = false
    @State private var acknowledgeNote: String = ""
    @State private var isAcknowledging = false
    @State private var acknowledged = false

    private var anomaly: Anomaly? {
        if case .anomaly(let a) = item.payload { return a }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                header
                chartSection
                anomalyDetail
                if !acknowledged {
                    actionButtons
                } else {
                    acknowledgedBadge
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, 152)
            .padding(.bottom, SparkSpacing.xxl)
        }
        .scrollContentBackground(.hidden)
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

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text("Anomaly Detected")
                .font(SparkTypography.caption)
                .foregroundStyle(Color.sparkWarning)
                .tracking(1.2)
                .textCase(.uppercase)

            Text(anomaly?.displayName ?? anomaly?.metric ?? "Metric Anomaly")
                .font(SparkTypography.heroSmall)
                .foregroundStyle(.primary)

            if let direction = anomaly?.direction {
                directionPill(direction)
            }
        }
    }

    private func directionPill(_ direction: String) -> some View {
        let isUp = direction.lowercased().contains("up") || direction.lowercased() == "high"
        return HStack(spacing: 4) {
            Image(systemName: isUp ? "arrow.up" : "arrow.down")
            Text(direction.capitalized)
        }
        .font(SparkTypography.bodySmall)
        .foregroundStyle(Color.sparkWarning)
        .padding(.horizontal, SparkSpacing.md)
        .padding(.vertical, SparkSpacing.xs)
        .background(Capsule().fill(Color.sparkWarning.opacity(0.2)))
    }

    @ViewBuilder
    private var chartSection: some View {
        if let detail = metricDetail {
            MetricTrendChart(
                series: detail.series,
                baseline: detail.baseline,
                anomalies: detail.anomalies,
                valueForAnomaly: { _ in anomaly?.currentValue }
            )
            .frame(height: 140)
        } else if isLoadingMetric {
            LoadingShimmer()
                .frame(height: 140)
                .cornerRadius(SparkRadii.md)
        }
    }

    @ViewBuilder
    private var anomalyDetail: some View {
        if let anomaly {
            GlassCard {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    if let current = anomaly.currentValue, let baseline = anomaly.baselineValue {
                        detailRow(label: "Current", value: String(format: "%.1f", current))
                        detailRow(label: "Baseline", value: String(format: "%.1f", baseline))
                    }
                    if let deviation = anomaly.deviation {
                        detailRow(label: "Deviation", value: String(format: "%+.1f", deviation))
                    }
                    if let streak = anomaly.streakDays, streak > 1 {
                        detailRow(label: "Streak", value: "\(streak) days")
                    }
                }
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(SparkTypography.monoSmall)
                .foregroundStyle(.primary)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: SparkSpacing.md) {
            PillButton("Acknowledge", systemImage: "checkmark") {
                Task { await acknowledge(note: acknowledgeNote) }
            }
            .disabled(isAcknowledging)

            Button("Suppress for a while") {
                showSuppressSheet = true
            }
            .font(SparkTypography.bodySmall)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
    }

    private var acknowledgedBadge: some View {
        HStack(spacing: SparkSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.sparkSuccess)
            Text("Acknowledged")
                .font(SparkTypography.bodySmall)
                .foregroundStyle(Color.sparkSuccess)
        }
        .padding(SparkSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: SparkRadii.sm)
                .fill(Color.sparkSuccess.opacity(0.1))
        )
    }

    // MARK: - Actions

    private func loadMetric() async {
        guard let metric = anomaly?.metric, metricDetail == nil else { return }
        isLoadingMetric = true
        do {
            metricDetail = try await appModel.apiClient.request(MetricsEndpoint.detail(identifier: metric))
        } catch {}
        isLoadingMetric = false
    }

    private func acknowledge(note: String?) async {
        isAcknowledging = true
        do {
            _ = try await appModel.apiClient.request(
                AnomaliesEndpoint.acknowledge(id: item.id, note: note)
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
                Section("Suppress anomaly alerts until") {
                    DatePicker("Date", selection: $suppressUntil, displayedComponents: .date)
                }
                Section("Note (optional)") {
                    TextField("Add a note…", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Suppress Anomaly")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Suppress") {
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
