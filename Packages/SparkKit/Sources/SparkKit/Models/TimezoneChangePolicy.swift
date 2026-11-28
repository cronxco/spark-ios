import Foundation

/// Decides when the app should ask whether Spark should follow the device's
/// timezone (CRX-724). Compares IANA identifiers only, so a daylight-saving
/// change within one timezone never prompts.
public enum TimezoneChangePolicy {
    /// Identifies one "keep my timezone" answer: the timezone Spark uses and
    /// the device timezone the user declined. A change on either side makes a
    /// new key, so the prompt returns for a genuinely new situation.
    public static func rejectionKey(
        acknowledgedTimezone: String,
        deviceTimezone: String
    ) -> String {
        "\(acknowledgedTimezone)\n\(deviceTimezone)"
    }

    public static func shouldPrompt(
        acknowledgedTimezone: String,
        deviceTimezone: String,
        rejectedKey: String?
    ) -> Bool {
        guard acknowledgedTimezone != deviceTimezone else { return false }
        return rejectedKey != rejectionKey(
            acknowledgedTimezone: acknowledgedTimezone,
            deviceTimezone: deviceTimezone
        )
    }
}
