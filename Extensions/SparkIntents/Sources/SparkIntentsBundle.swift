import AppIntents

/// Phase 1 stub. Real intents land in Phase 3.
struct PingSparkIntent: AppIntent {
    static let title: LocalizedStringResource = "Ping Spark"
    static let description = IntentDescription("Placeholder intent to prove the target compiles.")

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct SparkAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PingSparkIntent(),
            phrases: ["Ping \(.applicationName)"],
            shortTitle: "Ping Spark",
            systemImageName: "sparkles"
        )
    }
}
