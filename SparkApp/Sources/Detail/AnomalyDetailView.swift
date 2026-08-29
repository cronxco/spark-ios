import SparkIntelligence
import SparkKit
import SparkUI
import SwiftUI

struct AnomalyDetailView: View {
    let anomalyId: String

    @Environment(AppModel.self) private var appModel
    @State private var entity: AnomalyEntity?
    @State private var isAcknowledging = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                if let entity {
                    content(entity)
                } else if let errorMessage {
                    EmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Couldn't load anomaly",
                        message: errorMessage,
                        actionTitle: "Retry"
                    ) { load() }
                } else {
                    LoadingShimmerCard()
                    LoadingShimmerCard()
                }
            }
            .padding(SparkSpacing.lg)
        }
        .sparkAppBackground()
        .sparkOnscreenEntity(
            type: "anomaly",
            identifier: anomalyId,
            title: entity?.summary ?? "Anomaly"
        )
        .navigationTitle("Anomaly")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: anomalyId) { load() }
    }

    @ViewBuilder
    private func content(_ entity: AnomalyEntity) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            Label("Anomaly", systemImage: "exclamationmark.triangle.fill")
                .font(SparkTypography.caption)
                .foregroundStyle(entity.acknowledged ? Color.secondary : Color.sparkWarning)

            Text(entity.summary)
                .font(SparkTypography.title)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let metric = entity.metric {
                detailRow("Metric", metric)
            }
            if let direction = entity.direction {
                detailRow("Direction", direction.capitalized)
            }
            if let detectedAt = entity.detectedAt {
                detailRow("Detected", Self.dateFormatter.string(from: detectedAt))
            }

            Button {
                Task { await acknowledge(entity) }
            } label: {
                Label(entity.acknowledged ? "Acknowledged" : "Acknowledge", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(entity.acknowledged || isAcknowledging)
        }
        .padding(SparkSpacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: SparkRadii.lg))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(Color.secondary)
            Spacer(minLength: SparkSpacing.md)
            Text(value)
                .font(SparkTypography.body)
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    @MainActor
    private func load() {
        errorMessage = nil
        entity = IntentService.anomalyEntities(matching: [anomalyId]).first
        if entity == nil {
            errorMessage = "This anomaly is not available in the local cache yet."
        }
    }

    @MainActor
    private func acknowledge(_ entity: AnomalyEntity) async {
        guard !entity.acknowledged else { return }
        isAcknowledging = true
        defer { isAcknowledging = false }
        do {
            _ = try await appModel.apiClient.request(AnomaliesEndpoint.acknowledge(id: entity.id))
            IntentService.markAnomalyAcknowledged(id: entity.id)
            load()
        } catch {
            SparkObservability.captureHandled(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
