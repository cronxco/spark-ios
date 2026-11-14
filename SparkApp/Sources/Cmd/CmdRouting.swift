import Foundation
import FoundationModels
import SparkKit

/// Where a line typed into Command goes.
enum CmdRouteDecision: Equatable, Sendable {
    /// Something that happened: the Log sheet opens on what was understood.
    case log
    /// A screen to open: the app goes straight there.
    case navigate(CmdDestination)
    /// Anything else: a question, or a request to change, run or note
    /// something. The Flint chat opens with the line as its first message.
    case flint
}

/// What the model says about one line. Strings, as in `LogDraft`: the guide
/// names the allowed values and `decision` reads them forgivingly.
@Generable
struct CmdRoutingDraft {
    @Guide(description: "Exactly one of: log, navigate, flint. log if the line records something that happened. navigate if it asks to open a screen. flint for a question or any other request.")
    var route: String

    @Guide(description: "navigate only: exactly one of day, flint, knowledge, health, money, metrics, tags, map. Empty otherwise.")
    var destination: String?
}

extension CmdRoutingDraft {
    /// The decision this draft makes. Anything unclear goes to Flint: a
    /// question sent there by mistake costs a few seconds, while a question
    /// read as a log opens a sheet that has to be dismissed.
    var decision: CmdRouteDecision {
        switch Self.word(route) {
        case "log":
            return .log
        case "navigate":
            guard let screen = CmdRouter.destination(named: destination ?? "") else { return .flint }
            return .navigate(screen)
        default:
            return .flint
        }
    }

    static func word(_ value: String) -> String {
        value.lowercased().filter(\.isLetter)
    }
}

/// The parts of routing that need no model.
enum CmdRouter {
    /// The names the model, and a typed "show money", may use for a screen.
    private static let destinations: [String: CmdDestination] = [
        "day": .day, "today": .day,
        "flint": .flint,
        "knowledge": .knowledge,
        "health": .exploreHealth,
        "money": .exploreMoney,
        "metrics": .exploreMetrics,
        "tags": .exploreTags,
        "map": .exploreMap,
    ]

    private static let navigationVerbs: Set<String> = ["show", "open", "goto"]

    static func destination(named name: String) -> CmdDestination? {
        destinations[CmdRoutingDraft.word(name)]
    }

    /// Lines the rules are sure about, decided at once: a question or an
    /// `@flint` line is for Flint, and "show money" is a screen. Nil sends
    /// the line to the model.
    static func certain(_ text: String) -> CmdRouteDecision? {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }

        let words = line.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        if words.count == 2 || (words.count == 3 && words[0] == "go" && words[1] == "to") {
            let verb = words.dropLast().joined()
            if navigationVerbs.contains(verb), let screen = destination(named: words[words.count - 1]) {
                return .navigate(screen)
            }
        }

        switch HeuristicCmdClassifier.classifySync(line)?.intent {
        case .ask, .flintNote: return .flint
        default: return nil
        }
    }

    /// The decision when no model can read the line: a short statement the
    /// rules take for a log is a log, and everything else goes to Flint.
    static func fallback(_ text: String) -> CmdRouteDecision {
        guard let classified = HeuristicCmdClassifier.classifySync(text),
            classified.intent == .log, !classified.needsAsk, !classified.isForced
        else { return .flint }
        return .log
    }
}

/// Routes one line with a language model: the on-device model first, so the
/// decision is quick and works offline, and Private Cloud Compute only where
/// the device has no model of its own.
enum CmdRoutingService {
    static let instructions = """
    You route one short line the user typed into an app that holds their personal data: health, sleep, spending, what they watched, read, drank and did.
    Pick log when the line records something that happened to them: a drink, a film, TV episodes, a board game, or a note about their day. "2 pints of Guinness with Dan", "Watched Slow Horses episode 3" and "Long walk by the river, felt good" are log.
    Pick navigate when the line only asks to open a screen: "show my money", "go to the map", "open health". Name the screen in destination.
    Pick flint for a question, or a request to find, explain, change, tag, delete, run, sync or remember something: "how did I sleep", "tag yesterday's lunch as work", "refresh Monzo", "remind Flint I'm away next week".
    If you are not sure, pick flint.
    """

    /// Nil when no model can serve the line, or the model fails: the caller
    /// then decides by rule.
    static let route: @Sendable (String) async -> CmdRouteDecision? = { text in
        for allowPrivateCloudCompute in [false, true] {
            let resolved = FlintModelProvider.resolve(
                reasoning: .light,
                instructions: instructions,
                allowPrivateCloudCompute: allowPrivateCloudCompute
            )
            guard case .success(let model) = resolved else { continue }
            // With PCC allowed and not ready, this is the on-device model
            // that has just failed: don't ask it twice.
            if allowPrivateCloudCompute, model.tier != .privateCloudCompute { return nil }

            do {
                let response = try await model.session.respond(
                    generating: CmdRoutingDraft.self,
                    options: FlintModelProvider.generationOptions(for: .light, maximumResponseTokens: 40),
                    contextOptions: FlintModelProvider.contextOptions(for: .light),
                    metadata: [
                        "spark.generation.path": "cmd_route",
                        "spark.generation.tier": model.tier.rawValue,
                    ]
                ) {
                    "Line: \(text)"
                }
                return response.content.decision
            } catch {
                continue
            }
        }
        return nil
    }
}
