import SparkKit
import SwiftUI

/// How the app background picks its slot. `auto` follows the clock; every
/// other case pins one slot.
///
/// The raw values are persisted in the App Group under
/// `spark.background.mode`, so they are storage format as well as API.
public enum SparkAppBackgroundMode: String, CaseIterable, Identifiable, Sendable {
    case auto
    case morning
    case day
    case evening
    case night

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .auto: "Auto"
        case .morning: "Morning"
        case .day: "Day"
        case .evening: "Evening"
        case .night: "Night"
        }
    }

    /// The slot this mode pins, or `nil` when it follows the clock.
    public var slot: SparkTimeOfDay? {
        switch self {
        case .auto: nil
        case .morning: .morning
        case .day: .day
        case .evening: .evening
        case .night: .night
        }
    }

    /// The slot to draw: the pinned one, else whichever the clock is in.
    public func resolvedSlot(
        date: Date = .now,
        calendar: Calendar = .current
    ) -> SparkTimeOfDay {
        slot ?? SparkTimeOfDay.from(date: date, calendar: calendar)
    }
}

/// One of the two radial glows that give the dark washes their depth.
public struct SparkBackgroundGlow {
    public let colour: Color
    public let opacity: Double
    public let anchor: UnitPoint
    /// Fraction of the larger edge; the end radius is this times 1.3.
    public let span: CGFloat

    public init(_ colour: Color, _ opacity: Double, _ anchor: UnitPoint, _ span: CGFloat) {
        self.colour = colour
        self.opacity = opacity
        self.anchor = anchor
        self.span = span
    }
}

/// The app-wide background: one wash per time-of-day slot, composed
/// differently in each colour scheme.
///
/// Light draws a single diagonal linear gradient. It cannot use the glows the
/// dark washes do: the light ground is `ash1` at `#FCFCFC`, and `plusLighter`
/// adds light, so a glow over it has no headroom and clips to white.
///
/// Dark draws a vertical base under two `plusLighter` radial glows — one
/// top-trailing, one bottom-leading — which the near-black ground has all the
/// room in the world for.
///
/// Every stop is a step of the eight families; `SparkUITests` pins that.
public struct SparkAppBackground: View {
    public let slot: SparkTimeOfDay
    public let scheme: ColorScheme

    public init(slot: SparkTimeOfDay, scheme: ColorScheme) {
        self.slot = slot
        self.scheme = scheme
    }

    public var body: some View {
        ZStack {
            Color.sparkSurface

            if scheme == .dark {
                darkWash
            } else {
                LinearGradient(
                    colors: Self.lightStops(for: slot),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    /// The glows blend against the base and each other, never against
    /// whatever the background is placed behind, so the stack is its own
    /// compositing group.
    private var darkWash: some View {
        let glows = Self.darkGlows(for: slot)

        return ZStack {
            LinearGradient(
                colors: Self.darkBase(for: slot),
                startPoint: .top,
                endPoint: .bottom
            )
            Self.radial(glows.top)
            Self.radial(glows.bottom)
        }
        .compositingGroup()
    }

    private static func radial(_ glow: SparkBackgroundGlow) -> some View {
        GeometryReader { proxy in
            let size = max(proxy.size.width, proxy.size.height) * (glow.span * 1.3)
            RadialGradient(
                colors: [glow.colour.opacity(glow.opacity), .clear],
                center: glow.anchor,
                startRadius: 0,
                endRadius: size
            )
            .blendMode(.plusLighter)
        }
    }
}

// MARK: - The washes

public extension SparkAppBackground {
    /// Light mode: stops for the diagonal, top-leading to bottom-trailing.
    static func lightStops(for slot: SparkTimeOfDay) -> [Color] {
        switch slot {
        case .morning:
            [Color.sky3.opacity(0.24), Color.spark2.opacity(0.18), .clear]
        case .day:
            [Color.spark5.opacity(0.16), Color.spark2.opacity(0.16), .clear]
        case .evening:
            [
                Color.flame2.opacity(0.22),
                Color.ember3.opacity(0.18),
                Color.spark3.opacity(0.12),
                .clear,
            ]
        case .night:
            [Color.sky2.opacity(0.20), Color.flint3.opacity(0.12), .clear]
        }
    }

    /// Dark mode: the vertical base the glows sit on, top to bottom.
    static func darkBase(for slot: SparkTimeOfDay) -> [Color] {
        switch slot {
        case .morning: [.flint5, .slate5]
        case .day: [.flint4, .slate6]
        case .evening: [.flint3, .slate7]
        case .night: [.flint7, .slate9]
        }
    }

    /// Dark mode: the two glows, top-trailing first.
    static func darkGlows(
        for slot: SparkTimeOfDay
    ) -> (top: SparkBackgroundGlow, bottom: SparkBackgroundGlow) {
        switch slot {
        case .morning:
            (
                SparkBackgroundGlow(.sky7, 0.55, .topTrailing, 0.55),
                SparkBackgroundGlow(.flint3, 0.60, .bottomLeading, 0.65)
            )
        case .day:
            (
                SparkBackgroundGlow(.spark7, 0.40, .topTrailing, 0.50),
                SparkBackgroundGlow(.flint3, 0.55, .bottomLeading, 0.65)
            )
        case .evening:
            (
                SparkBackgroundGlow(.spark6, 0.45, .topTrailing, 0.50),
                SparkBackgroundGlow(.flame7, 0.25, .bottomLeading, 0.60)
            )
        case .night:
            (
                SparkBackgroundGlow(.flint3, 0.50, .topTrailing, 0.45),
                SparkBackgroundGlow(.flint5, 0.45, .bottomLeading, 0.70)
            )
        }
    }
}

// MARK: - Resolution from the stored mode

public struct SparkResolvedAppBackground: View {
    public let date: Date

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("spark.background.mode", store: .sparkAppGroup)
    private var storedMode = SparkAppBackgroundMode.auto.rawValue

    public init(date: Date = .now) {
        self.date = date
    }

    public var body: some View {
        let mode = SparkAppBackgroundMode(rawValue: storedMode) ?? .auto

        SparkAppBackground(slot: mode.resolvedSlot(date: date), scheme: colorScheme)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct SparkResolvedStatusBarBackground: View {
    public let date: Date

    public init(date: Date = .now) {
        self.date = date
    }

    public var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                SparkResolvedAppBackground(date: date)
                    .frame(height: proxy.safeAreaInsets.top)
                    .ignoresSafeArea(edges: .top)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
    }
}

public extension View {
    func sparkAppBackground(date: Date = .now) -> some View {
        modifier(SparkAppBackgroundModifier(date: date))
    }
}

private struct SparkAppBackgroundModifier: ViewModifier {
    let date: Date

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(SparkResolvedAppBackground(date: date))
    }
}

#Preview("Light — morning / day / evening / night") {
    VStack(spacing: 0) {
        ForEach(SparkTimeOfDay.allCases, id: \.self) { slot in
            ZStack {
                SparkAppBackground(slot: slot, scheme: .light)
                Text(slot.greeting)
                    .font(SparkTypography.hero)
                    .foregroundStyle(.black)
            }
        }
    }
}

#Preview("Dark — morning / day / evening / night") {
    VStack(spacing: 0) {
        ForEach(SparkTimeOfDay.allCases, id: \.self) { slot in
            ZStack {
                SparkAppBackground(slot: slot, scheme: .dark)
                Text(slot.greeting)
                    .font(SparkTypography.hero)
                    .foregroundStyle(.white)
            }
        }
    }
}
