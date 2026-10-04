import Foundation
import Testing
@testable import SparkKit

@Suite("Integration reauthorisation callbacks")
struct IntegrationReauthTests {
    @Test("success must belong to the requested attempt")
    func validatesAttempt() throws {
        try IntegrationReauthService.validateCallback(
            URL(string: "spark://integrations/reauth-complete?status=success&attempt_id=abc")!,
            expectedAttemptID: "abc"
        )
        #expect(throws: IntegrationReauthError.self) {
            try IntegrationReauthService.validateCallback(
                URL(string: "spark://integrations/reauth-complete?status=success&attempt_id=other")!,
                expectedAttemptID: "abc"
            )
        }
    }

    @Test("error and malformed callbacks cannot report success", arguments: [
        "spark://integrations/reauth-complete?status=error",
        "spark://integrations/reauth-complete",
        "spark://integrations/reauth-complete?status=unknown",
        "spark://integrations/reauth-complete?status=success&status=error",
        "spark://other/reauth-complete?status=success",
        "spark://integrations/other?status=success",
        "https://integrations/reauth-complete?status=success"
    ])
    func rejectsInvalidCallbacks(_ value: String) {
        #expect(throws: IntegrationReauthError.self) {
            try IntegrationReauthService.validateCallback(URL(string: value)!)
        }
    }

    @Test("older servers remain compatible while new attempt IDs decode")
    func decodesStartResponse() throws {
        let decoder = JSONDecoder()
        let old = try decoder.decode(IntegrationsEndpoint.OAuthStartResponse.self,
            from: Data(#"{"url":"https://example.test/start"}"#.utf8))
        #expect(old.attemptID == nil)
        try IntegrationReauthService.validateCallback(URL(string: "spark://integrations/reauth-complete?status=success")!)
        let new = try decoder.decode(IntegrationsEndpoint.OAuthStartResponse.self,
            from: Data(#"{"url":"https://example.test/start","attempt_id":"abc"}"#.utf8))
        #expect(new.attemptID == "abc")
    }
}
