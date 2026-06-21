import CoreLocation
import SparkKit
import SparkUI
import SwiftUI

/// Renders a check_in Up to Speed item using the emoji-rating design pattern.
/// A completed period shows a summary; an incomplete period offers the rating form
/// with emoji ratings, notes, and location — matching CheckInModalView.
struct CheckInScreen: View {
    let item: UpToSpeedItem
    let viewModel: UpToSpeedViewModel

    @Environment(AppModel.self) private var appModel
    @State private var physical: Int? = nil
    @State private var mental: Int? = nil
    @State private var notes: String = ""
    @State private var locationState: LocationState = .idle
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var submitError: String?

    private var summary: UpToSpeedCheckInSummary? {
        if case .checkIn(let s) = item.payload { return s }
        return nil
    }

    var body: some View {
        StoryScreenScaffold(label: "Check-In") {
            if let summary {
                if summary.completed || submitted {
                    completedView(period: summary.period)
                } else {
                    formView(summary: summary)
                }
            }
        }
    }

    // MARK: - Completed state

    private func completedView(period: CheckInPeriod) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.lg) {
            Text("\(period.rawValue.capitalized) Check-In")
                .font(SparkTypography.heroSmall)
                .foregroundStyle(.primary)

            GlassCard {
                HStack(spacing: SparkSpacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.sparkSuccess)
                    VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                        Text("Check-in complete")
                            .font(SparkTypography.bodyStrong)
                            .foregroundStyle(.primary)
                        Text("Keep it up!")
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Form

    private func formView(summary: UpToSpeedCheckInSummary) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xl) {
            Text("\(summary.period.rawValue.capitalized) Check-In")
                .font(SparkTypography.heroSmall)
                .foregroundStyle(.primary)

            GlassCard {
                VStack(alignment: .leading, spacing: SparkSpacing.md) {
                    SectionLabel("HOW'S YOUR BODY?")
                    EmojiRatingRow(
                        selected: $physical,
                        emojis: CheckInPresentation.physicalEmojis,
                        labels: CheckInPresentation.physicalLabels
                    )
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: SparkSpacing.md) {
                    SectionLabel("HOW'S YOUR MIND?")
                    EmojiRatingRow(
                        selected: $mental,
                        emojis: CheckInPresentation.mentalEmojis,
                        labels: CheckInPresentation.mentalLabels
                    )
                }
            }

            notesSection

            locationSection

            if let err = submitError {
                Text(err)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(Color.sparkError)
            }

            logButton(summary: summary)
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            HStack {
                SectionLabel("NOTE")
                Spacer()
                Text("\(notes.count) / 1000")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.tertiary)
            }
            TextEditor(text: Binding(
                get: { notes },
                set: { notes = String($0.prefix(1000)) }
            ))
            .font(SparkTypography.body)
            .foregroundStyle(.primary)
            .frame(minHeight: 80, maxHeight: 160)
            .scrollContentBackground(.hidden)
            .padding(SparkSpacing.md)
            .sparkGlass(.roundedRect(SparkRadii.md))
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            SectionLabel("LOCATION")
            LocationChip(state: locationState) {
                Task { locationState = .fetching; locationState = await fetchLocationState(current: locationState) }
            } onClear: {
                locationState = .idle
            }
        }
    }

    // MARK: - Log button

    private func logButton(summary: UpToSpeedCheckInSummary) -> some View {
        Button {
            Task { await submit(summary: summary) }
        } label: {
            HStack(spacing: SparkSpacing.sm) {
                if isSubmitting {
                    ProgressView().scaleEffect(0.8).tint(.white)
                }
                Text(isSubmitting ? "Saving…" : "Log it")
                    .font(SparkTypography.body)
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SparkSpacing.md)
            .background(canSubmit ? Color.sparkAccent : Color.secondary.opacity(0.25))
            .foregroundStyle(canSubmit ? Color.white : Color.secondary)
            .clipShape(.rect(cornerRadius: SparkRadii.md))
        }
        .disabled(!canSubmit || isSubmitting)
        .animation(.easeInOut(duration: 0.15), value: canSubmit)
    }

    private var canSubmit: Bool { physical != nil && mental != nil }

    // MARK: - Submit

    private func submit(summary: UpToSpeedCheckInSummary) async {
        guard let phy = physical, let men = mental else { return }
        isSubmitting = true
        submitError = nil
        do {
            let (lat, lng, addr): (Double?, Double?, String?) = {
                if case let .resolved(address, lat, lng) = locationState {
                    return (lat, lng, address)
                }
                return (nil, nil, nil)
            }()
            let request = CheckInRequest(
                period: summary.period,
                physical: phy,
                mental: men,
                date: summary.date,
                latitude: lat,
                longitude: lng,
                address: addr,
                notes: notes.isEmpty ? nil : notes
            )
            _ = try await appModel.apiClient.request(CheckInsEndpoint.submit(request))
            submitted = true
        } catch {
            submitError = (error as? LocalizedError)?.errorDescription ?? "Failed to submit."
        }
        isSubmitting = false
    }
}
