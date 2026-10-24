import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("CMD return key")
@MainActor
struct CmdReturnKeyTests {
    @Test("a newline typed at the end sends the line")
    func newlineSubmits() {
        let model = CmdViewModel(
            classifier: HeuristicCmdClassifier(), submitter: StubCmdSubmitter(),
            queue: CmdQueue(), recentStore: CmdRecentStore())
        model.input = "This is a test reflection"
        model.input = "This is a test reflection\n"
        model.inputChanged(from: "This is a test reflection")

        #expect(model.input.isEmpty)
        #expect(!model.recents.isEmpty)
    }
}
