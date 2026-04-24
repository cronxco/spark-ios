import SwiftUI

public extension Color {
    /// Spark accent — warm amber, legible on both light and dark backgrounds.
    static let sparkAccent = Color(red: 0.95, green: 0.55, blue: 0.18)

    /// Primary surface used under cards and sheets.
    static let sparkSurface = Color("SparkSurface", bundle: nil).fallback(
        light: Color(red: 0.98, green: 0.97, blue: 0.95),
        dark: Color(red: 0.09, green: 0.09, blue: 0.10)
    )

    /// Elevated surface for grouped cards.
    static let sparkElevated = Color("SparkElevated", bundle: nil).fallback(
        light: Color(red: 1, green: 1, blue: 1),
        dark: Color(red: 0.13, green: 0.13, blue: 0.14)
    )

    static let sparkTextPrimary = Color.primary
    static let sparkTextSecondary = Color.secondary
    static let sparkPositive = Color.green
    static let sparkNegative = Color.red
    static let sparkWarning = Color.yellow
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
