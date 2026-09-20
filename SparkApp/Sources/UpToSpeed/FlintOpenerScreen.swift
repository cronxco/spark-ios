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
    var onShowRecap: (() -> Void)?

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
                if let onShowRecap, !viewModel.recapItems.isEmpty {
                    Button(action: onShowRecap) {
                        Label("Recap", systemImage: "clock.arrow.circlepath")
                            .font(SparkTypography.bodySmall)
                    }
                    .buttonStyle(.plain)
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
