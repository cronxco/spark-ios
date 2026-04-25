import CoreText
import Foundation
import SwiftUI

/// Bundled type. Comfortaa is used for hero/display moments, PT Mono for
/// timestamps and IDs. Body and UI text stay on SF Pro so Dynamic Type and
/// VoiceOver behave like every other iOS app.
public enum SparkFonts {
    /// Postscript names (what `Font.custom(...)` looks up after registration).
    public static let displayPostScriptName = "Comfortaa"
    public static let monoPostScriptName = "PTMono-Regular"

    /// Register the bundled fonts with Core Text. Call once at app launch
    /// before any view that depends on them renders. Idempotent.
    public static func registerBundledFonts() {
        guard !hasRegistered else { return }
        register("Comfortaa-VariableFont_wght", ext: "ttf")
        register("PTMono-Regular", ext: "ttf")
        hasRegistered = true
    }

    /// Comfortaa display font scaled against the given system text style so
    /// Dynamic Type still works.
    public static func display(_ style: Font.TextStyle = .largeTitle, weight: Font.Weight = .bold) -> Font {
        Font.custom(displayPostScriptName, size: pointSize(for: style), relativeTo: style)
            .weight(weight)
    }

    /// PT Mono at the given style. Good for timestamps, IDs, hex codes.
    public static func mono(_ style: Font.TextStyle = .footnote) -> Font {
        Font.custom(monoPostScriptName, size: pointSize(for: style), relativeTo: style)
    }

    // MARK: - Private

    private nonisolated(unsafe) static var hasRegistered = false

    private static func register(_ name: String, ext: String) {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            assertionFailure("Missing bundled font: \(name).\(ext)")
            return
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            // Silent in release; the next Font.custom call will fall back to system.
            assertionFailure("Failed to register \(name): \(String(describing: error?.takeRetainedValue()))")
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
