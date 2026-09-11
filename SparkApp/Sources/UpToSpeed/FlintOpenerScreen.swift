import SparkKit
import SparkUI
import SwiftUI

/// First screen of the Up to Speed flow — Flint's greeting, a short spoken
/// intro, and a tap-through list of the chapters ahead.
struct FlintOpenerScreen: View {
    let viewModel: UpToSpeedViewModel

    var body: some View {
        StoryScreenScaffold(flintByline: .init(meta: openerTime)) {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                Text(viewModel.openerGreeting)
                    .font(SparkTypography.heroXL)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(viewModel.openerParagraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(SparkTypography.longFormBody)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
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
