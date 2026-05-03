# Repository Guidelines

## Project Structure & Module Organization

Spark is a Tuist-generated native Swift iOS workspace. `Project.swift` defines the app, extension, watch, and package targets; run `tuist generate` after changing target membership or settings. Main app code lives in `SparkApp/Sources/`, grouped by feature (`Today/`, `Settings/`, `Map/`, `Onboarding/`), with assets and icons in `SparkApp/Resources/`. App extensions live under `Extensions/`, watch targets under `Watch/`, and reusable Swift packages under `Packages/` (`SparkKit`, `SparkUI`, `SparkHealth`, `SparkSync`, `SparkLocation`, `SparkIntelligence`). Cross-target app tests are in `Tests/SparkAppTests/`; package tests live in each package's `Tests/` directory.

## Build, Test, and Development Commands

- `tuist generate` regenerates `Spark.xcworkspace` from `Project.swift`.
- `open Spark.xcworkspace` opens the generated workspace for Xcode development.
- `xcodebuild build -workspace Spark.xcworkspace -scheme SparkApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' -configuration Debug` builds the main app.
- `cd Packages/SparkKit && swift test` runs the fastest package-level unit tests.
- `xcodebuild -workspace Spark.xcworkspace -scheme SparkApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' -skipPackagePluginValidation -skipMacroValidation test` runs the app test scheme.

## Coding Style & Naming Conventions

Use Swift 6.2 with strict concurrency; `Project.swift` treats Swift and GCC warnings as errors. Follow the existing Swift style: four-space indentation, `UpperCamelCase` types, `lowerCamelCase` properties and functions, and feature-focused filenames like `TodayViewModel.swift` or `EventDetailView.swift`. Keep UI in app or extension targets, reusable domain/networking/persistence code in `SparkKit`, and shared visual components in `SparkUI`.

## Testing Guidelines

Tests use Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`). Name tests after observable behavior, for example `productionEnvironmentPointsAtProductionHost`. Add package tests beside the package they cover, such as `Packages/SparkKit/Tests/SparkKitTests/`, and use `Tests/SparkAppTests/` for workspace-level smoke or integration coverage.

## Commit & Pull Request Guidelines

History uses short gitmoji-style subjects, often with scope or phase context, such as `:sparkles: Phase 2 Week 3 D12: Notification preferences` or `:bug: Fix handling bugs`. Keep commits focused and imperative. Pull requests should describe the user-visible change, list testing performed, link the issue or phase task, and include screenshots or recordings for UI changes.

## Security & Configuration Tips

Do not commit personal provisioning changes or local backend URLs. Environment overrides belong in the shared App Group `UserDefaults` keys documented in `README.md`; erase those keys to return to production. Treat release credentials such as `SENTRY_AUTH_TOKEN` as environment variables, not source files.
