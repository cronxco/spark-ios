import SparkKit
import SparkUI
import SwiftData
import SwiftUI

struct TodayView: View {
    let date: Date
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TodayViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                header

                if let summary = viewModel?.cached {
                    content(for: summary)
                } else if viewModel?.networkState == .loading {
                    loadingPlaceholders
                } else if case .error(let message) = viewModel?.networkState {
                    EmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Couldn't load today",
                        message: message,
                        actionTitle: "Retry",
                        action: { Task { await viewModel?.refresh() } }
                    )
                } else {
                    loadingPlaceholders
                }

                Text("History heatmap coming soon")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SparkSpacing.xl)
            }
            .padding(SparkSpacing.lg)
        }
        .background(Color.sparkSurface.ignoresSafeArea())
        .refreshable { await viewModel?.refresh() }
        .task(id: date) {
            if viewModel == nil {
                viewModel = TodayViewModel(
                    date: date,
                    apiClient: appModel.apiClient,
                    container: appModel.container
                )
            }
            await viewModel?.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text(Greeting.for(date: date))
                .font(SparkTypography.titleStrong)
            Text(Self.dateLabel.string(from: date))
                .font(SparkTypography.bodyStrong)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func content(for summary: DaySummary) -> some View {
        if !summary.sections.hasAnyContent {
            EmptyState(
                systemImage: "sparkles",
                title: "Nothing yet for today",
                message: "We'll fill this in as integrations sync."
            )
        } else {
            LazyVStack(spacing: SparkSpacing.md) {
                ForEach(domainRows(from: summary.sections)) { row in
                    MetricCard(
                        title: row.title,
                        value: row.value,
                        unit: row.unit,
                        caption: row.caption
                    )
                }
            }

            if !summary.anomalies.isEmpty {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    Text("Anomalies")
                        .font(SparkTypography.titleStrong)
                    ForEach(summary.anomalies) { anomaly in
                        EventRow(
                            title: anomaly.metric ?? "Anomaly",
                            subtitle: anomaly.description,
                            timestamp: anomaly.detectedAt ?? .now,
                            iconSystemName: "exclamationmark.triangle.fill",
                            tintColor: .sparkWarning
                        )
                    }
                }
                .padding(.top, SparkSpacing.md)
            }
        }
    }

    private var loadingPlaceholders: some View {
        VStack(spacing: SparkSpacing.md) {
            LoadingShimmerCard()
            LoadingShimmerCard()
            LoadingShimmerCard()
        }
    }

    private func domainRows(from sections: DaySummary.Sections) -> [DomainRow] {
        let all: [(String, [String: AnyCodable]?)] = [
            ("Health", sections.health),
            ("Activity", sections.activity),
            ("Money", sections.money),
            ("Media", sections.media),
            ("Knowledge", sections.knowledge),
        ]
        return all.compactMap { (title, payload) -> DomainRow? in
            guard let payload, !payload.isEmpty else { return nil }
            let summaryLine = payload.compactMap { key, value -> String? in
                guard let rendered = value.renderForCard() else { return nil }
                return "\(key.replacingOccurrences(of: "_", with: " ")): \(rendered)"
            }.prefix(3).joined(separator: " · ")
            return DomainRow(
                id: title,
                title: title,
                value: payload.count.description,
                unit: payload.count == 1 ? "signal" : "signals",
                caption: summaryLine.isEmpty ? nil : summaryLine
            )
        }
    }

    private struct DomainRow: Identifiable {
        let id: String
        let title: String
        let value: String
        let unit: String?
        let caption: String?
    }

    private static let dateLabel: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f
    }()
}

private enum Greeting {
    static func `for`(date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5 ..< 12: return "Good morning"
        case 12 ..< 18: return "Good afternoon"
        case 18 ..< 23: return "Good evening"
        default: return "Hello"
        }
    }
}

private extension DaySummary.Sections {
    var hasAnyContent: Bool {
        [health, activity, money, media, knowledge]
            .contains { ($0?.isEmpty == false) }
    }
}

private extension AnyCodable {
    /// Lightweight renderer so we can pull a short display string out of the
    /// dynamic-shape sections payload without a full typed model (Phase 2).
    func renderForCard() -> String? {
        switch value {
        case .null: return nil
        case .bool(let v): return v ? "yes" : "no"
        case .int(let v): return String(v)
        case .double(let v): return String(format: "%.1f", v)
        case .string(let v): return v
        case .array(let v): return v.isEmpty ? nil : "\(v.count) items"
        case .object: return nil
        }
    }
}
