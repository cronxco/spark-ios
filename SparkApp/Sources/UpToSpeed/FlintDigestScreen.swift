import SparkKit
import SparkUI
import SwiftUI

// MARK: - FlintHeaderPage

/// Title card for a flint digest. Also shows the first content section so
/// the title is never on its own empty-looking page.
struct FlintHeaderPage: View {
    let item: UpToSpeedItem
    let firstSection: String?

    private var summary: UpToSpeedFlintDigestSummary? {
        if case .flintDigest(let s) = item.payload { return s }
        return nil
    }

    var body: some View {
        StoryScreenScaffold(label: summary?.period.map { "\($0.displayName) Digest" }) {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                if let summary {
                    if let title = summary.title {
                        Text(title)
                            .font(SparkTypography.heroSmall)
                            .foregroundStyle(.primary)
                    }

                    HStack(spacing: SparkSpacing.sm) {
                        if summary.blockCount > 0 {
                            countPill("\(summary.blockCount) blocks", systemImage: "text.alignleft")
                        }
                        if summary.unansweredQuestionCount > 0 {
                            countPill("\(summary.unansweredQuestionCount) questions", systemImage: "questionmark.circle")
                        }
                    }
                }

                if let section = firstSection {
                    Divider().opacity(0.2)
                    SparkLongFormContentView(text: section, tint: .sparkAccent)
                }
            }
        }
    }

    private func countPill(_ label: String, systemImage: String) -> some View {
        Label(label, systemImage: systemImage)
            .font(SparkTypography.bodySmall)
            .foregroundStyle(.secondary)
            .padding(.horizontal, SparkSpacing.md)
            .padding(.vertical, SparkSpacing.xs)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
    }
}

// MARK: - FlintParagraphPage

/// One paragraph of a flint digest summary, rendered in the long-form serif style.
struct FlintParagraphPage: View {
    let item: UpToSpeedItem
    let text: String

    private var summary: UpToSpeedFlintDigestSummary? {
        if case .flintDigest(let s) = item.payload { return s }
        return nil
    }

    var body: some View {
        StoryScreenScaffold(label: summary?.period.map { "\($0.displayName) Digest" }) {
            SparkLongFormContentView(
                text: text,
                tint: .sparkAccent
            )
        }
    }
}

// MARK: - FlintInsightPage

/// One insight (non-question) block from a flint digest.
struct FlintInsightPage: View {
    let block: FlintDigestBlock

    var body: some View {
        StoryScreenScaffold(label: "Insight") {
            GlassCard(tint: Color.sparkAccent.opacity(0.1)) {
                VStack(alignment: .leading, spacing: SparkSpacing.md) {
                    Text(block.title)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.primary)

                    if let content = block.content, !content.isEmpty {
                        SparkRichContentText(
                            text: content,
                            font: SparkTypography.bodySmall,
                            foregroundStyle: .secondary,
                            lineSpacing: 5
                        )
                    }
                }
            }
        }
    }
}

// MARK: - FlintQuestionPage

/// One question block from a flint digest. Allows inline answering.
/// Calls `viewModel.onQuestionAnswered` on successful submission.
struct FlintQuestionPage: View {
    let item: UpToSpeedItem
    let block: FlintDigestBlock
    let viewModel: UpToSpeedViewModel

    @Environment(AppModel.self) private var appModel
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var submittedAnswer: String?
    @State private var submittedNote: String?

    var body: some View {
        StoryScreenScaffold(label: labelText) {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                Text(block.question ?? block.title)
                    .font(SparkTypography.heroSmall)
                    .foregroundStyle(.primary)

                if let submittedAnswer {
                    answeredView(answer: submittedAnswer, note: submittedNote)
                } else {
                    FlintAnswerFormView(
                        block: block,
                        isSubmitting: isSubmitting,
                        errorMessage: submitError,
                        onSubmit: { answer, note in await submitAnswer(answer, note: note) }
                    )
                }
            }
        }
    }

    private var labelText: String {
        if let priority = block.priority, priority == .high {
            return "Priority Question"
        }
        return "Question"
    }

    private func answeredView(answer: String, note: String?) -> some View {
        GlassCard(tint: Color.sparkSuccess.opacity(0.08)) {
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                Label(answer, systemImage: "checkmark.circle.fill")
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(Color.sparkSuccess)

                if let note, !note.isEmpty {
                    Text(note)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func submitAnswer(_ answer: String, note: String?) async {
        isSubmitting = true
        submitError = nil
        do {
            _ = try await appModel.apiClient.request(
                FlintEndpoint.answerQuestion(
                    blockID: block.id,
                    FlintQuestionAnswerRequest(answer: answer, answerNote: note)
                )
            )
            submittedAnswer = answer
            submittedNote = note
            viewModel.onQuestionAnswered(blockID: block.id, itemID: item.id)
        } catch {
            submitError = (error as? LocalizedError)?.errorDescription ?? "Failed to submit."
        }
        isSubmitting = false
    }
}
