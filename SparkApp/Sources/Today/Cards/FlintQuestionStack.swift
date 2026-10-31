import SparkKit
import SparkUI
import SwiftUI

/// The last 48 hours of Flint's questions, open ones first.
///
/// Answered ones stay in the stack behind them so you can see what you already
/// told it — the assistant's memory of you is worth showing, and it is the
/// only place the app does.
///
/// A single question fills the width; more than one becomes a pager whose next
/// card peeks, which is the whole swipe affordance.
struct FlintQuestionStack: View {
    let questions: [FlintQuestion]
    let onAnswer: (FlintQuestion, String) -> Void
    let onOpen: () -> Void
    @State private var visibleQuestionID: String?

    private var isPaged: Bool { questions.count > 1 }
    private var visibleIndex: Int {
        questions.firstIndex { $0.id == visibleQuestionID } ?? 0
    }

    var body: some View {
        if !questions.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("For you", style: .dayHeading)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: SparkSpacing.md) {
                        ForEach(questions) { question in
                            FlintQuestionCard(
                                question: question,
                                onAnswer: { onAnswer(question, $0) },
                                onOpen: onOpen
                            )
                            .containerRelativeFrame(.horizontal) { width, _ in
                                // The next card peeks when there is one to
                                // peek, which is the whole swipe affordance.
                                isPaged ? width - SparkSpacing.xl : width
                            }
                            .id(question.id)
                        }
                    }
                    .padding(.vertical, SparkSpacing.sm)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $visibleQuestionID)
                .scrollIndicators(.hidden)
                // The next-card peek should not end at the
                // scroll view's rectangular content bounds.
                .scrollClipDisabled()
                .scrollDisabled(!isPaged)

                if isPaged {
                    pageIndicator
                }
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 5) {
            ForEach(Array(questions.enumerated()), id: \.element.id) { index, _ in
                Capsule()
                    .fill(index == visibleIndex ? Color.sparkAccent : Color.primary.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Question \(visibleIndex + 1) of \(questions.count)")
    }
}

private struct FlintQuestionCard: View {
    let question: FlintQuestion
    let onAnswer: (String) -> Void
    let onOpen: () -> Void

    private var isAnswered: Bool { question.status == .answered }

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(spacing: SparkSpacing.xs) {
                SparkGlyph(.flint, size: 13, relativeTo: .caption)
                Text("Flint asks")
                    .font(SparkTypography.captionStrong)
                Spacer(minLength: SparkSpacing.sm)
                if let asked = question.askedAt {
                    SparkTimeText(asked)
                }
            }
            .foregroundStyle(.secondary)

            // The short label the question carries as a digest block, so the
            // card can be recognised before its full text is read.
            if let title = question.title, !title.isEmpty, title != question.question {
                Text(title)
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Text(question.question)
                .font(SparkTypography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isAnswered, let answer = question.effectiveAnswer?.answer {
                answered(answer)
            } else {
                options
            }
        }
        .padding(SparkSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Flint's own words sit on the generated surface (section 3.5); the
        // surface is what says Flint is asking.
        .sparkGeneratedSurface(radius: SparkRadii.lg)
    }

    private func answered(_ answer: String) -> some View {
        HStack(spacing: SparkSpacing.sm) {
            SparkGlyph(.success, size: 13)
                .foregroundStyle(Color.sparkSuccess)
            Text("You said \u{201C}\(answer)\u{201D}")
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, SparkSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(Color.sparkSurface, in: .rect(cornerRadius: SparkRadii.md))
    }

    @ViewBuilder
    private var options: some View {
        if let options = question.answerOptions, !options.isEmpty {
            // A wrapping row would need a custom layout; a flexible grid gets
            // the same result and keeps every chip at a 44pt target.
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: SparkSpacing.sm)],
                alignment: .leading,
                spacing: SparkSpacing.sm
            ) {
                ForEach(options, id: \.self) { option in
                    Button { onAnswer(option) } label: {
                        Text(option)
                            .font(SparkTypography.captionStrong)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.horizontal, SparkSpacing.md)
                            .background(Color.sparkSurface, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            // A free-text question cannot be answered from a chip, so the card
            // hands off to the place that has the full form.
            Button(action: onOpen) {
                Text("Answer")
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(.primary)
                    .frame(minHeight: 44)
                    .padding(.horizontal, SparkSpacing.lg)
                    .background(Color.sparkSurface, in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }
}
