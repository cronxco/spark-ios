import SparkKit
import SparkUI
import SwiftUI

struct SparkDetailHero: View {
    let eyebrow: String
    let status: String?
    let title: String
    let subtitle: String?
    let value: String?
    var valueTint: Color = .sparkAccent
    var valueAlignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Text(eyebrow)
                .font(SparkTypography.mono)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .lineLimit(2)

            if let status, !status.isEmpty {
                Text(status)
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(title)
                .font(SparkFonts.display(.largeTitle, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
                .accessibilityAddTraits(.isHeader)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(SparkTypography.title)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if let value, !value.isEmpty {
                Text(value)
                    .font(SparkFonts.display(.largeTitle, weight: .bold))
                    .foregroundStyle(valueTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.52)
                    .frame(maxWidth: .infinity, alignment: valueAlignment == .trailing ? .trailing : .leading)
                    .multilineTextAlignment(valueAlignment == .trailing ? .trailing : .leading)
                    .padding(.top, SparkSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct SparkDetailSectionHeader: View {
    let title: String
    let trailing: String?

    init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(SparkFonts.display(.title2, weight: .bold))
                .foregroundStyle(.primary)

            Spacer(minLength: SparkSpacing.sm)

            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
        }
    }
}

struct SparkDetailInsightCard: View {
    var label = "Insight"
    let text: String
    var tint: Color = .sparkWarning

    var body: some View {
        GlassCard(radius: SparkRadii.lg, padding: SparkSpacing.md, tint: tint.opacity(0.06)) {
            HStack(alignment: .top, spacing: SparkSpacing.sm) {
                Circle()
                    .fill(tint)
                    .frame(width: 12, height: 12)
                    .padding(.top, 5)
                    .background {
                        Circle()
                            .fill(tint.opacity(0.2))
                            .frame(width: 26, height: 26)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(SparkTypography.mono)
                        .fontWeight(.semibold)
                        .foregroundStyle(tint)
                        .textCase(.uppercase)

                    Text(text)
                        .font(SparkTypography.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(text)")
    }
}

struct SparkDetailValueTile: View {
    let label: String
    let value: String
    var subtitle: String?
    var tint: Color = .sparkAccent

    var body: some View {
        GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                Text(label)
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)

                Text(value)
                    .font(SparkFonts.display(.title2, weight: .bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct SparkDetailLinkedRow: View {
    let title: String
    let subtitle: String?
    let trailing: String?
    var tint: Color = .sparkAccent

    var body: some View {
        GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
            HStack(alignment: .center, spacing: SparkSpacing.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if let trailing, !trailing.isEmpty {
                    Text(trailing)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

enum SparkDetailFormatters {
    static func shortDate(_ date: Date) -> String {
        SparkDateFormatting.shortDate(date)
    }

    static func shortTime(_ date: Date) -> String {
        SparkDateFormatting.shortTime(date)
    }

    static func compactDateTime(_ date: Date) -> String {
        SparkDateFormatting.compactDateTime(date)
    }
}

extension Color {
    static func domainTint(for domain: String) -> Color {
        EntityPresentation.tint(domain: domain)
    }
}
