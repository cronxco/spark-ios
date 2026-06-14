import SparkUI
import SwiftUI

struct HeroStep: View {
    let proceed: () -> Void

    private struct Feature: Identifiable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
    }

    private let features: [Feature] = [
        Feature(id: "today", icon: "sun.max.fill", title: "Your day, unified", subtitle: "Sleep, activity, money, and events in one feed"),
        Feature(id: "health", icon: "heart.fill", title: "Built on your data", subtitle: "HealthKit, integrations, and smart baselines"),
        Feature(id: "intelligence", icon: "sparkles", title: "Anomalies, explained", subtitle: "Knows when something shifts and tells you why"),
    ]

    var body: some View {
        SparkOnboardingScaffold(icon: "sparkles", title: "Welcome to Spark.") {
            VStack(spacing: SparkSpacing.md) {
                ForEach(features) { feature in
                    HStack(spacing: SparkSpacing.md) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(Color.sparkAccent)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title)
                                .font(SparkTypography.bodyStrong)
                            Text(feature.subtitle)
                                .font(SparkTypography.bodySmall)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, SparkSpacing.lg)
                }
            }
            .padding(.vertical, SparkSpacing.lg)
        } actions: {
            PillButton("Get Started", systemImage: "arrow.right.circle.fill", action: proceed)
        }
        .navigationBarHidden(true)
    }
}
