import SparkKit
import SparkUI
import SwiftUI

/// Horizontal scrolling strip of at-a-glance stat tiles.
/// Replaces the large domain cards in the Today redesign.
struct StatStripView: View {
    let snapshot: TodaySnapshot

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if let steps = snapshot.activity?.steps {
                    StatTile(
                        icon: "figure.walk",
                        tint: .domainActivity,
                        value: formatSteps(steps),
                        label: "Steps",
                        entityType: "metric",
                        entityIdentifier: "apple_health.steps"
                    )
                }
                if let display = snapshot.money?.spentTodayDisplay {
                    StatTile(
                        icon: "sterlingsign.circle.fill",
                        tint: .domainMoney,
                        value: display,
                        label: "Spent",
                        entityType: "spend",
                        entityIdentifier: Self.isoKey(for: snapshot.date)
                    )
                }
                if let score = snapshot.health?.sleepScore {
                    StatTile(
                        icon: "moon.zzz.fill",
                        tint: .domainHealth,
                        value: "\(score)",
                        label: "Sleep",
                        entityType: "metric",
                        entityIdentifier: "oura.sleep_score"
                    )
                }
                if let bookmarks = snapshot.knowledge?.bookmarksToday, bookmarks > 0 {
                    StatTile(
                        icon: "book.fill",
                        tint: .domainKnowledge,
                        value: "\(bookmarks)",
                        label: "Read"
                    )
                }
                StatTile(
                    icon: "heart.fill",
                    tint: .domainHealth,
                    value: snapshot.health?.restingHeartRate.map { "\($0)" } ?? "—",
                    label: "Heart",
                    entityType: "metric",
                    entityIdentifier: "apple_health.resting_heart_rate"
                )
            }
            .padding(.horizontal, SparkSpacing.lg)
        }
        .padding(.horizontal, -SparkSpacing.lg)
    }

    private func formatSteps(_ count: Int) -> String {
        count >= 1_000 ? String(format: "%.1fk", Double(count) / 1_000) : String(count)
    }

    private static func isoKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

private struct StatTile: View {
    let icon: String
    let tint: Color
    let value: String
    let label: String
    var entityType: String? = nil
    var entityIdentifier: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(SparkTypography.heroSmall)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(SparkTypography.monoSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 90, alignment: .leading)
        .sparkGlass(.roundedRect(16))
        .sparkAppEntityIdentifier(type: entityType ?? "", identifier: entityIdentifier)
    }
}
