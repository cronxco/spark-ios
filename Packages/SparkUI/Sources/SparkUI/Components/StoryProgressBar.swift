import SwiftUI

/// Segmented top progress bar for the Up to Speed stories flow.
///
/// Two shapes:
/// - **Flat** — one segment per screen (`init(total:currentIndex:)`).
/// - **Chaptered** — segments grouped into named chapters with a wider gap
///   between groups (`init(chapters:currentIndex:)`). `currentIndex` is the
///   global 0-based screen index across every chapter.
public struct StoryProgressBar: View {
    /// One chapter's worth of segments in the chaptered bar.
    public struct ChapterSpec: Equatable {
        public let label: String
        public let segments: Int

        public init(label: String, segments: Int) {
            self.label = label
            self.segments = segments
        }
    }

    private let chapters: [ChapterSpec]
    private let currentIndex: Int
    private let segmentProgress: Double

    /// Flat bar — `total` evenly-weighted segments.
    public init(total: Int, currentIndex: Int, segmentProgress: Double = 1) {
        self.chapters = [ChapterSpec(label: "", segments: max(total, 0))]
        self.currentIndex = currentIndex
        self.segmentProgress = segmentProgress
    }

    /// Chaptered bar — segments grouped by chapter.
    public init(chapters: [ChapterSpec], currentIndex: Int, segmentProgress: Double = 1) {
        self.chapters = chapters
        self.currentIndex = currentIndex
        self.segmentProgress = segmentProgress
    }

    public var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(chapters.enumerated()), id: \.offset) { chapterIndex, chapter in
                HStack(spacing: 4) {
                    ForEach(0..<chapter.segments, id: \.self) { segmentInChapter in
                        segment(for: globalIndex(chapterIndex: chapterIndex, segmentInChapter: segmentInChapter))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(chapter.label)
            }
        }
        .frame(height: 3)
    }

    private func globalIndex(chapterIndex: Int, segmentInChapter: Int) -> Int {
        let preceding = chapters.prefix(chapterIndex).reduce(0) { $0 + $1.segments }
        return preceding + segmentInChapter
    }

    @ViewBuilder
    private func segment(for index: Int) -> some View {
        GeometryReader { geo in
            Capsule()
                .fill(Color.primary.opacity(0.15))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(index < currentIndex ? Color.primary.opacity(0.5) : Color.sparkAccent)
                        .frame(width: geo.size.width * fillFraction(for: index))
                }
        }
        .frame(height: 3)
    }

    private func fillFraction(for index: Int) -> Double {
        if index < currentIndex { return 1 }
        if index == currentIndex { return segmentProgress.clamped(to: 0...1) }
        return 0
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    VStack(spacing: 24) {
        StoryProgressBar(total: 5, currentIndex: 2, segmentProgress: 0.4)
            .padding(.horizontal, 16)
        StoryProgressBar(
            chapters: [
                .init(label: "You", segments: 1),
                .init(label: "Ask", segments: 1),
                .init(label: "Day", segments: 1),
                .init(label: "News", segments: 3),
                .init(label: "Wrap", segments: 2)
            ],
            currentIndex: 4
        )
        .padding(.horizontal, 16)
    }
    .frame(height: 120)
    .background(Color.sparkSurface)
}
