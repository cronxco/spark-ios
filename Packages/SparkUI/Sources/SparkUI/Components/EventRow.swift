import SwiftUI

public struct EventRow: View {
    let title: String
    let subtitle: String?
    let timestamp: Date
    let iconSystemName: String
    let tintColor: Color

    public init(
        title: String,
        subtitle: String? = nil,
        timestamp: Date,
        iconSystemName: String,
        tintColor: Color = .sparkAccent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.timestamp = timestamp
        self.iconSystemName = iconSystemName
        self.tintColor = tintColor
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.md) {
            Image(systemName: iconSystemName)
                .font(.title3)
                .foregroundStyle(tintColor)
                .frame(width: 28, height: 28)
                .sparkGlass(.circle, tint: tintColor.opacity(0.25))
            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                Text(title)
                    .font(SparkTypography.bodyStrong)
                if let subtitle {
                    Text(subtitle)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: SparkSpacing.md)
            Text(timestamp, style: .time)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, SparkSpacing.sm)
    }
}

#Preview {
    VStack(spacing: SparkSpacing.xs) {
        EventRow(title: "Morning coffee", subtitle: "Monmouth, SE1", timestamp: .now, iconSystemName: "cup.and.saucer.fill")
        EventRow(title: "7.4h sleep", subtitle: "Oura · deep 1.6h", timestamp: .now, iconSystemName: "bed.double.fill", tintColor: .blue)
        EventRow(title: "Monzo · £4.50", subtitle: "Café debit", timestamp: .now, iconSystemName: "creditcard.fill", tintColor: .sparkPositive)
    }
    .padding()
    .background(Color.sparkSurface)
}
