import CoreText
import Foundation
import Testing
@testable import SparkUI

@Suite("Spark bundled fonts")
struct SparkFontsTests {
    /// A missing font no longer stops the app at launch, so this is where a
    /// renamed or dropped file shows up.
    @Test("every bundled font file is in the resource bundle", arguments: SparkFonts.bundledFontFiles)
    func fontFileIsBundled(_ name: String) {
        #expect(SparkFonts.bundledFontURL(name) != nil, "\(name).ttf is not in SparkUI's resource bundle")
    }

    @Test("the icon font carries the PostScript name the glyphs look up")
    func iconFontPostScriptName() throws {
        let url = try #require(SparkFonts.bundledFontURL("SparkIcons-Solid"))
        let descriptors = try #require(CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])
        let names = descriptors.compactMap {
            CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String
        }
        #expect(names.contains(SparkFonts.iconPostScriptName))
    }
}
