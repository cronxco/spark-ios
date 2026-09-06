# iOS P0 containment — validated findings and the changes made

## Context

The Outline page **Spark — Product Domains** (`docs.cronx.co/doc/spark-product-domains-oXQSuKm3fB`) records a
product audit completed 1 September 2026. Its first phase is eight security/privacy packages, PSEC-01 … PSEC-08.
Four of them (PSEC-04 … PSEC-07) land wholly or partly on iOS.

All four were re-validated against current code and **all four were present**. The server-side halves are
implemented in `cronxco/spark` on `claude/spark-product-priorities-b49ppr`; the client-side changes are now
implemented here.

> **Not compiled.** This work was done in an environment with no Swift toolchain — and an iOS app cannot be built
> on Linux regardless — so nothing below has been through a compiler, a simulator or a device. The SparkKit tests
> in `ConditionalWriteTests.swift` are the runnable part and still need `swift test`. Treat this as a reviewed
> patch awaiting its first build, not as verified work. Expect strict-concurrency diagnostics first: `signOut`
> now touches `UNUserNotificationCenter`, `UIApplication` and ActivityKit, and
> `scheduleBackgroundImageUpload` became `async`.

Read alongside `docs/Architecture/P0_CONTAINMENT_VALIDATION.md` in the `spark` repo, which covers all eight
packages.

## The branch situation, and why it matters less than it looks

The audit read `1dc11161`, which is **not on `main`**. It is `origin/feature/mobile-api-implementation`, four
commits ahead of `main` — and `main` (`74f595a`) is itself a revert of `0179382`, the first of those commits.

That sounds like it should complicate every finding. It does not: `git diff 74f595a
origin/feature/mobile-api-implementation` is **empty** for `AppModel.swift`, `AuthenticationService.swift`,
`KeychainTokenStore.swift`, `Extensions/SparkShare/`, `SparkApp.swift` and `Project.swift`. All four findings are
byte-identical on both branches.

It matters in exactly one place, noted under PSEC-07: the revert removed `headers` from `Endpoint`, so on `main`
`APIClient` has no mechanism to send `If-Match` at all. The feature branch has that plumbing.

CI is green on both (`ios.yml` runs #29 and #32). One coverage gap was directly relevant: **`SparkShare` was in no
built scheme, so CI never compiled it** — which is why PSEC-06's runtime-only defects survived a green pipeline.
It is now in the `SparkApp` scheme's build action.

---

## PSEC-04 — Complete logout and account-switch purge

**Status: confirmed, and worse than the audit recorded.**

The entire logout path is `AppModel.signOut()` (`SparkApp/Sources/App/AppModel.swift:255-267`).

Cleared today: the Keychain OAuth blob, the ETag cache, `spark.userId`, `spark.apnsDeviceId`, in-memory `profile`,
the Reverb socket, and the server device row (best effort).

**Not cleared:**

- **SwiftData** — never purged. The store lives in the App Group (`SparkDataStore.swift:8,16,24`), so all ten
  cached models survive into the next account. A correct wipe routine already exists but is trapped inside
  `#if DEBUG` at `Settings/DebugView.swift:476-484` and is never called from `signOut()`.
- **App Group defaults** — `spark.profile.name`, `spark.apnsToken`, `onboarding.*`, `health.upload.enabled`,
  `spark.background.mode`, `spark.env.name`, `spark.checkin.legacyCleared.v1`. `spark.profile.name` is re-read at
  init (`AppModel.swift:81-83`), so **the departing user's display name is restored into the next session.**
- **APNs** — no `unregisterForRemoteNotifications()` anywhere, and no `removeAllDeliveredNotifications()`, so the
  old user's delivered notifications stay in Notification Center.
- **Core Spotlight** — `deleteAllSearchableItems()` exists (`SpotlightIndexer.swift:75-84`) but only on a lazy
  BG-processing path (`SparkApp.swift:161-166`). Until iOS schedules that task, the previous user's records stay
  searchable from the system.
- **Recents** — `spark.search.recents` in `UserDefaults.standard` (`Search/SearchView.swift:252-256`), never
  cleared.
- **Retry after offline revocation** — `AppModel.swift:257-259` discards the revoke result (`_ = try?`) and then
  removes `spark.apnsDeviceId` unconditionally on the next line. Offline logout **destroys the only identifier
  needed to retry**, and nothing is queued.

### Server side — done

There was no logout endpoint at all: `routes/mobile.php` had no `logout` and no `oauth/revoke`, so the Sanctum
access and refresh pair stayed valid until natural expiry after every sign-out. Only the push subscription was
revoked.

`POST /api/v1/mobile/logout` now exists (`OAuthController::logout`), gated on `ios:read` so a read-only session can
still sign itself out, and deliberately behind no precondition. It revokes the paired refresh token and deletes the
access token presenting the request, and nothing else — other devices and independently created personal access
tokens are untouched.

### What was done

`signOut()` is now a two-stage coordinator — `revokeRemoteSession()` then `purgeLocalState()` — where the local
half always completes even if every remote call fails. It:

1. Calls `SparkDataStore.purgeAll`, a new SparkKit entry point covering all twelve `SparkSchemaV3` models. The
   equivalent wipe previously existed only inside `#if DEBUG` in `DebugView` and was never called on sign-out.
2. Clears nine enumerated App Group defaults keys plus `spark.search.recents` from `UserDefaults.standard`.
   `spark.env.name` is deliberately kept — it is a build override, not user data.
3. Awaits `SpotlightIndexer.purgeAll()` synchronously rather than waiting for a BGProcessingTask.
4. Ends every Live Activity via `LiveActivityManager.endAll()`, including ones started by a previous launch.
5. Clears delivered notifications, resets the badge, and calls `unregisterForRemoteNotifications()`.
6. Calls `POST /api/v1/mobile/logout` (`SessionEndpoint.logout`).
7. Parks the device id under `spark.pendingDeviceRevocation` when the revoke fails, instead of destroying the only
   identifier a retry needs.
8. Clears `pendingRoute` and reloads widget timelines.

---

## PSEC-05 — Remove unsafe raw presentation

**Status: confirmed, but the audit named the wrong mechanism.**

There is **no** raw-dump fallback for unrecognised card or block types. Every `default:` branch degrades
gracefully — `BlockDetailView.swift:58` → shimmer, `TodayView.swift:251-256` → `EmptyState`,
`FeedSection.swift:427` → placeholder. That part of the finding should be struck from the record.

What is real is an **always-on production raw-payload surface**, not `#if DEBUG` gated:

1. A **"Raw" toolbar button and sheet on every detail screen** — `Shared/SparkAppViewSystem.swift:436-440,
   449-453`. `SparkRawPayloadView` renders the unfiltered HTTP response body as `Text` with a **Copy JSON**
   pasteboard button. `rawPayload` is `response.utf8Body`, set in six view models and attached on seven screens
   (event, object, block, metric, place, integration, knowledge).
2. **`RawFeedJSONView` inlined into Today** (`TodayView.swift:58-60`) with whole response bodies from four
   endpoints (`TodayViewModel.swift:112, 157, 186, 257`), and into three Explore screens
   (`MetricsExploreView:92`, `MoneyExploreView:118`, `HealthExploreView:118`).

### What was done

Both surfaces are wrapped in `#if DEBUG` — the toolbar button and sheet in `SparkAppViewSystem.swift`, and the
`RawFeedJSONView` call sites. More importantly, so is every write that *populates* them
(`TodayViewModel.upsertRawAPIEntry` and the four Explore view-model assignments), so a release build never holds
the payloads in memory at all rather than merely declining to render them. `RawFeedJSONEntry` stays outside the
guard because view models still reference the type. `DebugView.swift:1` is the in-repo precedent.

Still outstanding: a CI grep to stop this being reintroduced.

The web side is clean; the equivalent Blade instances are labelled, collapsed admin affordances rather than
unrecognised-type fallbacks. One malformed Blade block found while checking has been fixed server-side.

---

## PSEC-06 — Make Share capture authenticated, durable and truthful

**Status: confirmed on both branches — but the audit blamed the wrong layer.**

The **entitlements are correctly aligned.** Every target declares `$(AppIdentifierPrefix)co.cronx.sparkapp`
(`Project.swift:5-10,25` and all nine `.entitlements` files). The audit's "misaligned Keychain access group" is not
the problem.

The problem is `ShareViewController.syncAccessToken()`
(`Extensions/SparkShare/Sources/ShareViewController.swift:167-180`), which is wrong three separate ways:

1. `kSecAttrAccessGroup` is the **literal, unexpanded** string `"$(AppIdentifierPrefix)co.cronx.sparkapp"`. Build
   variables expand in `.entitlements` plists, never in Swift string literals — no such access group exists at
   runtime.
2. `kSecAttrService` is `"co.cronx.sparkapp.accessToken"`, but the app writes under `"co.cronx.sparkapp.oauth"` /
   account `"primary"` (`KeychainTokenStore.swift:32-34`). Wrong service, and no `kSecAttrAccount` at all.
3. Even on a hit, the stored value is a JSON `AuthTokens` blob, so it would be sent as `Bearer {"accessToken":…`.

The consequence is worse than a failed upload. `scheduleBackgroundImageUpload` (lines 106-135) opens with
`guard let token = syncAccessToken() else { return }`, so it **never creates the upload task at all** — while
`shareImage` / `shareImageData` (lines 86-104) have *already* shown "Photo saved to Spark." and called `complete()`
unconditionally, before any network call. The JPEG lands in
`group.co.cronx.sparkapp/ShareUploads/<uuid>.jpg` and nothing ever collects it. The telemetry event even reports
`outcome: .success` before `resume()`, on the path that never runs.

Endpoints: `POST /bookmarks` **exists and matches** (`routes/mobile.php:219-221`). `POST check-ins/media` **exists
and the shape matches** (`routes/mobile.php:201-203`) but is unreachable for the reason above. `POST /notes` **does
not exist** — `notes` appears nowhere in `routes/mobile.php` or `routes/api.php` — so text sharing 404s, though at
least it fails loudly.

### What was done

1. **`syncAccessToken()` deleted** in favour of the `KeychainTokenStore()` already in the same file and already
   used correctly by `APIClient`. One deletion removes all three bugs.
2. **`scheduleBackgroundImageUpload` became `async` and returns whether it actually scheduled.** The toast and
   `complete()` now follow the result, and a file that could not be queued is removed rather than left in the
   shared container pretending to be pending work. The telemetry event moved after `resume()`.
3. **Text shares that are wholly a URL become bookmarks**; anything else is declined with "Sharing text isn't
   supported yet." rather than posting to the nonexistent `/notes` and failing. A single-match `NSDataDetector`
   check means a sentence mentioning a URL is not silently turned into a bookmark.
4. **`SparkShare` added to the `SparkApp` scheme's build action** (`Project.swift`), so CI compiles it.

---

## PSEC-07 — Restore the native notification contract

**Status: confirmed on both branches, and materially worse than recorded — the contract was unsatisfiable.**

Four routes required `If-Match`; `RequireIfMatch.php:42-45` returns **428** when it is absent. The client never
sends it (`NotificationsEndpoint.swift:14-26`, `NotificationsPreferencesEndpoint.swift:10-13`, identical on both
branches), so **every shipped inbox control and the preferences save returned 428.**

But the client could not have complied even if it tried: `GET /notifications` exposed no per-notification version
and there is no `GET /notifications/{id}`, so the strong ETag `if-match:notification` demanded was unobtainable.
For `if-match:user`, `MeController` emitted no explicit ETag, so the generic middleware supplied a weak
`W/"md5(body)"` that can never equal `ResourceVersion`'s strong `sha256` — 412 rather than success.

### Server side — done

- `if-match` dropped from `notifications/read-all` and `notifications/{id}/read`. These are idempotent state
  transitions where a lost update is meaningless, so the precondition bought nothing and cost the whole feature.
  **This is a contract change and is reversible if Will disagrees.**
- `DELETE /notifications/{id}` keeps its precondition, and `CompactNotificationResource` now emits `version` so a
  client can satisfy it.
- `MeController` now emits the strong `ResourceVersion` ETag, so `if-match:user` (still used by
  `PATCH /settings/notifications`) is satisfiable by echoing what the read returned.

### APNs vocabulary

`ApnsChannel` set the category to the raw snake_case notification type, producing eleven values. The client
registers five SCREAMING_CASE categories (`SparkApp.swift:197-226`): `ANOMALY`, `DIGEST`, `INTEGRATION_FAILED`,
`NEW_BOOKMARK`, `CALENDAR_EVENT`. **Zero overlap** — identifiers are case-sensitive, so not even
`integration_failed` / `INTEGRATION_FAILED` matched, and every action (`ACKNOWLEDGE`, `VIEW`, `REAUTH`, `SNOOZE`)
was inert.

Server side, `ApnsChannel::CLIENT_CATEGORIES` groups actionable authentication and cookie warnings under
`INTEGRATION_ATTENTION`, integration and migration outcomes under `INTEGRATION_STATUS`, and account-level export,
maintenance, and test notifications under `SYSTEM`. The client registers those same three identifiers and matching
actions.

Notification preferences remain a separate, lower-case vocabulary because they gate individual notification types,
not APNs action groups. `NotificationPreferencesController::CATEGORIES` and the client's preference cases now mirror
the configurable notification types the server emits.

### What was done, client-side

1. **`Endpoint.headers` and `withIfMatch()` re-added**, and applied in `APIClient` — the plumbing the revert
   removed. `RawAPIResponse.etag` was also restored, since the preferences flow needs to read the ETag back.
2. **`DELETE /notifications/{id}` sends `If-Match`**, using the `version` the list payload now carries.
   `NotificationsInboxViewModel.delete` refreshes on a precondition failure and rolls its optimistic removal back
   on any other error. The two optimistic rebuilds in that view model were also dropping `version`, which would
   have broken a subsequent delete.
3. **`PATCH /settings/notifications` sends `If-Match`**, with `NotificationsPreferencesViewModel` holding the ETag
   from the read and retrying exactly once after a stale-version refresh.
4. **`APIError.isPreconditionRequired` / `isPreconditionFailed` / `isPreconditionFailure`** added, with plain-English
   descriptions for 428 and 412.
5. **Deep-link routing fixed** — reads `userInfo["spark"]["deep_link"]` and routes via `AppModel.pendingRoute`.
   The `kind:id` parser inside `AppModel.consumePendingIntentRoute` was extracted to a shared
   `AppModel.route(from:)` so the AppIntent hand-off and notification taps use one vocabulary.
6. **`response.actionIdentifier` is now inspected**: `REAUTH` routes to the integration, `SNOOZE` and dismiss are
   no-ops, everything else follows the deep link or the entity reference.
7. **`If-None-Match` restricted to GET** — the revert had reintroduced attaching it to PATCH/POST/DELETE.

> **Item 5 changes nothing observable yet.** No notification currently sets a deep link: `sparkDeepLink` and its
> siblings are read via `?? nil` on classes that never declare them, so the server has nothing to send. The client
> is now correct and the entity-reference fallback does work, but populating the envelope is outstanding backend
> work.

---

## Verification

None of this has been compiled. It needs:

```bash
tuist generate
cd Packages/SparkKit && swift test --parallel   # incl. ConditionalWriteTests
xcodebuild -workspace Spark.xcworkspace -scheme SparkApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' test
```

Plus the checks the suite cannot make:

- Sign in as A, sign out, sign in as B: no A data in Today, Spotlight, widgets, the share extension or Notification
  Center; A's bearer token returns 401.
- Sign out in airplane mode, reconnect: the revocation completes.
- A release build shows no Raw toolbar button and no `RawFeedJSONView`.
- Share a photo with the app signed out, and signed in: the toast tells the truth in both cases.
- A real-device push of an `integration_failed` notification: the action buttons appear.
