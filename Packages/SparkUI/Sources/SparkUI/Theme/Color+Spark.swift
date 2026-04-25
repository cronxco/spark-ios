import SwiftUI

// MARK: - Spark brand palette
//
// Tokens mirror the Spark Design System (see `tokens.css` in the design
// bundle). Brand colours are constants — they don't adapt to light/dark by
// themselves. Surface/text tokens further down DO adapt.

public extension Color {
    // Spark — warm amber to orange.
    static let spark50 = Color(red: 1.000, green: 0.969, blue: 0.839)
    static let spark100 = Color(red: 1.000, green: 0.914, blue: 0.604)
    static let spark200 = Color(red: 1.000, green: 0.851, blue: 0.400)
    static let spark300 = Color(red: 1.000, green: 0.800, blue: 0.200)
    /// Brand primary — used for CTAs, hero values, active selection.
    static let spark400 = Color(red: 1.000, green: 0.749, blue: 0.000)
    static let spark500 = Color(red: 0.969, green: 0.569, blue: 0.161)
    static let spark600 = Color(red: 0.851, green: 0.455, blue: 0.102)
    static let spark700 = Color(red: 0.690, green: 0.314, blue: 0.059)

    // Flame
    static let flame100 = Color(red: 0.980, green: 0.741, blue: 0.498)
    static let flame200 = Color(red: 0.969, green: 0.569, blue: 0.161)
    static let flame300 = Color(red: 0.690, green: 0.141, blue: 0.067)
    static let flame400 = Color(red: 0.455, green: 0.094, blue: 0.043)
    static let flame500 = Color(red: 0.235, green: 0.047, blue: 0.024)

    // Ember
    static let ember100 = Color(red: 0.973, green: 0.757, blue: 0.725)
    static let ember200 = Color(red: 0.961, green: 0.643, blue: 0.600)
    static let ember300 = Color(red: 0.933, green: 0.388, blue: 0.322)

    // Ocean — cool blues, used for sleep/health.
    static let ocean100 = Color(red: 0.553, green: 0.725, blue: 0.867)
    static let ocean200 = Color(red: 0.392, green: 0.620, blue: 0.753)
    static let ocean300 = Color(red: 0.247, green: 0.533, blue: 0.773)
    static let ocean400 = Color(red: 0.192, green: 0.431, blue: 0.631)
    static let ocean500 = Color(red: 0.169, green: 0.369, blue: 0.612)
    static let ocean600 = Color(red: 0.141, green: 0.310, blue: 0.514)
    static let ocean700 = Color(red: 0.086, green: 0.188, blue: 0.314)
    static let ocean800 = Color(red: 0.051, green: 0.122, blue: 0.369)
    static let ocean900 = Color(red: 0.035, green: 0.082, blue: 0.251)
    static let ocean950 = Color(red: 0.024, green: 0.051, blue: 0.157)
    static let sky100 = Color(red: 0.820, green: 0.855, blue: 0.902)

    // Slate — used as cool dark base in evening/night gradients.
    static let slate500 = Color(red: 0.004, green: 0.086, blue: 0.153)
    static let slate600 = Color(red: 0.004, green: 0.055, blue: 0.098)
    static let slate700 = Color(red: 0.004, green: 0.071, blue: 0.125)

    // Ash — light neutrals.
    static let ash100 = Color(red: 0.988, green: 0.988, blue: 0.988)
    static let ash200 = Color(red: 0.961, green: 0.961, blue: 0.961)
    static let ash300 = Color(red: 0.922, green: 0.922, blue: 0.922)
    static let ash400 = Color(red: 0.851, green: 0.851, blue: 0.851)
}

// MARK: - Semantic colours

public extension Color {
    /// Brand primary. Use for CTAs, active tab tint, hero values.
    static let sparkAccent = Color.spark400

    /// Cool accent — sleep, health, depth.
    static let sparkOcean = Color.ocean300

    static let sparkSuccess = Color(red: 0.478, green: 0.729, blue: 0.631)
    static let sparkWarning = Color(red: 0.694, green: 0.424, blue: 0.537)
    static let sparkError = Color(red: 0.886, green: 0.412, blue: 0.412)
    static let sparkInfo = Color.ocean200

    // Backwards-compat for Phase 1 callers.
    static let sparkPositive = sparkSuccess
    static let sparkNegative = sparkError
}

// MARK: - Domain tints
//
// One canonical accent per domain so cards/widgets stay coherent.

public extension Color {
    static let domainHealth = Color.sparkSuccess
    static let domainActivity = Color.spark500
    static let domainMoney = Color.spark400
    static let domainMedia = Color.ember300
    static let domainKnowledge = Color.ocean300
    static let domainAnomaly = Color.sparkWarning
}

// MARK: - Surfaces (light/dark adaptive)

public extension Color {
    /// Primary surface used under cards and sheets.
    static let sparkSurface = Color("SparkSurface", bundle: nil).fallback(
        light: Color(red: 0.969, green: 0.957, blue: 0.925),
        dark: Color(red: 0.024, green: 0.051, blue: 0.090)
    )

    /// Elevated surface for grouped cards.
    static let sparkElevated = Color("SparkElevated", bundle: nil).fallback(
        light: Color(red: 1, green: 1, blue: 1),
        dark: Color(red: 0.090, green: 0.106, blue: 0.149)
    )

    static let sparkTextPrimary = Color.primary
    static let sparkTextSecondary = Color.secondary
}

private extension Color {
    /// Falls back to a hard-coded colour if the asset catalogue lookup misses
    /// (e.g. previews in SPM targets without an asset bundle).
    func fallback(light: Color, dark: Color) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}
