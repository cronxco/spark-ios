import SparkKit
import SwiftUI

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
}

public enum SparkAppBackgroundPhase: String, CaseIterable, Sendable {
    case morning
    case day
    case eveningLight
    case eveningDark
    case night

    public static func resolve(
        mode: SparkAppBackgroundMode,
        date: Date = .now,
        calendar: Calendar = .current,
        colorScheme: ColorScheme
    ) -> SparkAppBackgroundPhase {
        switch mode {
        case .auto:
            return autoPhase(date: date, calendar: calendar, colorScheme: colorScheme)
        case .morning:
            return .morning
        case .day:
            return .day
        case .evening:
            return colorScheme == .dark ? .eveningDark : .eveningLight
        case .night:
            return .night
        }
    }

    private static func autoPhase(
        date: Date,
        calendar: Calendar,
        colorScheme: ColorScheme
    ) -> SparkAppBackgroundPhase {
        let hour = calendar.component(.hour, from: date)

        if colorScheme == .dark {
            return (6..<22).contains(hour) ? .eveningDark : .night
        }

        switch hour {
        case 6..<10:
            return .morning
        case 10..<17:
            return .day
        default:
            return .eveningLight
        }
    }
}

public struct SparkAppBackground: View {
    public let phase: SparkAppBackgroundPhase

    public init(phase: SparkAppBackgroundPhase) {
        self.phase = phase
    }

    public var body: some View {
        ZStack {
            Color.sparkSurface
            gradient
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var gradient: some View {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var colors: [Color] {
        switch phase {
        case .morning:
            [Color.ocean100.opacity(0.24), Color.spark100.opacity(0.18), Color.clear]
        case .day:
            [Color.domainMoney.opacity(0.16), Color.spark100.opacity(0.16), Color.clear]
        case .eveningLight:
            [
                Color.ember100.opacity(0.22),
                Color.flame100.opacity(0.18),
                Color.spark200.opacity(0.12),
                Color.clear,
            ]
        case .eveningDark:
            [Color.domainMoney.opacity(0.34), Color.ocean950, Color.black.opacity(0.45)]
        case .night:
            [
                Color.ocean800.opacity(0.70),
                Color.slate700.opacity(0.90),
                Color.ocean950,
                Color.black.opacity(0.50),
            ]
        }
    }
}

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
        let phase = SparkAppBackgroundPhase.resolve(
            mode: mode,
            date: date,
            colorScheme: colorScheme
        )

        SparkAppBackground(phase: phase)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.colorScheme, phase == .night ? .dark : colorScheme)
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

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("spark.background.mode", store: .sparkAppGroup)
    private var storedMode = SparkAppBackgroundMode.auto.rawValue

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(SparkResolvedAppBackground(date: date))
    }
}
