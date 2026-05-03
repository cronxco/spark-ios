import SparkUI
import SwiftUI

struct SleepCard: View {
    let health: HealthSnapshot

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                GlassCardHeader(
                    icon: "moon.fill",
                    tint: .domainHealth,
                    title: "Sleep",
                    trailing: "last night"
                )

                HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.md) {
                    if let score = health.sleepScore {
                        Text("\(score)")
                            .font(SparkFonts.display(.largeTitle, weight: .bold))
                            .foregroundStyle(Color.domainHealth)
                            .accessibilityLabel("Sleep score \(score)")
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if let duration = health.sleepDurationMinutes {
                            Text(formatDuration(minutes: duration))
                                .font(SparkTypography.bodyStrong)
                        }
                        if let bedtime = health.bedtime, let wake = health.wakeTime {
                            Text("\(bedtime) → \(wake)")
                                .font(SparkTypography.monoSmall)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)
                }

                if !hypnogramStages.isEmpty {
                    SleepHypnogram(stages: hypnogramStages, tint: .domainHealth)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func formatDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let m = minutes % 60
        return "\(hours)h \(m)m in bed"
    }

    /// Phase 2 shows a synthetic hypnogram derived from total deep+REM share
    /// since the backend ships only the totals; we replace this with real
    /// stage data when the HealthKit ingestion delivers per-stage timeline.
    private var hypnogramStages: [SleepHypnogram.Stage] {
        let pattern: [Double] = [0.4, 0.6, 0.85, 0.9, 0.95, 1.0, 0.85, 0.7, 0.45, 0.3,
                                 0.5, 0.7, 0.9, 0.7, 0.4, 0.5, 0.6, 0.45, 0.3, 0.5,
                                 0.65, 0.85, 0.9, 0.7, 0.5, 0.4, 0.55, 0.3]
        guard health.sleepDurationMinutes != nil || health.sleepScore != nil else { return [] }
        return pattern.enumerated().map { SleepHypnogram.Stage(id: $0.offset, depth: $0.element) }
    }
}
