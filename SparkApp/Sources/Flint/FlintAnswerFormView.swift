import SparkKit
import SparkUI
import SwiftUI

/// Reusable answer form for Flint question blocks.
/// Handles both multiple-choice and free-text question types. Submission is delegated via closure so this
/// view can be used from FlintViewModel-backed screens (FlintView) and
/// from the Up to Speed stories flow (FlintDigestScreen).
struct FlintAnswerFormView: View {
    let block: FlintDigestBlock
    let isSubmitting: Bool
    let errorMessage: String?
    let onSubmit: (String, String?) async -> Void
    var onNotRelevant: (() async -> Void)? = nil

    @State private var selectedAnswer: String = ""
    @State private var freeformAnswer: String = ""
    @State private var answerNote: String = ""
    @State private var showsContext = false
    @FocusState private var answerFieldFocused: Bool

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
                                .foregroundStyle(selectedAnswer == option ? Color.black : Color.primary)
                                .padding(.horizontal, SparkSpacing.md)
                                .padding(.vertical, SparkSpacing.sm)
                                .background(
                                    selectedAnswer == option ? Color.sparkAccent : Color.sparkElevated,
                                    in: Capsule()
                                )
                                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: 44)
                        .accessibilityAddTraits(selectedAnswer == option ? .isSelected : [])
                    }
                }
            } else {
                Text("Your answer")
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(.secondary)

                TextField("Type your answer", text: $freeformAnswer, axis: .vertical)
                    .font(SparkTypography.bodySmall)
                    .lineLimit(1...4)
                    .padding(SparkSpacing.md)
                    .textFieldInputBackground()
                    .focused($answerFieldFocused)
                    .submitLabel(.send)
                    .onSubmit(submit)
            }

            if showsContext {
                TextField("Add context (optional)", text: $answerNote, axis: .vertical)
                    .font(SparkTypography.bodySmall)
                    .lineLimit(1...3)
                    .padding(SparkSpacing.md)
                    .textFieldInputBackground()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Button("Add context (optional)", systemImage: "plus") {
                    withAnimation { showsContext = true }
                }
                .font(SparkTypography.captionStrong)
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }

            ViewThatFits(in: .horizontal) {
                HStack {
                    if let onNotRelevant {
                        notRelevantButton(action: onNotRelevant)
                    }
                    Spacer(minLength: SparkSpacing.sm)
                    answerButton
                }

                VStack(alignment: .leading) {
                    answerButton
                        .frame(maxWidth: .infinity)
                    if let onNotRelevant {
                        notRelevantButton(action: onNotRelevant)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var answerButton: some View {
        Button(action: submit) {
            HStack {
                if isSubmitting {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text("Answer")
                    .font(SparkTypography.bodyStrong)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.glassProminent)
        .tint(.sparkAccent)
        .disabled(isSubmitting || submittedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func notRelevantButton(action: @escaping () async -> Void) -> some View {
        Button("Not relevant") { Task { await action() } }
            .buttonStyle(.glass)
            .frame(minHeight: 44)
            .disabled(isSubmitting)
    }

    private func submit() {
        let answer = submittedAnswer
        guard !isSubmitting, !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let note = answerNote.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { await onSubmit(answer, note.isEmpty ? nil : note) }
    }

    private var submittedAnswer: String {
        if let options = block.answerOptions, !options.isEmpty {
            return selectedAnswer
        }
        return freeformAnswer
    }
}
