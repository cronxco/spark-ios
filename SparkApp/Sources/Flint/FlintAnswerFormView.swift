import SparkKit
import SparkUI
import SwiftUI

/// Reusable answer form for Flint question blocks.
/// Handles both multiple-choice (sparkGlass capsule buttons) and free-text
/// (TextField) question types. Submission is delegated via closure so this
/// view can be used from FlintViewModel-backed screens (FlintView) and
/// from the Up to Speed stories flow (FlintDigestScreen).
struct FlintAnswerFormView: View {
    let block: FlintDigestBlock
    let isSubmitting: Bool
    let errorMessage: String?
    let onSubmit: (String, String?) async -> Void

    @State private var selectedAnswer: String = ""
    @State private var freeformAnswer: String = ""
    @State private var answerNote: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            if block.answered {
                answeredView
            } else {
                answerForm
            }

            if let error = errorMessage {
                Text(error)
                    .font(SparkTypography.caption)
                    .foregroundStyle(Color.sparkError)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            if block.answered, let existing = block.answer {
                selectedAnswer = existing
            }
        }
    }

    // MARK: - Answered state

    private var answeredView: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Label(block.answer ?? "Answered", systemImage: "checkmark.circle.fill")
                .font(SparkTypography.bodySmall)
                .foregroundStyle(Color.sparkSuccess)

            if let note = block.answerNote, !note.isEmpty {
                Text(note)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
            }

            if let answeredAt = block.answeredAt {
                Text("Answered \(answeredAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Answer form

    private var answerForm: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            if let options = block.answerOptions, !options.isEmpty {
                FlowLayout(spacing: SparkSpacing.sm) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            selectedAnswer = option
                        } label: {
                            Text(option)
                                .font(SparkTypography.captionStrong)
                                .foregroundStyle(selectedAnswer == option ? Color.white : Color.primary)
                                .padding(.horizontal, SparkSpacing.md)
                                .padding(.vertical, SparkSpacing.sm)
                                .sparkGlass(
                                    .capsule,
                                    tint: selectedAnswer == option ? Color.sparkAccent : Color.sparkAccent.opacity(0.1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                TextField("Answer", text: $freeformAnswer, axis: .vertical)
                    .font(SparkTypography.bodySmall)
                    .lineLimit(1...4)
                    .padding(SparkSpacing.md)
                    .textFieldInputBackground()
            }

            TextField("Add a note", text: $answerNote, axis: .vertical)
                .font(SparkTypography.bodySmall)
                .lineLimit(1...3)
                .padding(SparkSpacing.md)
                .textFieldInputBackground()

            Button {
                let answer = submittedAnswer
                let note = answerNote.isEmpty ? nil : answerNote
                Task { await onSubmit(answer, note) }
            } label: {
                HStack(spacing: SparkSpacing.sm) {
                    if isSubmitting {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text("Submit")
                        .font(SparkTypography.bodyStrong)
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.vertical, SparkSpacing.sm)
                .foregroundStyle(Color.white)
                .sparkGlass(.capsule, tint: Color.sparkAccent)
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting || submittedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var submittedAnswer: String {
        if let options = block.answerOptions, !options.isEmpty {
            return selectedAnswer
        }
        return freeformAnswer
    }
}
