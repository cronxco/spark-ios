import SwiftUI

/// One row in the Today heatmap — a 45-day intensity strip per domain.
public struct DomainHeatmapRow: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let values: [Double]
    public let tint: Color

    public init(id: String, label: String, values: [Double], tint: Color) {
        self.id = id
        self.label = label
        self.values = values
        self.tint = tint
    }
}

/// Small-multiples heatmap pinned to the bottom of Today. Each row is a
/// 45-day strip per domain, with intensity derived from the row's tint.
/// Communicates rhythm without bombarding the chrome with colour.
public struct Heatmap45: View {
    public let rows: [DomainHeatmapRow]
    public let cellSpacing: CGFloat
    public let labelWidth: CGFloat

    public init(
        rows: [DomainHeatmapRow],
        cellSpacing: CGFloat = 1.5,
        labelWidth: CGFloat = 56
    ) {
        self.rows = rows
        self.cellSpacing = cellSpacing
        self.labelWidth = labelWidth
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            ForEach(rows) { row in
                HStack(spacing: SparkSpacing.sm) {
                    Text(row.label.uppercased())
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                        .frame(width: labelWidth, alignment: .leading)
                        .accessibilityHidden(true)

                    HStack(spacing: cellSpacing) {
                        ForEach(Array(row.values.suffix(45).enumerated()), id: \.offset) { _, v in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(row.tint.opacity(max(0.05, min(v, 1.0))))
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(row.label) over the last 45 days")
            }
        }
    }
}

/// Deterministic heatmap fixture so Today renders before the backend ships
/// the 45-day endpoint. Replace once `/api/v1/mobile/heatmap` is live.
public enum HeatmapPlaceholder {
    public static func generate(seed: UInt64 = 12_345, length: Int = 45) -> [String: [Double]] {
        var s = seed
        let lcg: () -> Double = {
            s = s &* 9_301 &+ 49_297
            s = s % 233_280
            return Double(s) / 233_280.0
        }
        return ["sleep", "activity", "spend", "mood"].reduce(into: [:]) { acc, key in
            var row: [Double] = []
            for i in 0 ..< length {
                let weekly = sin(Double(i) / 3.5) * 0.25 + 0.55
                row.append(max(0.05, min(1.0, weekly + (lcg() - 0.5) * 0.4)))
            }
            acc[key] = row
        }
    }
}

#Preview("Heatmap45") {
    let raw = HeatmapPlaceholder.generate()
    Heatmap45(rows: [
        .init(id: "sleep", label: "Sleep", values: raw["sleep"] ?? [], tint: .domainHealth),
        .init(id: "activity", label: "Motion", values: raw["activity"] ?? [], tint: .domainActivity),
        .init(id: "spend", label: "Spend", values: raw["spend"] ?? [], tint: .domainMoney),
        .init(id: "mood", label: "Mood", values: raw["mood"] ?? [], tint: .sparkSuccess),
    ])
    .padding()
    .background(Color.sparkSurface)
}
