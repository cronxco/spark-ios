# Spark iOS

The native iOS companion app for [Spark](https://spark.cronx.co). Phase 1 delivers the app skeleton, OAuth round-trip, and a read-only Today view backed by stale-while-revalidate against `/api/v1/mobile/briefing/today`.

## Requirements

- Xcode 26.0 (or Xcode 26 beta at `/Applications/Xcode-beta.app`)
- macOS 15+
- [tuist](https://github.com/tuist/tuist) 4.x — `brew install tuist`
- A Sanctum-backed Spark backend running on `spark.cronx.co` (or a LAN address you expose via App Group defaults — see *Environment overrides* below)

## First-time setup

```bash
git clone git@github.com:willscottuk/spark-ios.git
cd spark-ios
tuist generate
```

`tuist generate` creates `Spark.xcworkspace`. Open it in Xcode 26.

### Provisioning

Every target shares the App Group `group.co.cronx.spark`, the Keychain access group `$(AppIdentifierPrefix)co.cronx.spark`, and the associated domain `applinks:spark.cronx.co`. If you're running on a personal team:

1. In Xcode, select each target → Signing & Capabilities → pick your Team.
2. Let Xcode regenerate provisioning profiles. The App Group, Keychain Sharing, Associated Domains, Push Notifications, and HealthKit capabilities are already declared — Xcode will just need to register the group IDs under your team.
3. `DEVELOPMENT_TEAM` is read from your Xcode user settings; no changes to `Project.swift` required.

### Environment overrides

The default build points at `https://spark.cronx.co`. To swap in a local Sail instance, write two strings into the shared App Group `UserDefaults` (e.g. from a debug build):

```swift
let defaults = UserDefaults(suiteName: "group.co.cronx.spark")!
defaults.set("http://192.168.1.42:8000/api/v1/mobile", forKey: "spark.env.baseURL")
defaults.set("http://192.168.1.42:8000/oauth/authorize", forKey: "spark.env.oauthURL")
defaults.set("lan", forKey: "spark.env.name")
```

Erase the keys to restore production.

## Running

```bash
# Tests — SparkKit SPM layer
cd Packages/SparkKit && swift test

# Tests — full app (requires iOS 26 simulator)
xcodebuild \
    -workspace Spark.xcworkspace \
    -scheme SparkApp \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
    -skipPackagePluginValidation \
    -skipMacroValidation \
    test
```

In Xcode: select the `SparkApp` scheme + an iOS 26 simulator + ⌘R.

## Layout

```
SparkApp/         # @main app target
Extensions/       # Widgets, Controls, LiveActivities, Share, Intents, NotificationService stubs
Watch/            # Phase 5 watchOS stubs
Packages/
  SparkKit/       # Domain, networking, persistence, OAuth, deep-links
  SparkUI/        # Theme tokens + Liquid Glass components
  SparkSync/      # (empty — Phase 3)
  SparkIntelligence/
  SparkHealth/
  SparkLocation/
Tests/            # Cross-target app tests
```

## Release

Versioning follows [gitmoji](https://gitmoji.dev) on the commit subject. CI (`.github/workflows/ios.yml`) runs `xcodebuild test` on every push to `main` / `dev` and every PR. Phase 1 ships as tag `v0.1.0-phase1` to internal TestFlight.

## Sentry

Crash + performance telemetry uses the Sentry project `cronx/spark-ios`. DSN is committed (project-scoped, not a secret); upload auth token is read from `SENTRY_AUTH_TOKEN` at release time. See `.sentryclirc`.
