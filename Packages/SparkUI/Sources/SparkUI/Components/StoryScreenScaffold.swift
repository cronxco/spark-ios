import SwiftUI

/// Reusable scaffold for each screen inside the Up to Speed stories flow.
/// Provides a consistent transparent container that sits over the story background.
/// When `reserveTopSpace` is true (default), adds 152 pt top padding to clear
/// the progress-bar + controls overlay at the top of the story container.
///
/// Pass `flintByline` to render Flint's attribution (avatar + name + optional
/// time) above the content — used wherever Flint "speaks" on a screen.
///
/// Pass `onReachedBottom` to be notified once the reader has genuinely finished
/// the card. That means two things together: the scroll view is at the end of
/// its content, *and* the card is the page currently on screen, *and* both have
/// stayed true for `dwellDuration`. A card whose content fits without scrolling
/// is at the end from first layout, so it still has to be looked at for the
/// dwell before it counts.
///
/// `isActive` is what keeps a `TabView(.page)` from marking cards read before
/// they are seen: the pager builds the adjacent page ahead of the swipe, so an
/// off-screen card reaches end-of-content while the reader is still on the
/// previous one. Only the active page arms the dwell.
@MainActor
public struct StoryScreenScaffold<Content: View>: View {
    public struct Byline: Equatable {
        public let name: String
        public let meta: String?

        public init(_ name: String = "Flint", meta: String? = nil) {
            self.name = name
            self.meta = meta
        }
    }

    /// How long the reader must sit at the end before the card counts as read.
    private static var dwellDuration: Duration { .seconds(2) }

    public let label: String?
    public let flintByline: Byline?
    public let reserveTopSpace: Bool
    public let isActive: Bool
    public let onReachedBottom: (() -> Void)?
    public let supplement: AnyView?
    private let content: Content

    @State private var isAtEnd = false
    @State private var hasReachedBottom = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        label: String? = nil,
        flintByline: Byline? = nil,
        reserveTopSpace: Bool = true,
        isActive: Bool = true,
        onReachedBottom: (() -> Void)? = nil,
        supplement: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.flintByline = flintByline
        self.reserveTopSpace = reserveTopSpace
        self.isActive = isActive
        self.onReachedBottom = onReachedBottom
        self.supplement = supplement
        self.content = content()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                if let label {
                    Text(label)
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if let flintByline {
                    FlintByline(flintByline.name, meta: flintByline.meta)
                }

                content

                if let supplement {
                    supplement
                }

                if onReachedBottom != nil && showsReadIndicator {
                    readIndicator
                        .padding(.top, SparkSpacing.sm)
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, reserveTopSpace ? headerClearance + 8 : SparkSpacing.lg)
            .padding(.bottom, SparkSpacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .ignoresSafeArea(.container)
        .onScrollGeometryChange(for: StoryScrollEndMetrics.self) { geometry in
            StoryScrollEndMetrics(
                offsetY: geometry.contentOffset.y,
                containerHeight: geometry.containerSize.height,
                contentHeight: geometry.contentSize.height
            )
        } action: { _, metrics in
            isAtEnd = metrics.isAtEnd()
        }
        .task(id: dwellKey) {
            guard onReachedBottom != nil, dwellKey.shouldArm else { return }
            try? await Task.sleep(for: Self.dwellDuration)
            guard !Task.isCancelled else { return }
            hasReachedBottom = true
            onReachedBottom?()
        }
    }

    // MARK: - End-of-content detection

    private var dwellKey: StoryDwellKey {
        StoryDwellKey(isActive: isActive, isAtEnd: isAtEnd, alreadyRead: hasReachedBottom)
    }

    // MARK: - Read indicator

    private var readIndicator: some View {
        HStack(spacing: SparkSpacing.xs) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
            Text("Read")
                .font(SparkTypography.caption)
        }
        .foregroundStyle(Color.sparkSuccess)
        .padding(.horizontal, SparkSpacing.md)
        .padding(.vertical, SparkSpacing.xs)
        .background(Capsule().fill(Color.sparkSuccess.opacity(0.15)))
        .opacity(hasReachedBottom ? 1 : 0)
        .scaleEffect(reduceMotion ? 1 : (hasReachedBottom ? 1 : 0.8), anchor: .leading)
        .animation(
            reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.7),
            value: hasReachedBottom
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(!hasReachedBottom)
        .accessibilityLabel("Read")
        .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    ZStack {
        Color.sparkSurface.ignoresSafeArea()
        StoryScreenScaffold(label: "Morning Digest", flintByline: .init(meta: "07:27")) {
            Text("Content goes here")
                .foregroundStyle(.primary)
        }
    }
}
