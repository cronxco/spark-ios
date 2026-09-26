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

    private var isPaged: Bool { questions.count > 1 }

    var body: some View {
        if !questions.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("For you")

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
                                isPaged ? width - SparkSpacing.xxl : width
                            }
                            .id(question.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .scrollDisabled(!isPaged)

                if isPaged {
                    legend
                }
            }
        }
    }

    /// One mark per question, amber for the ones still wanting an answer and
    /// green for the ones already given. Deliberately not a position
    /// indicator: the peeking card says there is more to swipe to, and reading
    /// scroll position back needs API that is deprecated on this deployment
    /// target.
    private var legend: some View {
        HStack(spacing: 5) {
            ForEach(questions) { question in
                Capsule()
                    .fill(
                        question.status == .answered
                            ? Color.sparkSuccess.opacity(0.7)
                            : Color.sparkAccent
                    )
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(legendLabel)
    }

    private var legendLabel: String {
        let open = questions.filter { $0.status != .answered }.count
        let answered = questions.count - open
        var parts: [String] = []
        if open > 0 { parts.append("\(open) waiting on you") }
        if answered > 0 { parts.append("\(answered) answered") }
        return parts.joined(separator: ", ")
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
                    .font(SparkTypography.monoSmall)
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
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 38)
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
                    .frame(minHeight: 38)
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
