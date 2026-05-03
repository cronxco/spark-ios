import ActivityKit
import SparkKit
import SwiftUI
import WidgetKit

// MARK: - Lock Screen layout

struct SleepLockScreenView: View {
    let context: ActivityViewContext<SleepActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            Text(phaseEmoji)
                .font(.system(size: 36))

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.phaseLabel)
                    .font(.headline.weight(.semibold))

                if let dur = context.state.durationDisplay {
                    Text(dur)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let wake = context.attributes.targetWakeTime {
                    Text("Wake at \(timeString(wake))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let score = context.state.sleepScore {
                    Text("Score: \(score)/100")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.indigo)
                }
            }

            Spacer()
        }
        .padding(16)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.indigo.opacity(0.3), Color.purple.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var phaseEmoji: String {
        switch context.state.phase {
        case .preparing: return "🌙"
        case .sleeping:  return "😴"
        case .wakingUp:  return "☀️"
        case .resolved:  return "✅"
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}

// MARK: - Dynamic Island compact views

struct SleepIslandCompactLeading: View {
    let state: SleepActivityAttributes.SleepContentState
    var body: some View {
        Text(emoji(state.phase))
            .font(.caption)
    }
    private func emoji(_ phase: SleepActivityAttributes.SleepContentState.Phase) -> String {
        switch phase {
        case .preparing: return "🌙"
        case .sleeping:  return "😴"
        case .wakingUp:  return "☀️"
        case .resolved:  return "✅"
        }
    }
}

struct SleepIslandCompactTrailing: View {
    let state: SleepActivityAttributes.SleepContentState
    var body: some View {
        if let score = state.sleepScore {
            Text("\(score)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.indigo)
        } else if let dur = state.durationDisplay {
            Text(dur)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
