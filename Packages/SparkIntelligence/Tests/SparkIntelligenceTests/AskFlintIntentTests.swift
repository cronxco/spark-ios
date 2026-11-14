import Foundation
import Testing
@testable import SparkIntelligence
import SparkKit

@Suite("Ask Flint intent")
struct AskFlintIntentTests {
    @Test("a failed ask is explained by what went wrong")
    func failures() throws {
        let url = try #require(URL(string: "https://spark.test/flint/ask"))

        #expect(AskFlintIntentError(APIError.unauthorized) == .signedOut)
        #expect(AskFlintIntentError(APIError.httpStatus(403, nil, url)) == .signedOut)
        #expect(AskFlintIntentError(APIError.httpStatus(429, nil, url)) == .allowanceSpent)
        #expect(AskFlintIntentError(APIError.transport(URLError(.notConnectedToInternet))) == .offline)
        #expect(AskFlintIntentError(APIError.httpStatus(503, nil, url)) == .unavailable)
        #expect(AskFlintIntentError(CancellationError()) == .unavailable)
    }

    @Test("the intent carries the question it was made with")
    func question() {
        #expect(AskFlintIntent(question: "How did I sleep?").question == "How did I sleep?")
    }
}
