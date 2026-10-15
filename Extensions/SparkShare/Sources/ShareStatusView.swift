import Observation
import SparkUI
import SwiftUI

/// What the share sheet is doing right now.
enum SharePhase: Equatable, Sendable {
    case working(String)
    case succeeded(String)
    case failed(String)
}

/// Drives `ShareStatusView`. The controller moves it through the phases; the
/// view only renders the current one and reports the user's taps.
@MainActor
@Observable
final class ShareStatusModel {
    var phase: SharePhase = .working("Preparing…")

    @ObservationIgnored var onCancel: () -> Void = {}
    @ObservationIgnored var onDone: () -> Void = {}
}

/// The share sheet's only screen: a spinner while the item is being sent,
/// then a tick or a cross with the outcome.
///
/// Before this existed the controller drew nothing but its background while
/// it worked, and its result toast was added in the same run-loop turn the
/// sheet was dismissed, so the user saw a blank sheet that vanished.
struct ShareStatusView: View {
    @Bindable var model: ShareStatusModel

    var body: some View {
        VStack(spacing: SparkSpacing.lg) {
            Spacer()

            icon
                .frame(width: 64, height: 64)

            Text(message)
                .font(SparkTypography.bodyStrong)
                .foregroundStyle(Color.sparkTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SparkSpacing.xl)

            Spacer()

            footerButton
                .padding(.horizontal, SparkSpacing.xl)
                .padding(.bottom, SparkSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sparkSurface.ignoresSafeArea())
        .animation(.snappy, value: model.phase)
        .sensoryFeedback(trigger: model.phase) { _, newPhase in
            switch newPhase {
            case .working: return nil
            case .succeeded: return .success
            case .failed: return .error
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch model.phase {
        case .working:
            ProgressView()
                .controlSize(.large)
                .tint(Color.sparkAccent)
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.sparkSuccess)
                .transition(.scale.combined(with: .opacity))
                .accessibilityHidden(true)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.sparkError)
                .transition(.scale.combined(with: .opacity))
                .accessibilityHidden(true)
        }
    }

    private var message: String {
        switch model.phase {
        case .working(let message), .succeeded(let message), .failed(let message):
            message
        }
    }

    @ViewBuilder
    private var footerButton: some View {
        switch model.phase {
        case .working:
            Button("Cancel", role: .cancel) { model.onCancel() }
                .buttonStyle(.glass)
                .controlSize(.large)
        case .succeeded:
            // Dismisses itself; keep the layout steady so the icon doesn't jump.
            Button("Done") { model.onDone() }
                .buttonStyle(.glass)
                .controlSize(.large)
                .hidden()
        case .failed:
            Button("Done") { model.onDone() }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        }
    }
}
