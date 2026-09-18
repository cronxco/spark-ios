import SwiftUI

// MARK: - Spark brand palette
//
// Tokens mirror the Spark Design System. Each family below is a ten-step ramp,
// 0 lightest through 9 darkest, with the family's base at 5 — the same scale
// the design system publishes, so these can be diffed against its
// `tokens.json` directly. Brand colours are constants — they don't adapt to
// light/dark by themselves. Surface/text tokens further down DO adapt.

public extension Color {
    // Spark — the brand amber. `spark5` is the brand primary.
    static let spark0 = Color(red: 1.000, green: 0.976, blue: 0.898) // #FFF9E5
    static let spark1 = Color(red: 1.000, green: 0.949, blue: 0.800) // #FFF2CC
    static let spark2 = Color(red: 1.000, green: 0.902, blue: 0.600) // #FFE699
    static let spark3 = Color(red: 1.000, green: 0.851, blue: 0.400) // #FFD966
    static let spark4 = Color(red: 1.000, green: 0.800, blue: 0.200) // #FFCC33
    static let spark5 = Color(red: 1.000, green: 0.749, blue: 0.000) // #FFBF00 — base
    static let spark6 = Color(red: 0.800, green: 0.600, blue: 0.000) // #CC9900
    static let spark7 = Color(red: 0.600, green: 0.451, blue: 0.000) // #997300
    static let spark8 = Color(red: 0.400, green: 0.302, blue: 0.000) // #664D00
    static let spark9 = Color(red: 0.200, green: 0.149, blue: 0.000) // #332600

    // Ember — orange. Bridges Spark and Flame; the activity tint.
    static let ember0 = Color(red: 0.996, green: 0.961, blue: 0.922) // #FEF5EB
    static let ember1 = Color(red: 0.992, green: 0.910, blue: 0.827) // #FDE8D3
    static let ember2 = Color(red: 0.988, green: 0.831, blue: 0.671) // #FCD4AB
    static let ember3 = Color(red: 0.980, green: 0.741, blue: 0.498) // #FABD7F
    static let ember4 = Color(red: 0.976, green: 0.651, blue: 0.325) // #F9A653
    static let ember5 = Color(red: 0.969, green: 0.569, blue: 0.161) // #F79129 — base
    static let ember6 = Color(red: 0.867, green: 0.451, blue: 0.031) // #DD7308
    static let ember7 = Color(red: 0.655, green: 0.341, blue: 0.024) // #A75706
    static let ember8 = Color(red: 0.443, green: 0.231, blue: 0.016) // #713B04
    static let ember9 = Color(red: 0.212, green: 0.110, blue: 0.008) // #361C02

    // Flame — red/coral. The media tint and the hottest signal.
    static let flame0 = Color(red: 0.992, green: 0.933, blue: 0.925) // #FDEEEC
    static let flame1 = Color(red: 0.988, green: 0.886, blue: 0.871) // #FCE2DE
    static let flame2 = Color(red: 0.973, green: 0.757, blue: 0.725) // #F8C1B9
    static let flame3 = Color(red: 0.961, green: 0.643, blue: 0.600) // #F5A499
    static let flame4 = Color(red: 0.945, green: 0.510, blue: 0.455) // #F18274
    static let flame5 = Color(red: 0.933, green: 0.388, blue: 0.322) // #EE6352 — base
    static let flame6 = Color(red: 0.910, green: 0.184, blue: 0.090) // #E82F17
    static let flame7 = Color(red: 0.690, green: 0.141, blue: 0.067) // #B02411
    static let flame8 = Color(red: 0.455, green: 0.094, blue: 0.043) // #74180B
    static let flame9 = Color(red: 0.235, green: 0.047, blue: 0.024) // #3C0C06

    // Sky — the bright blue. `sky5` is the cool accent.
    static let sky0 = Color(red: 0.922, green: 0.953, blue: 0.976) // #ebf3f9
    static let sky1 = Color(red: 0.847, green: 0.906, blue: 0.953) // #d8e7f3
    static let sky2 = Color(red: 0.694, green: 0.812, blue: 0.906) // #b1cfe7
    static let sky3 = Color(red: 0.553, green: 0.725, blue: 0.867) // #8db9dd
    static let sky4 = Color(red: 0.400, green: 0.631, blue: 0.820) // #66a1d1
    static let sky5 = Color(red: 0.247, green: 0.533, blue: 0.773) // #3f88c5 — base
    static let sky6 = Color(red: 0.192, green: 0.431, blue: 0.631) // #316ea1
    static let sky7 = Color(red: 0.145, green: 0.325, blue: 0.475) // #255379
    static let sky8 = Color(red: 0.094, green: 0.212, blue: 0.306) // #18364e
    static let sky9 = Color(red: 0.047, green: 0.106, blue: 0.153) // #0c1b27

    // Ocean — deep blue. `ocean5` is the web's light-mode accent fill.
    static let ocean0 = Color(red: 0.200, green: 0.435, blue: 0.722) // #336fb8
    static let ocean1 = Color(red: 0.192, green: 0.424, blue: 0.706) // #316cb4
    static let ocean2 = Color(red: 0.180, green: 0.396, blue: 0.659) // #2e65a8
    static let ocean3 = Color(red: 0.169, green: 0.369, blue: 0.612) // #2b5e9c
    static let ocean4 = Color(red: 0.157, green: 0.341, blue: 0.565) // #285790
    static let ocean5 = Color(red: 0.141, green: 0.310, blue: 0.514) // #244f83 — base
    static let ocean6 = Color(red: 0.114, green: 0.247, blue: 0.408) // #1d3f68
    static let ocean7 = Color(red: 0.086, green: 0.188, blue: 0.314) // #163050
    static let ocean8 = Color(red: 0.055, green: 0.122, blue: 0.204) // #0e1f34
    static let ocean9 = Color(red: 0.031, green: 0.067, blue: 0.110) // #08111c

    // Flint — navy. The darkest cool family before Slate.
    static let flint0 = Color(red: 0.071, green: 0.161, blue: 0.490) // #12297d
    static let flint1 = Color(red: 0.067, green: 0.153, blue: 0.475) // #112779
    static let flint2 = Color(red: 0.059, green: 0.137, blue: 0.420) // #0f236b
    static let flint3 = Color(red: 0.051, green: 0.122, blue: 0.369) // #0d1f5e
    static let flint4 = Color(red: 0.043, green: 0.098, blue: 0.298) // #0b194c
    static let flint5 = Color(red: 0.035, green: 0.082, blue: 0.251) // #091540 — base
    static let flint6 = Color(red: 0.027, green: 0.063, blue: 0.192) // #071031
    static let flint7 = Color(red: 0.024, green: 0.051, blue: 0.157) // #060d28
    static let flint8 = Color(red: 0.016, green: 0.035, blue: 0.106) // #04091b
    static let flint9 = Color(red: 0.008, green: 0.016, blue: 0.051) // #02040d

    // Slate — the near-black ground. `slate5` is the dark-theme surface.
    static let slate0 = Color(red: 0.008, green: 0.208, blue: 0.369) // #02355E
    static let slate1 = Color(red: 0.008, green: 0.196, blue: 0.353) // #02325A
    static let slate2 = Color(red: 0.008, green: 0.165, blue: 0.294) // #022A4B
    static let slate3 = Color(red: 0.008, green: 0.141, blue: 0.255) // #022441
    static let slate4 = Color(red: 0.004, green: 0.110, blue: 0.196) // #011C32
    static let slate5 = Color(red: 0.004, green: 0.086, blue: 0.153) // #011627 — base
    static let slate6 = Color(red: 0.004, green: 0.067, blue: 0.118) // #01111E
    static let slate7 = Color(red: 0.004, green: 0.055, blue: 0.098) // #010E19
    static let slate8 = Color(red: 0.000, green: 0.031, blue: 0.059) // #00080F
    static let slate9 = Color(red: 0.000, green: 0.024, blue: 0.039) // #00060A

    // Ash — the light neutral ground. `ash1` is the light-theme surface.
    // Steps 0-2 are the same #FCFCFC: the ramp is tight enough that they
    // collapse at 8-bit. Kept so the scale lines up with every other family.
    static let ash0 = Color(red: 0.988, green: 0.988, blue: 0.988) // #FCFCFC
    static let ash1 = Color(red: 0.988, green: 0.988, blue: 0.988) // #FCFCFC
    static let ash2 = Color(red: 0.988, green: 0.988, blue: 0.988) // #FCFCFC
    static let ash3 = Color(red: 0.980, green: 0.980, blue: 0.980) // #FAFAFA
    static let ash4 = Color(red: 0.969, green: 0.969, blue: 0.969) // #F7F7F7
    static let ash5 = Color(red: 0.961, green: 0.961, blue: 0.961) // #F5F5F5 — base
    static let ash6 = Color(red: 0.949, green: 0.949, blue: 0.949) // #F2F2F2
    static let ash7 = Color(red: 0.929, green: 0.929, blue: 0.929) // #EDEDED
    static let ash8 = Color(red: 0.922, green: 0.922, blue: 0.922) // #EBEBEB
    static let ash9 = Color(red: 0.902, green: 0.902, blue: 0.902) // #E6E6E6
}

// MARK: - Semantic colours

public extension Color {
    /// Brand primary. Use for CTAs, active tab tint, hero values.
    static let sparkAccent = Color.spark5

    /// Cool accent — sleep, health, depth. Resolves to `sky5`; the name is a
    /// role, like `sparkAccent`, not the family it draws from.
    static let sparkOcean = Color.sky5

    static let sparkSuccess = Color(red: 0.478, green: 0.729, blue: 0.631)
    static let sparkWarning = Color(red: 0.694, green: 0.424, blue: 0.537)
    static let sparkError = Color(red: 0.886, green: 0.412, blue: 0.412)
    /// Not a ramp step — `#649ec0` is the informational semantic, and the
    /// design system keeps it outside the eight families alongside success,
    /// warning and error.
    static let sparkInfo = Color(red: 0.392, green: 0.620, blue: 0.753)

    // Backwards-compat for Phase 1 callers.
    static let sparkPositive = sparkSuccess
    static let sparkNegative = sparkError
}

// MARK: - Domain tints
//
// One canonical accent per domain so cards/widgets stay coherent.

public extension Color {
    static let domainHealth = Color.sparkSuccess
    static let domainActivity = Color.ember5
    static let domainMoney = Color.spark5
    static let domainMedia = Color.flame5
    static let domainKnowledge = Color.sky5
    static let domainAnomaly = Color.sparkWarning
}

// MARK: - Tag type tints
//
// Colour-codes EventTag.type in chip display. Reuses existing semantic tokens
// where they fit the semantic (place → success green).

public extension Color {
    static let sparkTagPerson: Color = .purple
    static let sparkTagPlace: Color  = .sparkSuccess
    static let sparkTagTopic: Color  = .orange
}

// MARK: - Surfaces (light/dark adaptive)

public extension Color {
    /// Primary surface used under cards and sheets.
    static let sparkSurface = Color("SparkSurface", bundle: nil).fallback(
        light: .ash1,
        dark: .slate5
    )

    /// Elevated surface for grouped cards.
    static let sparkElevated = Color("SparkElevated", bundle: nil).fallback(
        light: .white,
        dark: .slate3
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
