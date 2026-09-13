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
                    .font(SparkTypography.heroXL)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let dayContext = viewModel.openerDayContext, hasDayContent(dayContext) {
                    DayContextSection(
                        dayContext: dayContext,
                        yesterday: viewModel.openerYesterday
                    )
                }

                if !chapterRows.isEmpty {
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
            }
        }
    }

    /// A day context block can arrive with everything empty — a quiet day with
    /// no calendar, no birthdays and no weather. Rendering its heading anyway
    /// would put an empty "Today" on the card.
    private func hasDayContent(_ context: FlintDayContext) -> Bool {
        !context.calendar.isEmpty
            || !context.birthdays.isEmpty
            || context.weather != nil
            || viewModel.openerYesterday != nil
    }

    private var chapterRows: [UpToSpeedChapter] {
        viewModel.chapters.filter { $0.kind != .intro }
    }

    private func chapterRow(_ chapter: UpToSpeedChapter) -> some View {
        HStack(spacing: SparkSpacing.md) {
            Circle()
                .fill(chapter.accent)
                .frame(width: 7, height: 7)
            Text(chapter.title)
                .font(SparkTypography.body)
                .foregroundStyle(.primary)
            Spacer(minLength: SparkSpacing.sm)
            Text(chapter.cardCount == 1 ? "1 card" : "\(chapter.cardCount) cards")
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.vertical, SparkSpacing.md)
        .contentShape(Rectangle())
    }

    private var openerTime: String {
        Date.now.formatted(.dateTime.hour().minute())
    }
}
