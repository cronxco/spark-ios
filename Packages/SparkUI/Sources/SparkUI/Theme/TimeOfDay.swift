import SwiftUI

/// The four time-of-day moods Today renders against. Each maps to a
/// background gradient + a default greeting.
public enum SparkTimeOfDay: String, CaseIterable, Sendable {
    case morning
    case afternoon
    case evening
    case night

    /// Pick the slot for the given hour of day (24h, local time).
    public static func from(hour: Int) -> SparkTimeOfDay {
        switch hour {
        case 5..<11: .morning
        case 11..<17: .afternoon
        case 17..<21: .evening
        default: .night
        }
    }

    public static func from(date: Date, calendar: Calendar = .current) -> SparkTimeOfDay {
        from(hour: calendar.component(.hour, from: date))
    }

    /// Default greeting copy. Callers can override.
    public var greeting: String {
        switch self {
        case .morning: "Good morning"
        case .afternoon: "Good afternoon"
        case .evening: "Good evening"
        case .night: "Still up?"
        }
    }

    /// Whether the slot prefers light-on-dark text.
    public var prefersDarkTreatment: Bool {
        self == .evening || self == .night
    }
}

/// Today-only background. Two stacked radial gradients give the design's
/// dawn/day/evening/night washes a sense of depth without fighting the system
/// material under cards.
public struct TodayBackground: View {
    public let timeOfDay: SparkTimeOfDay

    public init(_ timeOfDay: SparkTimeOfDay) {
        self.timeOfDay = timeOfDay
    }

    public var body: some View {
        ZStack {
            base
            top
            bottom
        }
        .ignoresSafeArea()
    }

    private var base: some View {
        switch timeOfDay {
        case .morning:
            return LinearGradient(
                colors: [Color(red: 0.996, green: 0.969, blue: 0.922), Color(red: 0.961, green: 0.937, blue: 0.898)],
                startPoint: .top, endPoint: .bottom
            )
        case .afternoon:
            return LinearGradient(
                colors: [Color(red: 0.984, green: 0.973, blue: 0.941), Color(red: 0.953, green: 0.933, blue: 0.878)],
                startPoint: .top, endPoint: .bottom
            )
        case .evening:
            return LinearGradient(
                colors: [Color(red: 0.173, green: 0.212, blue: 0.329), Color(red: 0.047, green: 0.082, blue: 0.188)],
                startPoint: .top, endPoint: .bottom
            )
        case .night:
            return LinearGradient(
                colors: [Color(red: 0.020, green: 0.043, blue: 0.110), Color(red: 0.004, green: 0.024, blue: 0.078)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private var top: some View {
        switch timeOfDay {
        case .morning:
            radial(Color(red: 1.0, green: 0.961, blue: 0.847), at: .topTrailing, span: 0.6)
        case .afternoon:
            radial(Color(red: 1.0, green: 0.984, blue: 0.902), at: .topTrailing, span: 0.55)
        case .evening:
            radial(Color(red: 0.722, green: 0.800, blue: 0.875), at: .topTrailing, span: 0.5)
        case .night:
            radial(Color(red: 0.114, green: 0.176, blue: 0.329), at: .topTrailing, span: 0.4)
        }
    }

    @ViewBuilder
    private var bottom: some View {
        switch timeOfDay {
        case .morning:
            radial(Color(red: 1.0, green: 0.910, blue: 0.780), at: .bottomLeading, span: 0.6)
        case .afternoon:
            radial(Color(red: 0.941, green: 0.902, blue: 0.843), at: .bottomLeading, span: 0.6)
        case .evening:
            radial(Color(red: 0.102, green: 0.153, blue: 0.278), at: .bottomLeading, span: 0.6)
        case .night:
            radial(Color(red: 0.039, green: 0.071, blue: 0.157), at: .bottomLeading, span: 0.7)
        }
    }

    private func radial(_ colour: Color, at unit: UnitPoint, span: CGFloat) -> some View {
        GeometryReader { proxy in
            let size = max(proxy.size.width, proxy.size.height) * (span * 1.3)
            RadialGradient(
                colors: [colour.opacity(0.85), .clear],
                center: unit,
                startRadius: 0,
                endRadius: size
            )
            .blendMode(.plusLighter)
        }
    }
}

#Preview("Morning / Afternoon / Evening / Night") {
    VStack(spacing: 0) {
        ForEach(SparkTimeOfDay.allCases, id: \.self) { slot in
            ZStack {
                TodayBackground(slot)
                Text(slot.greeting)
                    .font(SparkTypography.hero)
                    .foregroundStyle(slot.prefersDarkTreatment ? .white : .black)
            }
        }
    }
}
