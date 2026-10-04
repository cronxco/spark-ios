import Testing
@testable import SparkKit

@Suite("HTML fragment text")
struct HTMLFragmentTextTests {
    @Test("strips tags and preserves visible text")
    func stripsTagsAndPreservesVisibleText() {
        let html = #"80 <span class="text-sm text-muted">bpm</span>"#

        #expect(html.sparkPlainTextFromHTMLFragment == "80 bpm")
    }

    @Test("decodes entities and escaped tags")
    func decodesEntitiesAndEscapedTags() {
        let html = #"97&lt;span class=&quot;text-sm&quot;&gt;%&lt;/span&gt; &amp; steady"#

        #expect(html.sparkPlainTextFromHTMLFragment == "97% & steady")
    }
}
