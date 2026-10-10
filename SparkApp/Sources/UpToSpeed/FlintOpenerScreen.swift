import SparkKit
import SparkUI
import SwiftUI

/// First screen of the Up to Speed flow — Flint's greeting, the day itself, and
/// a tap-through list of the chapters ahead.
///
/// The day used to be a chapter several swipes in while this card led with two
/// paragraphs lifted off the digest. That was wrong twice over: it buried the
/// thing most worth seeing first, and it stripped the briefing chapter of the
/// prose that was its only content.
struct FlintOpenerScreen: View {
    let viewModel: UpToSpeedViewModel

    var body: some View {
        StoryScreenScaffold(flintByline: .init(meta: openerTime)) {
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                Text(viewModel.openerGreeting)
                    .font(SparkTypography.heroSmall)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let dayContext = viewModel.openerDayContext, hasDayContent(dayContext) {
                    DayContextSection(
                        dayContext: dayContext,
                        yesterday: viewModel.openerYesterday
                    )
                }

                if !chapterRows.isEmpty {
                    Text("Up ahead").font(SparkTypography.bodyStrong)
                    GlassCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(chapterRows.enumerated()), id: \.element.id) { index, chapter in
                                Button {
                                    viewModel.jump(to: chapter.range.lowerBound)
                                } label: {
                                    chapterRow(chapter)
                                }
                                .buttonStyle(.plain)

                                if index < chapterRows.count - 1 {
                                    Divider().opacity(0.15)
                                }
                            }
                        }
                    }
                }
                if viewModel.digestsFailedToLoad > 0 {
                    Button("Some of your briefing couldn’t load. Try again") {
                        Task { await viewModel.reloadQueue() }
                    }
                    .font(SparkTypography.bodySmall)
                }
            }
        }
    }

    /// A day context block can arrive with everything empty — a quiet day with
    /// no calendar, no birthdays and no weather. Rendering its heading anyway
    /// would put an empty "Today" on the card.
    ///
    /// Weather is judged by `hasContent` rather than by nil-ness, and
    /// `DayContextSection` uses the same test: `"weather": {}` decodes to a
    /// non-nil value holding nothing, which would otherwise count as a reason
    /// to render the section.
    private func hasDayContent(_ context: FlintDayContext) -> Bool {
        !context.calendar.isEmpty
            || !context.birthdays.isEmpty
            || context.weather?.hasContent == true
            || viewModel.openerYesterday != nil
    }

    /// The Wrap is always there, so it earns a row only when a check-in is
    /// waiting in it.
    private var chapterRows: [UpToSpeedChapter] {
        viewModel.chapters.filter { chapter in
            switch chapter.kind {
            case .intro: false
            case .wrap: checkInCount(in: chapter) > 0
            default: true
            }
        }
    }

    private func chapterRow(_ chapter: UpToSpeedChapter) -> some View {
        HStack(spacing: SparkSpacing.md) {
            Circle()
                .fill(chapter.accent)
                .frame(width: 7, height: 7)
            Text(chapter.kind == .wrap ? "Check-in" : chapter.title)
                .font(SparkTypography.body)
                .foregroundStyle(.primary)
            Spacer(minLength: SparkSpacing.sm)
            let label = countLabel(chapter)
            if !label.isEmpty {
                Text(label)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.vertical, SparkSpacing.md)
        .contentShape(Rectangle())
    }

    /// Counts what the chapter actually holds rather than its cards: an
    /// anomaly is an observation, a roundup section a story. Headlines opens
    /// on a contents page, which isn't an article.
    private func countLabel(_ chapter: UpToSpeedChapter) -> String {
        switch chapter.kind {
        case .anomaly: return Self.count(chapter.cardCount, "observation")
        case .news: return Self.count(chapter.cardCount, "story", plural: "stories")
        case .headlines: return Self.count(max(chapter.cardCount - 1, 0), "article")
        case .wrap: return ""
        case .digest:
            let questions = screens(in: chapter).filter {
                if case .flintQuestion = $0 { return true }
                return false
            }.count
            let sections = Self.count(chapter.cardCount - questions, "section")
            return questions == 0 ? sections : "\(sections) · \(Self.count(questions, "question"))"
        case .intro, .recap: return Self.count(chapter.cardCount, "card")
        }
    }

    private func screens(in chapter: UpToSpeedChapter) -> ArraySlice<UpToSpeedScreen> {
        let range = chapter.range.clamped(to: viewModel.screens.indices)
        return viewModel.screens[range]
    }

    private func checkInCount(in chapter: UpToSpeedChapter) -> Int {
        screens(in: chapter).filter {
            if case .checkIn = $0 { return true }
            return false
        }.count
    }

    private static func count(_ n: Int, _ singular: String, plural: String? = nil) -> String {
        n == 1 ? "1 \(singular)" : "\(n) \(plural ?? singular + "s")"
    }

    private var openerTime: String {
        Date.now.formatted(.dateTime.hour().minute())
    }
}
