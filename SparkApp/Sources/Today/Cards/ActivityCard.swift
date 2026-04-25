import SparkUI
import SwiftUI

struct ActivityCard: View {
    let activity: ActivitySnapshot

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                GlassCardHeader(
                    icon: "figure.walk",
                    tint: .domainActivity,
                    title: "Activity"
                )

                HStack(alignment: .center, spacing: SparkSpacing.md) {
                    ActivityRings(
                        move: activity.moveProgress,
                        exercise: activity.exerciseProgress,
                        stand: activity.standProgress
                    )
                    .frame(width: 88, height: 88)

                    VStack(alignment: .leading, spacing: 4) {
                        if let steps = activity.steps {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(formatSteps(steps))
                                    .font(SparkFonts.display(.title, weight: .bold))
                                Text("/ \(formatSteps(activity.stepsGoal))")
                                    .font(SparkTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("\(steps) of \(activity.stepsGoal) steps")
                        }

                        if let cal = activity.activeCalories {
                            Text("\(cal) cal active")
                                .font(SparkTypography.bodySmall)
                                .foregroundStyle(.secondary)
                        }

                        if let workout = activity.lastWorkout {
                            Text(workout)
                                .font(SparkTypography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func formatSteps(_ count: Int) -> String {
        if count >= 1_000 {
            let k = Double(count) / 1_000
            return String(format: "%.1fk", k)
        }
        return String(count)
    }
}
