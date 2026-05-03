import SwiftUI

/// Inline status indicator — a coloured dot plus a short message. Used as
/// the "All baselines holding" / "N anomalies" pill on Today and elsewhere
/// where a quiet state needs to be readable in one glance.
public struct StatusPill: View {
    public enum Tone: Sendable {
        case ok
        case warning
        case neutral
    }

    public let tone: Tone
    public let message: String
    public let trailing: String?

    public init(_ tone: Tone, message: String, trailing: String? = nil) {
        self.tone = tone
        self.message = message
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: SparkSpacing.sm) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Text(message)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.primary)
            Spacer(minLength: SparkSpacing.sm)
            if let trailing {
                Text(trailing)
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.vertical, SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkGlass(.roundedRect(SparkRadii.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var dotColor: Color {
        switch tone {
        case .ok: .sparkSuccess
        case .warning: .sparkWarning
        case .neutral: .secondary
        }
    }

    private var accessibilityText: String {
        if let trailing { "\(message). \(trailing)." } else { message }
    }
}

#Preview("StatusPill") {
    VStack(spacing: 12) {
        StatusPill(.ok, message: "All baselines holding", trailing: "0 anomalies")
        StatusPill(.warning, message: "Resting HR ↑ 18 bpm", trailing: "1 anomaly")
        StatusPill(.neutral, message: "Last sync 3 min ago")
    }
    .padding()
    .background(Color.sparkSurface)
}
