import SparkUI
import SwiftUI

/// Today card surfacing the morning/afternoon check-in state. Tapping opens
/// the dedicated modal (placeholder until Day 15 wires in mood + tags +
/// note). When already logged for the current slot, the card flips to a
/// compact summary of the saved entry.
struct CheckInCard: View {
    let status: CheckInStatus
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GlassCard {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    GlassCardHeader(
                        icon: "heart.text.clipboard",
                        tint: .sparkAccent,
                        title: title,
                        trailing: trailing
                    )

                    Text(message)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the check-in modal")
    }

    private var title: String {
        switch status {
        case let .pending(slot):
            return "\(slot.rawValue.capitalized) check-in"
        case .logged:
            return "Today's check-in"
        }
    }

    private var trailing: String? {
        switch status {
        case .pending: return "tap to log"
        case .logged: return "logged"
        }
    }

    private var message: String {
        switch status {
        case .pending: return "How are you feeling? Mood, sleep quality, anything notable."
        case let .logged(mood, note):
            if let note, !note.isEmpty { return "\(mood.capitalized) — \(note)" }
            return mood.capitalized
        }
    }

    private var accessibilityLabel: String {
        switch status {
        case let .pending(slot): "\(slot.rawValue.capitalized) check-in pending"
        case let .logged(mood, _): "Check-in logged. Feeling \(mood)."
        }
    }
}
