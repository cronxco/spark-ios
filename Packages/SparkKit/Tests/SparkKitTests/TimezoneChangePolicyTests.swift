import Foundation
import Testing
@testable import SparkKit

@Suite("Timezone change policy")
struct TimezoneChangePolicyTests {
    @Test("matching timezones never prompt")
    func matchingTimezones() {
        #expect(!TimezoneChangePolicy.shouldPrompt(
            acknowledgedTimezone: "Europe/London",
            deviceTimezone: "Europe/London",
            rejectedKey: nil
        ))
    }

    @Test("a different device timezone prompts")
    func differentTimezone() {
        #expect(TimezoneChangePolicy.shouldPrompt(
            acknowledgedTimezone: "Europe/London",
            deviceTimezone: "Australia/Perth",
            rejectedKey: nil
        ))
    }

    @Test("a declined pair does not prompt again")
    func declinedPair() {
        let key = TimezoneChangePolicy.rejectionKey(
            acknowledgedTimezone: "Europe/London",
            deviceTimezone: "Australia/Perth"
        )
        #expect(!TimezoneChangePolicy.shouldPrompt(
            acknowledgedTimezone: "Europe/London",
            deviceTimezone: "Australia/Perth",
            rejectedKey: key
        ))
    }

    @Test("moving to a third timezone prompts after a decline")
    func thirdTimezone() {
        let key = TimezoneChangePolicy.rejectionKey(
            acknowledgedTimezone: "Europe/London",
            deviceTimezone: "Australia/Perth"
        )
        #expect(TimezoneChangePolicy.shouldPrompt(
            acknowledgedTimezone: "Europe/London",
            deviceTimezone: "Australia/Adelaide",
            rejectedKey: key
        ))
    }

    @Test("a new acknowledged timezone prompts after a decline")
    func newAcknowledgedTimezone() {
        let key = TimezoneChangePolicy.rejectionKey(
            acknowledgedTimezone: "Europe/London",
            deviceTimezone: "Australia/Perth"
        )
        #expect(TimezoneChangePolicy.shouldPrompt(
            acknowledgedTimezone: "Australia/Perth",
            deviceTimezone: "Europe/London",
            rejectedKey: key
        ))
    }
}
