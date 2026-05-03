import SwiftUI

/// Type system. Hero/display uses Comfortaa via `SparkFonts.display`. Mono
/// uses PT Mono via `SparkFonts.mono`. Body/UI stays on SF Pro so Dynamic
/// Type behaves like a first-party app.
public enum SparkTypography {
    // Hero / display — Comfortaa
    public static let heroXL = SparkFonts.display(.largeTitle, weight: .bold)
    public static let hero = SparkFonts.display(.title, weight: .bold)
    public static let heroSmall = SparkFonts.display(.title2, weight: .bold)

    // Backwards-compat aliases used by Phase 1 components.
    public static let displayLarge = heroXL
    public static let display = hero
    public static let titleStrong = heroSmall

    // Body / UI — SF Pro (Font.system gives free Dynamic Type)
    public static let title = Font.system(.title3)
    public static let bodyStrong = Font.system(.body).weight(.semibold)
    public static let body = Font.system(.body)
    public static let bodySmall = Font.system(.callout)
    public static let caption = Font.system(.caption)
    public static let captionStrong = Font.system(.caption).weight(.semibold)

    // Technical — PT Mono. Used for timestamps, IDs, all-caps section labels.
    public static let mono = SparkFonts.mono(.footnote)
    public static let monoSmall = SparkFonts.mono(.caption2)
    public static let monoBody = SparkFonts.mono(.body)
}

public extension View {
    /// Clamp Dynamic Type to a3 so hero glyphs don't overflow the iPhone
    /// frame. Apply at the app root.
    func sparkDynamicTypeClamp() -> some View {
        self.dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}
