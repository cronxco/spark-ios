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
                // Glass shadows and the next-card peek should not end at the
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
            // The short label the question carries as a digest block, so the
            // card can be recognised before its full text is read.
            if let title = question.title, !title.isEmpty, title != question.question {
                Text(title)
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            if let asked = question.askedAt {
                Text(Self.relative.localizedString(for: asked, relativeTo: .now))
                    .font(SparkTypography.caption)
                    .foregroundStyle(.tertiary)
            }

            Text(question.question)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isAnswered, let answer = question.effectiveAnswer?.answer {
                answered(answer)
            } else {
                options
            }
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The amber tint is what says Flint is asking; it replaces the glyph
        // and the "needs you" badge this card used to carry.
        .sparkGlass(.roundedRect(SparkRadii.lg), tint: Color.sparkAccent.opacity(0.09))
        .overlay {
            RoundedRectangle(cornerRadius: SparkRadii.lg)
                .stroke(Color.sparkAccent.opacity(0.30), lineWidth: 1)
        }
    }

    private func answered(_ answer: String) -> some View {
        HStack(alignment: .top, spacing: SparkSpacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.sparkSuccess)
            Text(answer)
                .font(SparkTypography.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, SparkSpacing.md)
        .padding(.vertical, SparkSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sparkSuccess.opacity(0.14), in: .rect(cornerRadius: SparkRadii.sm))
        .overlay {
            RoundedRectangle(cornerRadius: SparkRadii.sm)
                .stroke(Color.sparkSuccess.opacity(0.32), lineWidth: 1)
        }
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
                            .background(Color.sparkElevated.opacity(0.88), in: .capsule)
                            .overlay {
                                Capsule().stroke(Color.primary.opacity(0.14), lineWidth: 1)
                            }
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
                    .background(Color.sparkElevated.opacity(0.88), in: .capsule)
                    .overlay {
                        Capsule().stroke(Color.primary.opacity(0.14), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
}
