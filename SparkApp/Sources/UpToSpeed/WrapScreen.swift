import SparkKit
import SparkUI
import SwiftUI

/// Closing screen of the Up to Speed flow — a saved-to-read piece, any Flint
/// questions still open, and a way out.
struct WrapScreen: View {
    let viewModel: UpToSpeedViewModel
    let onDone: () -> Void
    var isActive: Bool = true
    var onShowRecap: (() -> Void)?

    @Environment(\.openURL) private var openURL

    var body: some View {
        StoryScreenScaffold(
            isActive: isActive,
            onReachedBottom: { viewModel.markReachedWrap() }
        ) {
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                Text(headline)
                    .font(SparkTypography.hero)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let reading = viewModel.readingItem {
                    readingCard(reading)
                }

                if !viewModel.openQuestions.isEmpty {
                    looseEnds
                }

                PillButton("Done for now") { onDone() }
                    .frame(maxWidth: .infinity)

                if let onShowRecap, !viewModel.recapItems.isEmpty {
                    recapLink(count: viewModel.recapItems.count, action: onShowRecap)
                }
            }
        }
    }

    /// A quiet way back to anything already dealt with today. Deliberately
    /// secondary to "Done for now" — the recap is a safety net, not a
    /// destination.
    private func recapLink(count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SparkSpacing.xs) {
                Text(count == 1 ? "Earlier today · 1 item" : "Earlier today · \(count) items")
                    .font(SparkTypography.bodySmall)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Review and restore anything you have already seen today")
    }

    private var headline: String {
        if let name = firstName {
            return "That's everything, \(name)."
        }
        return "That's everything."
    }

    private var firstName: String? {
        let parts = viewModel.openerGreeting.split(separator: ",")
        guard parts.count > 1, let last = parts.last else { return nil }
        let name = last.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        return name.isEmpty ? nil : name
    }

    private func readingCard(_ reading: UpToSpeedParsing.ReadingItem) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                Text(readingLabel(reading))
                    .font(SparkTypography.captionStrong)
                    .tracking(1)
                    .foregroundStyle(.secondary)

                Text(reading.title)
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let blurb = reading.blurb {
                    Text(blurb)
                        .font(SparkTypography.longFormBodySmall)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let urlString = reading.url, let url = URL(string: urlString) {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Read now", systemImage: "book")
                            .font(SparkTypography.bodySmall)
                            .padding(.horizontal, SparkSpacing.md)
                            .padding(.vertical, SparkSpacing.xs)
                            .sparkGlass(.capsule, tint: Color.sparkAccent.opacity(0.18))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, SparkSpacing.xs)
                }
            }
        }
    }

    private func readingLabel(_ reading: UpToSpeedParsing.ReadingItem) -> String {
        if let time = reading.readingTime {
            return "Saved to read · \(time)"
        }
        return "Saved to read"
    }

    private var looseEnds: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Text(viewModel.openQuestions.count == 1 ? "One loose end" : "Loose ends")
                .font(SparkTypography.captionStrong)
                .tracking(1)
                .foregroundStyle(.secondary)

            ForEach(viewModel.openQuestions) { question in
                Button {
                    jump(to: question)
                } label: {
                    HStack(spacing: SparkSpacing.md) {
                        Text(question.block.question ?? question.block.title)
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: SparkSpacing.sm)
                        Text("Answer")
                            .font(SparkTypography.captionStrong)
                            .foregroundStyle(Color.spark700)
                    }
                    .padding(SparkSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sparkGlass(.roundedRect(SparkRadii.md))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func jump(to question: UpToSpeedViewModel.OpenQuestion) {
        guard let index = viewModel.screens.firstIndex(where: { screen in
            if case .flintQuestion(_, let block) = screen { return block.id == question.block.id }
            return false
        }) else { return }
        viewModel.jump(to: index)
    }
}
