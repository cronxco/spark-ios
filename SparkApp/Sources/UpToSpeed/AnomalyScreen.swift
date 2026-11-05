import SparkKit
import SparkUI
import SwiftUI

/// Renders an anomaly Up to Speed item in Flint's voice: what moved, one hero
/// reading with its comparison and trend, and chips to act.
struct AnomalyScreen: View {
    let item: UpToSpeedItem
    let viewModel: UpToSpeedViewModel
    var isActive: Bool = true

    @Environment(AppModel.self) private var appModel
    @State private var metricDetail: MetricDetail?
    @State private var isLoadingMetric = false
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
                Text(headline)
                    .font(SparkTypography.heroSmall)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                heroCard
                narrative
                if acknowledged {
                    acknowledgedBadge
                } else {
                    actionChips
                }
            }
        }
        .task { await loadMetric() }
        // Covers both "Not worth flagging" and a confirmed mute.
        .sensoryFeedback(.impact(weight: .light), trigger: acknowledged) { _, new in new }
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

    // MARK: - Headline

    /// Plain statement of what moved, in sentence case. The "Unusual" chip
    /// that sat above it is gone: the byline already says "Something
    /// unusual", and a chip is for a state that needs acting on (§12.9).
    private var headline: String {
        let name = anomaly?.sentenceCaseName ?? "A metric"
        switch anomaly?.movement ?? .level {
        case .below: return "\(name) is below its usual range."
        case .above: return "\(name) is above its usual range."
        case .level: return "\(name) is off its usual range."
        }
    }

    // MARK: - Hero

    /// One hero (§1.1): the reading, one comparison line in the §3.4 shape,
    /// and the trend with its usual band underneath, all on one content
    /// surface. It replaces three glass tiles (Now, Baseline, Run) that
    /// repeated each other and the paragraph below.
    private var heroCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                eyebrow
                heroValue
                if let comparison = anomaly?.comparisonText {
                    comparisonLine(comparison)
                } else if let usual = anomaly?.baselineText {
                    // A banded reading with no numbers ("Adequate") still
                    // needs its usual value to read as unusual.
                    Text("Usually \(usual)")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
                chart
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var eyebrow: some View {
        HStack(spacing: SparkSpacing.sm) {
            SparkGlyph(glyph, relativeTo: .caption)
                .foregroundStyle(EntityPresentation.tint(domain: anomaly?.domain))
            Text(anomaly?.sentenceCaseName ?? "Reading")
                .font(SparkTypography.captionStrong)
                .foregroundStyle(.secondary)
        }
    }

    /// "oura.had_heart_rate.bpm" draws the heart, by its action.
    private var glyph: SparkIcon {
        let parts = (anomaly?.metric ?? "").split(separator: ".").map(String.init)
        let action = parts.count > 1 ? parts[1] : parts.first
        return SparkIcon.event(action: action, service: anomaly?.service, domain: anomaly?.domain)
    }

    private var heroValue: some View {
        let parts: (value: String, unit: String?) = anomaly?.heroParts ?? (value: "—", unit: nil)
        return HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
            Text(parts.value)
                .font(SparkFonts.display(size: 44, relativeTo: .largeTitle))
                .monospacedDigit()
                .foregroundStyle(Color.sparkHero(domain: anomaly?.domain))
            if let unit = parts.unit {
                // About 55% of the value (§4).
                Text(unit)
                    .font(SparkFonts.display(size: 24, relativeTo: .title2, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    /// The arrow points the way the reading moved and takes its colour from
    /// whether that is welcome (§3.4); the words stay secondary.
    private func comparisonLine(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
            SparkGlyph(arrowIcon, size: 12, relativeTo: .caption)
                .foregroundStyle(valenceTint)
            Text(text)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var arrowIcon: SparkIcon {
        switch anomaly?.movement ?? .level {
        case .above: .increase
        case .below: .decrease
        case .level: .steady
        }
    }

    /// Whether the move is welcome, which direction alone cannot say: a
    /// balance rising is good news, a cardiovascular age rising is not.
    private var valenceTint: Color {
        switch anomaly?.valence ?? .neutral {
        case .good: .sparkSuccess
        case .bad: .sparkError
        case .neutral: .secondary
        }
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

    /// Shown inline rather than behind "See the week": the usual band is
    /// what makes the reading unusual, so it belongs beside the number.
    @ViewBuilder
    private var chart: some View {
        if let detail = metricDetail {
            MetricTrendChart(
                series: detail.series,
                baseline: detail.baseline,
                anomalies: detail.anomalies,
                valueForAnomaly: { detail.valueForAnomaly($0) },
                tint: EntityPresentation.tint(domain: anomaly?.domain),
                height: 140
            )
            .padding(.top, SparkSpacing.xs)
            .accessibilityLabel("Trend with the usual range")
        } else if isLoadingMetric {
            LoadingShimmer()
                .frame(height: 140)
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
        // The glyph carries the success colour; as text it fails on the
        // light wash (§3.1).
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
            SparkGlyph(.success, size: 14, relativeTo: .subheadline)
                .foregroundStyle(Color.sparkSuccess)
            Text("Noted. I'll ease off on this one.")
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.primary)
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkContentSurface(radius: SparkRadii.md, tint: Color.sparkSuccess.opacity(0.1))
    }

    // MARK: - Data

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
