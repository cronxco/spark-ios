# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Spark iOS** is a native iOS companion app for the Spark personal intelligence platform. Phase 1 delivers the app skeleton, OAuth round-trip authentication, and a read-only Today view with stale-while-revalidate caching against the backend's `/api/v1/mobile/briefing/today` endpoint.

### Key Principles

- **Native Swift everywhere**: SwiftUI, SwiftData, ActivityKit, WidgetKit, App Intents, HealthKit. No WebViews except OAuth.
- **Liquid Glass UI**: iOS 26 visual design system throughout, using native materials and depth.
- **Offline-ready with background sync**: SwiftData is the local source of truth. Silent push + `BGAppRefreshTask` keep data fresh.
- **Ambient computing**: Widgets, StandBy, Dynamic Island, complications mean the app is visible without opening it.

## Tech Stack

- **Language**: Swift 6.2 with strict concurrency enforcement (`SWIFT_STRICT_CONCURRENCY=complete`)
- **Minimum OS**: iOS 26.0 (also watchOS 26.0 for Phase 5)
- **Project generation**: Tuist 4.x (not native Xcode workspace)
- **Package management**: SPM (Swift Package Manager) with 6 local packages + Sentry remote dependency
- **Data persistence**: SwiftData with App Group shared container
- **Authentication**: Sanctum tokens stored in Keychain (shared access group)
- **Networking**: URLSession with async/await, ETag caching, automatic token refresh
- **Testing**: swift-testing (unit), XCUITest (integration), WidgetKit snapshots
- **Observability**: Sentry SDK for crash + performance telemetry

## Repository Structure

```
SparkApp/                    # Main iOS app target (@main)
  Sources/SparkApp.swift     # App entry point, Sentry initialization
  Sources/App/               # RootView, MainTabView, AppModel
  Sources/Auth/              # LoginView (OAuth flow)
  Sources/Today/             # Today view, DayPagerView, TodayViewModel
  Resources/                 # Assets, colors, fonts

Extensions/                  # App extensions (6 targets)
  SparkWidgets/              # WidgetKit (Home/Lock/StandBy)
  SparkControls/             # Control Center widgets (iOS 18+)
  SparkLiveActivities/       # ActivityKit for Live Activities
  SparkShare/                # Share extension (URL/photo/text)
  SparkIntents/              # App Intents for Siri
  SparkNotificationService/  # Rich push notifications

Packages/                    # Local Swift packages (SPM)
  SparkKit/                  # Core domain, networking, persistence
    Sources/SparkKit/
      API/                   # APIClient, APIEnvironment, ETagCache
      Auth/                  # OAuth, KeychainTokenStore, PKCE
      Models/                # Event, Block, Metric, DaySummary, etc.
      Persistence/           # SwiftData models, SparkDataStore
      Sync/                  # DeltaApplier for stale-while-revalidate
      Deeplinks/             # Deep link routing
    Tests/SparkKitTests/
  
  SparkUI/                   # Design system, components (no networking)
    Sources/SparkUI/
      Theme/                 # Colors, spacing, typography
      Materials/             # Liquid Glass effects
      Components/            # MetricCard, EventRow, etc.
  
  SparkSync/                 # Background & real-time (Phase 2+)
  SparkHealth/               # HealthKit integration
  SparkLocation/             # CoreLocation, place detection
  SparkIntelligence/         # App Intents, CoreSpotlight

Watch/                       # Apple Watch (Phase 5 stubs)
Tests/SparkAppTests/         # Cross-target app tests

Project.swift                # Tuist project definition
Tuist.swift                  # Tuist config (Xcode 26, Swift 6.0)
.github/workflows/ios.yml    # CI: runs tests on push/PR to main/dev
```

## Getting Started

### Prerequisites

```bash
# Xcode 26 (or Xcode 26 beta at /Applications/Xcode-beta.app)
# macOS 15+
# Tuist 4.x
brew install tuist

# Backend running on spark.cronx.co (or override via App Group UserDefaults)
```

### Initial Setup

```bash
git clone git@github.com:willscottuk/spark-ios.git
cd spark-ios
tuist generate
```

This creates `Spark.xcworkspace`. Open in Xcode 26.

### Provisioning (Personal Team Setup)

Each target shares:
- **App Group**: `group.co.cronx.spark`
- **Keychain access group**: `$(AppIdentifierPrefix)co.cronx.spark`
- **Associated domain**: `applinks:spark.cronx.co`

In Xcode, for each target:
1. Select target → Signing & Capabilities → pick your Team
2. Xcode auto-registers App Group, Keychain Sharing, Associated Domains, Push Notifications, HealthKit

No Project.swift changes needed; `DEVELOPMENT_TEAM` is auto-read from Xcode user settings.

## Build & Test Commands

### Build

```bash
# Generate Xcode project (required after any Project.swift changes)
tuist generate

# Build main app target
xcodebuild build \
  -workspace Spark.xcworkspace \
  -scheme SparkApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -configuration Debug

# Build from Xcode
# Select SparkApp scheme → iPhone 16 Pro simulator → ⌘B
```

### Test

```bash
# SparkKit unit tests (SPM layer, fastest)
cd Packages/SparkKit && swift test

# Full app tests (requires iOS 26 simulator)
xcodebuild \
  -workspace Spark.xcworkspace \
  -scheme SparkApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  test

# From Xcode
# Select SparkApp scheme → iPhone 16 Pro simulator → ⌘U
```

### Lint & Code Quality

```bash
# SwiftFormat (if configured)
swiftformat --lint .

# Build with warnings-as-errors enabled (default in Project.swift)
xcodebuild \
  -workspace Spark.xcworkspace \
  -scheme SparkApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  build \
  -skipPackagePluginValidation
```

### Environment Overrides

To point at a local backend instead of `spark.cronx.co`, write to the shared App Group `UserDefaults`:

```swift
let defaults = UserDefaults(suiteName: "group.co.cronx.spark")!
defaults.set("http://192.168.1.42:8000/api/v1/mobile", forKey: "spark.env.baseURL")
defaults.set("http://192.168.1.42:8000/oauth/authorize", forKey: "spark.env.oauthURL")
defaults.set("lan", forKey: "spark.env.name")
```

Erase the keys to restore production.

## Architecture Patterns

### 1. Layered Package Model

- **SparkKit** (domain + infra): Models, API client, persistence, auth, sync logic. No UI.
- **SparkUI** (design system): Theme, Liquid Glass components, charts. No networking or business logic.
- **App targets** (UI + orchestration): Views, view models, user interactions. Import both packages.

All extension targets (Widgets, Share, Intents, etc.) depend on SparkKit only (no SwiftUI, lighter footprint).

### 2. Data Flow: Stale-While-Revalidate

Every screen follows this pattern:

1. **Read from SwiftData immediately** (cache from last sync)
2. **Render instantly** from cached data
3. **Fetch in background** — call API in parallel
4. **Compare ETag** — if unchanged, skip update
5. **Apply delta to SwiftData** — if changed, re-render

This keeps the app fast and responsive even on poor networks or in airplane mode.

Example flow in a view model:
```swift
// Immediate render from cache
@Query var cachedEvent: [CachedEvent]

// Background revalidation
Task {
    let response = try await api.request(endpoint: .events, with: etagCache)
    // 304 Not Modified? Skip update.
    // 200 with new data? Apply to SwiftData.
}
```

### 3. Shared Container Pattern

All targets (app + extensions) read/write to:
- **SwiftData**: `ModelContainer` created with App Group URL
- **Keychain**: Shared access group for OAuth tokens
- **UserDefaults**: App Group suite for sync cursors, HealthKit anchors, env overrides

This allows widgets to show live data without re-fetching, and share buttons to use live auth.

### 4. Authentication & Token Refresh

- **Token storage**: Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- **Refresh flow**: APIClient automatically detects 401 → calls token refresh → retries request
- **Refresh rotation**: Old refresh token invalidated on use; replay attempt revokes all device tokens
- **Logout**: DELETE token server-side, wipe Keychain, clear SwiftData, deregister APNs

### 5. Background Sync Strategy

- **Silent push handler** (`UIApplication.didReceiveRemoteNotification`): Extracts `sync_cursor`, fetches `/api/v1/mobile/sync/delta?since={cursor}`, applies deltas to SwiftData, reloads widget timelines (25s budget)
- **`BGAppRefreshTask`** (every 2h): Wakes app, performs delta sync, updates widgets
- **`BGProcessingTask`** (nightly, requires power + connectivity): Heavy lifting — index Spotlight, pre-fetch media, etc.
- **Foreground Reverb WebSocket** (foreground only): Low-latency real-time updates; auto-disconnect on backgrounding to save battery

### 6. Live Activities & APNs

Live Activities (sleep, activity rings) are **server-initiated**:
1. Client registers push token via `POST /api/v1/mobile/live-activities/{id}/tokens`
2. Server signs JWT with APNs `.p8` key, pushes to `apns-topic: co.cronx.spark.push-type.liveactivity`
3. ActivityKit updates the Live Activity state
4. Throttled by server-side Redis (16 pushes/hour per activity)

### 7. SwiftData Caching & Schema

Models in `Packages/SparkKit/Sources/SparkKit/Persistence/Schema/`:
- `CachedEvent`, `CachedObject`, `CachedBlock`, `CachedIntegration`, `CachedPlace`, `CachedMetric`, `CachedAnomaly`, `CachedDaySummary`, `SyncCursor`
- Each has `@Attribute(.unique) var id: String` and `lastSyncedAt: Date`
- Schema versioning via `@VersionedSchema` + migration plan
- TTL conventions: Today 5m, events 15m, integrations 1h, places 24h

All targets using the same schema must depend on `SparkKit` package (enforced by Tuist).

### 8. API Client & Environment

- **APIClient**: Generic `request<T: Decodable>(…)` with retry, backoff, 401 → refresh, ETag support
- **APIEnvironment**: Reads from `UserDefaults` (App Group) for overrides; defaults to `spark.cronx.co`
- **Endpoints**: Organized in `Packages/SparkKit/Sources/SparkKit/API/Endpoints/`

## Key Files to Know

| File | Purpose |
|------|---------|
| `SparkApp/Sources/SparkApp.swift` | App entry point, initializes Sentry, sets up AppModel |
| `SparkApp/Sources/App/AppModel.swift` | Observable app state, SwiftData container, auth state |
| `SparkApp/Sources/App/RootView.swift` | Root navigation (login vs authenticated tabs) |
| `SparkApp/Sources/Today/TodayView.swift` | Card-based Today feed (main surface) |
| `Packages/SparkKit/Sources/SparkKit/API/APIClient.swift` | URLSession wrapper, retry, token refresh |
| `Packages/SparkKit/Sources/SparkKit/Auth/AuthenticationService.swift` | OAuth flow orchestration |
| `Packages/SparkKit/Sources/SparkKit/Persistence/SparkDataStore.swift` | SwiftData container factory |
| `Packages/SparkKit/Sources/SparkKit/Sync/DeltaApplier.swift` | Applies `/sync/delta` responses to SwiftData |
| `Packages/SparkUI/Sources/SparkUI/Theme/` | Design tokens split across `Color+Spark.swift`, `Typography.swift`, `Spacing.swift`, `Radii.swift` |
| `Packages/SparkUI/Sources/SparkUI/Materials/LiquidGlass.swift` | Liquid Glass effect modifiers |
| `Project.swift` | Tuist project definition (targets, dependencies, schemes) |
| `.github/workflows/ios.yml` | CI workflow (runs tests on push/PR) |

## Testing

### Unit Tests (SparkKit)

```bash
cd Packages/SparkKit && swift test --parallel
```

Tests cover:
- APIClient (mocking, retry logic, token refresh)
- KeychainTokenStore (CRUD)
- DeltaApplier (state merges)
- ETagCache
- Auth (PKCE flow)

### Integration Tests (App)

```bash
xcodebuild \
  -workspace Spark.xcworkspace \
  -scheme SparkApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  test
```

Key test files:
- `Tests/SparkAppTests/SparkAppSmokeTests.swift` — basic app launch + auth flow

### Widget Snapshots

Test every family × size class × light/dark × extreme Dynamic Type before each TestFlight cut.

## CI/CD

**GitHub Actions** (`.github/workflows/ios.yml`):
- Runs on every push to `main` / `dev` and every PR
- Caches DerivedData + SPM packages
- Runs `swift test` on SparkKit
- Runs `xcodebuild test` on SparkApp (iPhone 16 Pro, iOS 26 simulator)
- Uploads xcresult on failure

## Version & Release

- **Current version**: 0.1.0 (Phase 1)
- **Versioning**: Commit message subject follows [gitmoji](https://gitmoji.dev) convention
- **Tagging**: Phase 1 ships as `v0.1.0-phase1` to internal TestFlight
- **Sentry**: Project `cronx/spark-ios`, DSN committed (project-scoped), auth token from `SENTRY_AUTH_TOKEN` env at release

## Backend Integration

The app expects a Spark backend running on `spark.cronx.co` (or locally via App Group override) with these endpoints:

### Phase 0 (Backend Foundations) Requirements

All endpoints live under `/api/v1/mobile/*` and require `auth:sanctum` middleware:

| Endpoint | Purpose | Used in |
|----------|---------|---------|
| `GET /briefing/today` | Compact day summary (ETag'd) | Today view, widgets |
| `GET /feed` | Paginated events | Feed/search |
| `GET /sync/delta?since={cursor}` | Delta sync for background refresh | Silent push, BGAppRefreshTask |
| `POST /devices` | Register APNs token | AppModel on first launch |
| `POST /health/samples` | Bulk HealthKit ingestion | SparkHealth package |
| `POST /live-activities` | Start Live Activity | ActivityKit manager |
| `PATCH /live-activities/{id}` | Update LA state | Server-driven via APNs |
| `POST /oauth/token` | PKCE token exchange | OAuth flow |
| `POST /oauth/refresh` | Refresh token rotation | APIClient on 401 |

Backend also provides:
- **WebSockets** (Laravel Reverb): `private-App.Models.User.{id}` channel for real-time updates
- **Silent push** fanout: Every alert push triggers a silent push to sync deltas
- **Universal Links**: `apple-app-site-association` at `/.well-known/`

For local development, see "Environment Overrides" above to point to `http://localhost:8000/api/v1/mobile`.

## Common Workflows

### Adding a New Feature to Today View

1. **Add model to SparkKit**: `Packages/SparkKit/Sources/SparkKit/Models/NewThing.swift`
2. **Add persistent model**: `Packages/SparkKit/Sources/SparkKit/Persistence/Schema/CachedNewThing.swift` (with `@Model`)
3. **Update schema version**: Increment `SchemaV1` and add migration in `Persistence/`
4. **Add API response mapping**: In APIClient endpoint or DeltaApplier
5. **Add UI component**: `Packages/SparkUI/Sources/SparkUI/Components/NewThingCard.swift`
6. **Wire into TodayView**: Import component, render from `@Query var cachedThings`
7. **Test**: Unit test model, snapshot test component, integration test full flow

### Adding a Widget

1. **Create target**: Add to `Extensions/SparkWidgets/Sources/` folder
2. **Link in Project.swift**: Add target definition (already templated)
3. **Share data**: Read from SwiftData via App Group container
4. **Reload timeline**: Widgets auto-reload when `WidgetCenter.shared.reloadAllTimelines()` called from main app or NSE
5. **Test**: WidgetKit snapshot tests for all sizes × schemes

### Debugging SwiftData Cache Issues

1. Check `lastSyncedAt` on records: `po cachedEvent.lastSyncedAt`
2. Verify schema migration ran: Check app logs for "applying schema migration"
3. Clear cache for testing: Delete app from simulator or use Debug menu in AppModel
4. Check ETag cache: `po etagCache.value(for: url)`

### Handling API Changes

If backend changes compact resource format:
1. Update model in `Packages/SparkKit/Sources/SparkKit/Models/`
2. Update CachedModel in `Persistence/Schema/`
3. Create migration: `Persistence/SchemaVx.swift` with version bump
4. Update APIClient endpoint or DeltaApplier to map new fields
5. Add feature flag in backend if rolling out gradually

## Constraints & Gotchas

- **Strict concurrency**: All mutable state must be `@MainActor` or protected by locks. Type-check failures block builds.
- **Warnings as errors**: `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` in all targets. Fix even deprecation warnings.
- **App Group schema sync**: All targets must use the same SwiftData schema. Widget crashes if out of sync.
- **Background budget**: Silent push handler has 25s, BGProcessingTask has ~5m. Prioritize essential data.
- **APNs rate limit**: Live Activities throttled to 16 pushes/hour per activity by server-side Redis.
- **Keychain access**: Only works after first device unlock. Tests may fail if simulator is locked.
- **ETag staleness**: TTL conventions on CachedModels; ignore old data even if cache hit.

## Useful Developer Links

- **Sentry project**: https://sentry.cronx.co/cronx/spark-ios/
- **Apple App Developer**: https://developer.apple.com/account/
- **Tuist docs**: https://docs.tuist.io/
- **SwiftData docs**: https://developer.apple.com/swiftdata/
- **ActivityKit docs**: https://developer.apple.com/activitykit/
- **Liquid Glass**: iOS 26 Glass Effect (`GlassEffectContainer`, `.glassEffect()`)

