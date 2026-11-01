import CoreText
import Foundation
import OSLog
import SwiftUI

/// Bundled type. Comfortaa is used for hero/display moments, PT Mono for
/// timestamps and IDs. Body and UI text stay on SF Pro so Dynamic Type and
/// VoiceOver behave like every other iOS app.
public enum SparkFonts {
    /// Postscript names (what `Font.custom(...)` looks up after registration).
    public static let displayPostScriptName = "Comfortaa"
    public static let monoPostScriptName = "PTMono-Regular"
    /// Font Awesome Solid, cut down to the glyphs in `icons.json` and renamed
    /// "Spark Icons", because the OFL reserves the "Font Awesome" name.
    public static let iconPostScriptName = "SparkIcons-Solid"

    /// The font files bundled in `Resources/Fonts`, without their extension.
    static let bundledFontFiles = [
        "Comfortaa-VariableFont_wght",
        "PTMono-Regular",
        "SparkIcons-Solid",
    ]

    /// Register the bundled fonts with Core Text. Call once at app launch
    /// before any view that depends on them renders. Idempotent.
    ///
    /// A font that is missing or fails to register is logged and skipped, never
    /// fatal: `Font.custom` falls back to the system face, so the app still
    /// launches with plain text in place of the missing type. The
    /// `SparkFontsTests` suite is what catches a missing file.
    public static func registerBundledFonts() {
        guard !hasRegistered else { return }
        for name in bundledFontFiles {
            register(name, ext: "ttf")
        }
        hasRegistered = true
    }

    /// Comfortaa display font scaled against the given system text style so
    /// Dynamic Type still works.
    public static func display(_ style: Font.TextStyle = .largeTitle, weight: Font.Weight = .bold) -> Font {
        Font.custom(displayPostScriptName, size: pointSize(for: style), relativeTo: style)
            .weight(weight)
    }

    /// Comfortaa at a fixed point size — for hero numerals where exact sizing matters.
    public static func display(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        Font.custom(displayPostScriptName, size: size).weight(weight)
    }

    /// Comfortaa at a design point size that still scales with Dynamic Type
    /// against `style`.
    public static func display(size: CGFloat, relativeTo style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        Font.custom(displayPostScriptName, size: size, relativeTo: style).weight(weight)
    }

    /// PT Mono at the given style. Good for timestamps, IDs, hex codes.
    public static func mono(_ style: Font.TextStyle = .footnote) -> Font {
        Font.custom(monoPostScriptName, size: pointSize(for: style), relativeTo: style)
    }

    /// The Font Awesome face at a design size that scales with Dynamic Type
    /// against `style`, so a glyph keeps pace with the text beside it.
    public static func icon(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        Font.custom(iconPostScriptName, size: size, relativeTo: style)
    }

    // MARK: - Private

    private nonisolated(unsafe) static var hasRegistered = false

    private static let logger = Logger(subsystem: "co.cronx.sparkapp", category: "SparkFonts")

    /// The bundled file for `name`, or nil when the resource bundle lacks it.
    static func bundledFontURL(_ name: String, ext: String = "ttf") -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext)
    }

    private static func register(_ name: String, ext: String) {
        guard let url = bundledFontURL(name, ext: ext) else {
            logger.error("Missing bundled font \(name, privacy: .public).\(ext, privacy: .public); falling back to the system font")
            return
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            let reason = error.map { String(describing: $0.takeRetainedValue()) } ?? "unknown error"
            logger.error("Failed to register \(name, privacy: .public): \(reason, privacy: .public)")
        }
    }

    private static func pointSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
    }
}
