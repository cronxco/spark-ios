import SparkKit
import SparkUI
import SwiftUI

/// Bottom sheet that lists the points currently visible in the map region.
/// Tapping a row pushes a `DetailRoute` (place / event) onto the Map tab's
/// navigation stack.
struct MapBottomSheet: View {
    let points: [MapDataPoint]
    let onSelect: (MapDataPoint) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if points.isEmpty {
                    EmptyState(
                        systemImage: "mappin.slash",
                        title: "Nothing here",
                        message: "Pan the map or change the day to see your visits and events."
                    )
                } else {
                    List {
                        ForEach(points) { point in
                            Button {
                                onSelect(point)
                            } label: {
                                MapBottomSheetRow(point: point)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("In view")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct MapBottomSheetRow: View {
    let point: MapDataPoint

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            DomainGlyph(icon: glyph, tint: tint, size: 30)
            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                Text(point.title)
                    .font(SparkTypography.bodyStrong)
                    .lineLimit(1)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: SparkSpacing.sm)
            if let timeLabel {
                Text(timeLabel)
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, SparkSpacing.xs)
        .contentShape(Rectangle())
    }

    private var subtitle: String? {
        if let s = point.subtitle, !s.isEmpty { return s }
        return point.service
    }

    private var timeLabel: String? {
        guard let time = point.time else { return nil }
        return Self.timeFormatter.string(from: time)
    }

    private var glyph: String {
        switch point.kind {
        case .place: "mappin.and.ellipse"
        case .transaction: "creditcard.fill"
        case .workout: "figure.run"
        case .event: "circle.dashed"
        }
    }

    private var tint: Color {
        switch point.kind {
        case .place: .sparkAccent
        case .transaction: .domainMoney
        case .workout: .domainActivity
        case .event: .domainKnowledge
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
