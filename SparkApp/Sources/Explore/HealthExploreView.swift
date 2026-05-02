import SparkUI
import SwiftUI

struct HealthExploreView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SparkSpacing.lg) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: SparkSpacing.md) {
                            GlassCardHeader(
                                icon: "figure.walk",
                                tint: .domainActivity,
                                title: "Activity"
                            )
                            EmptyState(
                                systemImage: "figure.walk.circle",
                                title: "Activity Rings",
                                message: "Steps, calories, exercise and stand hours — coming in Phase 3."
                            )
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: SparkSpacing.md) {
                            GlassCardHeader(
                                icon: "moon.zzz.fill",
                                tint: .sparkOcean,
                                title: "Sleep"
                            )
                            EmptyState(
                                systemImage: "bed.double",
                                title: "Sleep Analysis",
                                message: "Duration, quality, bedtime and wake trends — coming in Phase 3."
                            )
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: SparkSpacing.md) {
                            GlassCardHeader(
                                icon: "heart.fill",
                                tint: .domainHealth,
                                title: "Heart & Recovery"
                            )
                            EmptyState(
                                systemImage: "waveform.path.ecg",
                                title: "Heart Rate & HRV",
                                message: "Resting HR, heart rate variability and respiratory rate — coming in Phase 3."
                            )
                        }
                    }
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.vertical, SparkSpacing.xl)
            }
            .navigationTitle("Health")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
