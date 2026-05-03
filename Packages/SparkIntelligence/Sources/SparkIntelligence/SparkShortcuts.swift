import AppIntents

/// Publishes Spark's curated App Shortcuts to Siri and the Shortcuts app.
/// Phrases containing "$(applicationName)" work in any language; Siri
/// substitutes the app name automatically.
public struct SparkShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetSleepScoreIntent(),
            phrases: [
                "What's my sleep score in \(.applicationName)",
                "How did I sleep in \(.applicationName)",
            ],
            shortTitle: "Sleep Score",
            systemImageName: "moon.fill"
        )
        AppShortcut(
            intent: GetStepsTodayIntent(),
            phrases: [
                "How many steps today in \(.applicationName)",
                "Step count in \(.applicationName)",
            ],
            shortTitle: "Steps Today",
            systemImageName: "figure.walk"
        )
        AppShortcut(
            intent: GetSpendTodayIntent(),
            phrases: [
                "How much did I spend today in \(.applicationName)",
                "Daily spend in \(.applicationName)",
            ],
            shortTitle: "Daily Spend",
            systemImageName: "creditcard.fill"
        )
        AppShortcut(
            intent: GetReadinessIntent(),
            phrases: [
                "What's my readiness score in \(.applicationName)",
                "Am I ready for today in \(.applicationName)",
            ],
            shortTitle: "Readiness",
            systemImageName: "heart.fill"
        )
        AppShortcut(
            intent: LogCheckInIntent(),
            phrases: [
                "Log a check-in in \(.applicationName)",
                "How am I feeling in \(.applicationName)",
            ],
            shortTitle: "Check-In",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: OpenTodayIntent(),
            phrases: [
                "Open \(.applicationName) Today",
                "Show my day in \(.applicationName)",
            ],
            shortTitle: "Open Today",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: SearchSparkIntent(),
            phrases: [
                "Search \(.applicationName)",
            ],
            shortTitle: "Search Spark",
            systemImageName: "magnifyingglass"
        )
    }
}
