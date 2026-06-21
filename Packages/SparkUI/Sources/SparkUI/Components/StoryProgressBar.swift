import SwiftUI

/// Segmented top progress bar for the Up to Speed stories flow.
/// One segment per screen in the queue; the current segment fills as the user reads.
public struct StoryProgressBar: View {
    public let total: Int
    public let currentIndex: Int
    public let segmentProgress: Double

    public init(total: Int, currentIndex: Int, segmentProgress: Double = 1) {
        self.total = total
        self.currentIndex = currentIndex
        self.segmentProgress = segmentProgress
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                segment(for: index)
            }
        }
        .frame(height: 3)
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
        ZStack {
            Color.black.ignoresSafeArea()
            StoryProgressBar(total: 5, currentIndex: 2, segmentProgress: 0.4)
                .padding(.horizontal, 16)
        }
        .frame(height: 40)
        ZStack {
            Color.white.ignoresSafeArea()
            StoryProgressBar(total: 5, currentIndex: 2, segmentProgress: 0.4)
                .padding(.horizontal, 16)
        }
        .frame(height: 40)
    }
}
