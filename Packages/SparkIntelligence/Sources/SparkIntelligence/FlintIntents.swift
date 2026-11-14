import AppIntents
import Foundation
import SparkKit

// MARK: - Ask Flint

/// Ask Flint from Shortcuts and Spotlight, and from Siri AI where the build
/// allows it.
///
/// `@AppIntent(.tool)` (iOS 27.3, Siri AI Developer Preview) makes this a
/// tool Siri can call for a request that fits no app schema: "ask Spark how
/// I slept this week". Siri reads the title and the descriptions below to
/// decide when to call it, so they are written for a model. The macro needs
/// the iOS 27.3 SDK, so it is compiled in only under `SPARK_SIRI_AI_TOOLS`
/// (see `Package.swift`); such a build offers the intent on iOS 27.3 and
/// later. Without the flag this is an ordinary intent on every iOS 27.
///
/// An ask from here is read-only: the server withholds Flint's write tools
/// for the turn, because nothing here can show the Undo a change comes with.
/// The answer can hold money and health details, so the device running the
/// intent must itself be unlocked.
#if SPARK_SIRI_AI_TOOLS
@available(iOS 27.3, macOS 27.3, *)
@AppIntent(.tool)
#endif
public struct AskFlintIntent: AppIntent {
    public static let title: LocalizedStringResource = "Ask Flint"
    public static let description = IntentDescription(
        LocalizedStringResource(
            "Asks Flint, the assistant in Spark, a question about the person's own data: sleep, activity and other health metrics, spending and transactions, what they watched, read or listened to, places they went, and summaries of a day or week. Returns a short written answer. It only reads data and can't change anything."
        )
    )
    public static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(
        title: "Question",
        description: LocalizedStringResource(
            "The question to answer from the person's Spark data, in their own words, with any dates, names or amounts they gave."
        )
    )
    public var question: String

    public init() {}
    public init(question: String) { self.question = question }

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw $question.needsValueError("What would you like to ask Flint?")
        }

        let service = await IntentService()
        let answer: FlintAskAnswer
        do {
            answer = try await service.apiClient.request(
                FlintAskEndpoint.ask(message: String(text.prefix(FlintAskEndpoint.maximumMessageLength)), readOnly: true)
            )
        } catch {
            throw AskFlintIntentError(error)
        }

        let spoken = FlintAskText.spoken(answer.message.text)
        guard !spoken.isEmpty else { throw AskFlintIntentError.unavailable }

        await IntentDonations.donate(self)
        return .result(value: spoken, dialog: "\(spoken)")
    }
}

/// Why Flint couldn't answer, in words Siri can say.
public enum AskFlintIntentError: Error, Equatable, CustomLocalizedStringResourceConvertible {
    case signedOut
    case allowanceSpent
    case offline
    case unavailable

    init(_ error: Error) {
        guard let apiError = error as? APIError else {
            self = .unavailable
            return
        }
        switch apiError {
        case .unauthorized, .httpStatus(401, _, _), .httpStatus(403, _, _):
            self = .signedOut
        case .httpStatus(429, _, _):
            self = .allowanceSpent
        case .transport:
            self = .offline
        default:
            self = .unavailable
        }
    }

    public var localizedStringResource: LocalizedStringResource {
        switch self {
        case .signedOut: "Open Spark and sign in to ask Flint."
        case .allowanceSpent: "Flint has used today's AI allowance. Try again tomorrow."
        case .offline: "Flint can't reach Spark right now. Check your connection and try again."
        case .unavailable: "Flint couldn't answer that just now."
        }
    }
}
