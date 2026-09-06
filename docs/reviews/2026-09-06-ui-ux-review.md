# Spark iOS UI/UX review — 6 September 2026

Spark has a distinctive visual identity and a useful native foundation. Its biggest opportunity is to make the information hierarchy calmer and its status messages more trustworthy. The highest-priority changes concern misleading states, missing values, contrast, and text scaling; the broader design opportunity is to make Day feel like a concise personal briefing.

## Scope and confidence

Reviewed the source for the five main tabs, Day timeline and check-ins, catch-up, shared navigation/material/type components, representative details, settings, and onboarding. The initial pass scanned 133 Swift files. The follow-up visually inspected populated Day, Explore Health and Money, Knowledge, Flint, and Search on an iPhone 17 Pro Max (440 × 956 points), plus Day at the largest requested text setting and in dark appearance. AXe supplied accessibility labels and element frames after Device Hub automation timed out. Actual VoiceOver speech/focus traversal and physical hit testing are not verified; an accessibility frame is evidence of a small exposed control, not an exhaustive measurement of its touch hit region.

The separate authentication repair restored signed simulator Keychain access; the user confirmed live data now loads. This review continuation changes documentation only, not application code or backend records. It navigated tabs without submitting check-ins, opening catch-up (which may mark content read), or modifying records. Original light appearance and Large text settings were restored. AXe 1.8.0 was installed with approval for this review. Screenshots remain local temporary files and contain private account data; do not publish them without redaction and consent.

Remote freshness checked: iOS HEAD matches fetched `origin/main` at `74f595a`. Backend documentation was compared with fetched `origin/dev` at `32d94f6a`; the local backend is four commits behind, but those changes do not affect the reviewed mobile API contract, OAuth controller, routes, or Sanctum configuration. No branch was switched or merged.

The project targets iOS 27 in `Project.swift:12`. Recommendations concern that deployment target and do not depend on speculative newer APIs.

Fetched live Spark summaries for 5 and 6 September through the authenticated, read-only MCP tool. Confirmed its documented parameters in [MCP.md](/Users/will/Code/spark/docs/API/MCP.md:94), the mobile contract in [mobile_API.md](/Users/will/Code/spark/docs/API/mobile_API.md:221), and that both the MCP tool and mobile briefing controller call `DaySummaryService.generateSummary`. This validates shared data provenance, but is not a direct test of mobile HTTP authentication, caching, or on-device rendering. Private raw responses have not been copied into this report.

Apple guidance was checked through Context7's Apple SwiftUI documentation and current Apple design references. The Axiom skills guided the accessibility, material, and journey checks. Design recommendations below are distinguished from demonstrated source defects; custom typography, custom spacing, and branding are not inherently violations of Apple guidance.

## Surface and journey map

- Five native tabs: Day, Explore, Knowledge, Flint, and Search; Search uses the native search role.
- Navigation stacks handle pushed detail screens; notifications, URLs, and Spotlight provide additional entry points.
- Explore swaps between Health, Money, Metrics, and Map using a bottom accessory.
- Knowledge uses the accessory for filters; Flint uses it for digest periods.
- Day combines a greeting, stats, anomaly status, check-ins, history, and timeline.
- Catch-up uses a full-screen paged experience; check-in and settings flows use sheets.
- Standard buttons, links, pickers, and toggles are common, providing a sound accessibility foundation.
- The scan found five `.onTapGesture` sites, including the history card, plus custom drag interactions requiring contextual validation.
- Typography mixes scalable SF, scalable custom display/mono styles, and explicit system sizes. Forty `.font(.system(size:` matches include icons, so this is not a count of text violations.
- The entire app is capped at accessibility text size 3; no `@ScaledMetric` or size-class adaptations were found in the scanned trees. Absence alone is not proof that every layout fails.
- Some components have good combined labels and selected traits; metric charts already provide an accessibility chart descriptor.
- Loading/error handling exists widely, but catch-up, cached refreshes, and search recovery are inconsistent.

## Priority findings

### 1. High — Catch-up can report success after a failed request

[UpToSpeedView.swift:27](/Users/will/Code/spark-ios/SparkApp/Sources/UpToSpeed/UpToSpeedView.swift:27) chooses between loading, empty, and content without reading `viewModel.error`. [UpToSpeedViewModel.swift:45](/Users/will/Code/spark-ios/SparkApp/Sources/UpToSpeed/UpToSpeedViewModel.swift:45) does record that error. A failed initial request with no screens therefore becomes “You're all caught up!”

The close button is also conditional on a nonempty queue. During initial loading, the visible interface has no Close control, although a custom downward drag can dismiss once the model exists. This is an escape-affordance gap, not proof of an absolute dismiss trap.

**Recommendation:** keep Close present in every state. Distinguish loading, failure with Retry, a verified empty queue, and loaded content. Preserve previously loaded items with a refresh warning. Use semantic foreground colours for the loading text, which is currently white even when the background is light.

**Acceptance:** a failed initial load must never display a success message; loading, failure, and empty states must each have an accessible exit.

### 2. High — Day gives reassurance before it has evidence

[TodaySnapshot.swift:34](/Users/will/Code/spark-ios/SparkApp/Sources/Today/TodaySnapshot.swift:34) turns a missing summary into an empty anomaly array. [TodayView.swift:221](/Users/will/Code/spark-ios/SparkApp/Sources/Today/TodayView.swift:221) treats every empty array as “Baselines holding · 0 anomalies”, including before the first response.

The API explicitly allows absent baseline comparisons when history is insufficient ([mobile_API.md:621](/Users/will/Code/spark/docs/API/mobile_API.md:621)). Live data also includes partial service coverage. An empty list establishes neither complete coverage nor a completed baseline assessment.

**Recommendation:** separate “Loading your day”, “Some sources are still updating”, “Building your baseline”, and “No unusual changes detected in available data”. Show a concise freshness explanation with access to source details. Do not infer freshness solely from a daily metric's midnight event timestamp; use the documented coverage and integration status semantics.

### 3. High — The Heart tile is permanently missing a value

[TodaySnapshot.swift:80](/Users/will/Code/spark-ios/SparkApp/Sources/Today/TodaySnapshot.swift:80) sets `restingHeartRate = nil`. [StatStripView.swift:54](/Users/will/Code/spark-ios/SparkApp/Sources/Today/Cards/StatStripView.swift:54) reads that property, so its value remains “—”. The shared summary service places resting heart rate in `sections.activity.resting_heart_rate.value`, and the live sample contains it.

**Recommendation:** map the real field and label it “Resting heart rate”, including `bpm`. Label sleep as “Sleep score”, with its scale where appropriate. “Heart” and “Sleep” leave the user to infer what a number represents.

Related semantic issue: the optional “Read” tile counts bookmarks, which does not establish completed reading. Rename according to the actual activity represented. The summary's media and knowledge projections also expect some keys absent from the sampled shared-service shape; verify them before using `hasAnyDomainData` to claim that a day is empty.

### 4. High — Primary and selected controls have avoidable contrast failures

**Visually confirmed on the installed simulator build:** the welcome screen's “Get started” button uses white text on bright amber ([captured screen](/tmp/spark-ui-review-day.png)). [PillButton.swift:27](/Users/will/Code/spark-ios/Packages/SparkUI/Sources/SparkUI/Components/PillButton.swift:27) hardcodes white text over tinted glass, so the issue extends to a shared primary-action component. The screenshot confirms the pairing; its rendered glass pixels were not numerically sampled.

[MoneyExploreView.swift:184](/Users/will/Code/spark-ios/SparkApp/Sources/Explore/MoneyExploreView.swift:184) puts adaptive primary text on a fixed amber fill. In dark mode this becomes light text on amber. The delta badge uses the same pairing at line 161. Health's selected range uses adaptive primary text on a fixed green fill ([HealthExploreView.swift:135](/Users/will/Code/spark-ios/SparkApp/Sources/Explore/HealthExploreView.swift:135)).

Calculated from the declared sRGB tokens, opaque white on amber is **1.65:1**, and white on green is **2.24:1**. These calculations concern the solid colour pair, not sampled screen pixels. Both are below the usual 4.5:1 normal-text benchmark. Spark's existing dark ink yields 10.95:1 on amber and 8.07:1 on green.

There is a second appearance risk: the manual Night mode changes the background subtree's colour scheme, while surrounding content keeps the system scheme ([SparkAppBackground.swift:144](/Users/will/Code/spark-ios/Packages/SparkUI/Sources/SparkUI/Theme/SparkAppBackground.swift:144)). Light-mode text can consequently remain dark over a night background.

**Recommendation:** define explicit foreground/background pairs for filled controls. Make theme appearance coherent across content and background, or constrain theme choices to safe palettes for the active system appearance. Validate translucent materials separately in both appearances and accessibility contrast settings.

### 5. High — A global text-size cap masks layout problems

[SparkApp.swift:32](/Users/will/Code/spark-ios/SparkApp/Sources/SparkApp.swift:32) applies a clamp to the entire interface. [Typography.swift:39](/Users/will/Code/spark-ios/Packages/SparkUI/Sources/SparkUI/Theme/Typography.swift:39) caps it at accessibility 3, excluding the two largest preferences even on long-form reading and settings screens.

Day's stats also use 90-point widths and shrink values to 70%; hero lines cannot wrap. The catch-up label uses a fixed 12.5-point system font.

**Recommendation:** remove the app-wide cap after adapting compact layouts. Let summaries and rows stack vertically at accessibility sizes, preserve units, allow titles to wrap, and move the catch-up action beneath the greeting when needed. Limit only genuinely constrained decorative elements. Apple's [large content viewer guidance](https://developer.apple.com/documentation/swiftui/view/accessibilityshowslargecontentviewer(_:)) says it is not a replacement for standard Dynamic Type support.

Do not classify every custom font as fixed: Spark's semantic custom styles use `relativeTo`, and `Font.custom(name, size:)` itself is not the same as `fixedSize:`.

### 6. High — Search prefix shortcuts stop scheduling searches

[SearchViewModel.swift:45](/Users/will/Code/spark-ios/SparkApp/Sources/Search/SearchViewModel.swift:45) returns from `handleQueryChange` whenever the first character matches a mode prefix, before reaching `scheduleSearch()`. Subsequent characters still take that return path. The interface advertises these shortcuts in its suggestions.

**Recommendation:** select the mode, strip the prefix, and schedule the query through one path. Keep a visible Retry action for failed searches; currently the user must change the query or mode to trigger another request. Present human categories first, with prefix syntax as an optional accelerator.

### 7. High — The primary catch-up action is too compact

[TodayView.swift:300](/Users/will/Code/spark-ios/SparkApp/Sources/Today/TodayView.swift:300) explicitly sets the plain-style catch-up button to 32 points high with no local hit-region expansion. Its small text and position beside a scalable hero compound the problem. Several range chips are similarly compact, although their final hit regions need runtime measurement.

**Recommendation:** give the primary action at least a 44-point interaction height, a semantic font, and a predictable standalone position. Use native pickers or consistently sized controls for secondary ranges. Verify hit regions rather than assuming visual padding outside a button enlarges the button.

### 8. Medium — Content and controls share the same glass treatment

[GlassCard.swift:31](/Users/will/Code/spark-ios/Packages/SparkUI/Sources/SparkUI/Components/GlassCard.swift:31) delegates to actual `.glassEffect` through the shared material wrapper. This affects reading cards, statistics, and other ordinary content. Money places another glass range control inside a glass hero; Search puts glass suggestion chips inside a glass card.

Apple reserves Liquid Glass primarily for controls and navigation above content, and cautions against nested glass ([Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)).

**Recommendation:** retain native glass for the tab bar, toolbars, and genuinely floating controls. Give dense content a quiet opaque or conventional material surface. Let simple timeline rows sit directly on the page. Keep gradients restrained behind content. This is the largest visual-system change I recommend.

### 9. Medium — Main screen titles disappear instead of becoming navigation context

[SparkAppViewSystem.swift:90](/Users/will/Code/spark-ios/SparkApp/Sources/Shared/SparkAppViewSystem.swift:90) ignores its title for visual navigation, inserts an empty principal item, and relies on custom content headers. As headers scroll away, the navigation bar cannot show the title. Day adds `SparkSpacing.xl + 72` top padding while ancestors ignore safe areas.

**Recommendation:** use a consistent scroll-to-navigation-title pattern. Keep Comfortaa for a brief editorial hero where useful, but preserve a native screen title after scrolling. Replace Day's accumulated offsets with safe-area-aware composition. Do not claim a current overlap from source alone; verify short screens, rotation, and large text.

### 10. Medium — Knowledge spends space on placeholders while truncating meaning

[KnowledgeView.swift:257](/Users/will/Code/spark-ios/SparkApp/Sources/Knowledge/KnowledgeView.swift:257) always reserves 160 points for imagery, including an oversized decorative placeholder when there is no image. Titles and summaries are each limited to two lines. Labels such as “blocks” expose storage structure rather than reading value.

Live summaries contain long editorial titles and multi-paragraph source summaries, so these are realistic content pressures.

**Recommendation:** feature one editorial lead item, then use compact text-first rows. Omit large placeholder artwork for missing images. Prioritise title, publication/source, and a short useful summary; allow additional title lines at larger text sizes. Replace “blocks” with a meaningful concept only if the underlying data supports it, otherwise omit the count. Do not invent read progress or reading time without a defined derivation.

### 11. Medium — Diagnostics appear in normal content journeys

Raw payload disclosure cards appear on Day, Health, Money, and Metrics without a local debug-build gate. Settings already has a debug-only destination. Knowledge and Search also expose terms such as blocks, entities, and ingestion.

**Recommendation:** move payload inspection to Debug or a deliberately enabled diagnostics mode. Prefer “Saved articles”, “People and places”, “Connected apps”, and “Still updating” where those match the actual entity. Preserve technical detail under an explicit Details section for power users.

### 12. Medium — Charts show shape more clearly than magnitude

[MetricTrendChart.swift:110](/Users/will/Code/spark-ios/Packages/SparkUI/Sources/SparkUI/Charts/MetricTrendChart.swift:110) hides the value axis without providing a point-selection interaction inside the component. The accessibility descriptor exists, which is good, but uses generic “Value” and “Metric trend” names and no summary. The last point is named “Today” even for a historical series.

**Recommendation:** supply the metric name and unit, a useful magnitude cue, selected-point values, and a short textual trend summary. Label the final point “Latest” or with its date. Distinguish missing observations from zeros. Keep the baseline band, but explain what its range means and use a clear insufficient-history state.

### 13. Medium — Editing and history need clearer affordances

[CheckInModalView.swift:73](/Users/will/Code/spark-ios/SparkApp/Sources/CheckIn/CheckInModalView.swift:73) closes immediately while scores and notes live in local state. There is no visible draft-preservation or discard decision. The submit button is below the form. [CheckInHeatmapCard.swift:26](/Users/will/Code/spark-ios/SparkApp/Sources/Today/Cards/CheckInHeatmapCard.swift:26) opens history via a gesture without explicit button semantics at the outer card.

**Recommendation:** use consistent Cancel/Save semantics for editing, preserve meaningful drafts or confirm discarding them, and keep submission discoverable with the keyboard present. Make history a labelled button. Preserve the emoji controls' existing accessible labels and selected traits; add a visible text explanation for the selected rating.

### 14. Medium — Filtering changes location, meaning, and presentation

The bottom accessory controls sections in Explore, filters in Knowledge, and periods in Flint. Explore's four options become a menu in the minimised accessory, while smaller sets stay segmented. Day filters are in its timeline header and Search modes are above results. Health and Money add a separate range-selector family.

**Recommendation:** use one rule: navigation chooses a destination, and filters live beside the content they affect. Put Explore's section choice near the page title, standardise date-range controls, and preserve the active filter visibly during scrolling. The existing accessory is native, but its use as several different kinds of selector needs usability validation; it is not automatically an Apple violation.

### 15. Medium — Freshness and recovery are inconsistent between tabs

Health preserves its dashboard after refresh failure but shows no local failure message in that branch. Knowledge also keeps loaded items without surfacing an error there. Money's error branch replaces content. Catch-up has the more serious false-success problem above.

**Recommendation:** standardise first-load skeletons, true empty states, cached content with an unobtrusive refresh failure, and first-load failure with Retry. Keep the last successful content visible when appropriate. Give the user an honest “last updated” indication rather than silently conflating cached data with fresh data.

### 16. Medium — Onboarding asks for too much before demonstrating value

[OnboardingFlow.swift:12](/Users/will/Code/spark-ios/SparkApp/Sources/Onboarding/OnboardingFlow.swift:12) defines seven steps after the initial hero: sign-in, three HealthKit waves, notifications, location, and completion. Individual permissions may be skippable, but the sequence still asks the user to work through multiple setup decisions.

**Recommendation:** show a useful first Day after sign-in; offer one optional connection, then request further capabilities when the related feature provides a concrete benefit. Keep a visible setup checklist for later. This is a product recommendation, not a claim that Apple imposes a numerical onboarding-screen limit.

**Welcome-screen visual observation:** the Comfortaa heading has a clear identity, the feature rows have an understandable hierarchy, and the bottom action is easy to locate. Supporting grey copy appears faint against the cream surface and merits measured contrast validation. A substantial blank middle region separates the pitch from the action; consider using that space for one compact, explicitly illustrative preview of a useful day. Replace “Knows when something shifts and tells you why” with a promise supported by actual inference quality, such as “See unusual changes, with context from your data.”

## Populated-app validation and additional findings

Evidence captures: [Day](/tmp/spark-review-populated.png), [Health](/tmp/spark-review-health-loaded.png), [Money](/tmp/spark-review-money.png), [Knowledge](/tmp/spark-review-knowledge.png), [Flint](/tmp/spark-review-flint.png), [Search](/tmp/spark-review-search.png), [Day large text](/tmp/spark-review-day-ax5.png), and [Day dark](/tmp/spark-review-day-dark.png). Filenames `spark-review-health.png` and `spark-review-explore.png` are not evidence of Explore: those earlier captures preceded the completed tab transition and still show Day.

### 17. High — Health renders contributor values as physiological changes

The populated hero shows labels including “Body Temperature +100%” and “Resting Heart Rate +39%”. [HealthExploreView.swift:240](/Users/will/Code/spark-ios/SparkApp/Sources/Explore/HealthExploreView.swift:240) applies `formatSigned` to every factor and colours it green. The formatter inserts a plus sign for every nonnegative value.

The documented `hero.factors` shape only supplies label, value, unit, and status; it does not specify a comparison interval or explicitly identify a delta ([mobile_API.md:289](/Users/will/Code/spark/docs/API/mobile_API.md:289)). Backend `HealthDashboardService.heroFactors` copies contributor block values without computing a difference. `OuraReadinessData` imports the source's `contributors` field with a `percent` unit. This is not evidence that body temperature rose 100%; the UI must not imply that it did. The contract itself needs clearer semantics as well as a client correction.

**Recommendation:** add an explicit value kind such as score, measurement, or baseline change; supply scale/comparison/source where applicable. Present a verified contributor score as “Temperature contribution · 100/100”, not “Temperature +100%”. Do not assume the scale for every provider. Only show a signed change when the API establishes that meaning, and derive colour from interpretation rather than sign alone.

**Acceptance:** contributor scores never acquire a delta sign; real changes name their reference and units; no broad “Health looks steady” conclusion is inferred from one readiness measure. Prefer “Readiness is near your usual range”.

### 18. High — “Last synced” is actually the newest event timestamp

Health displayed a time on 7 September while the simulator was on the afternoon of 6 September. [HealthExploreView.swift:657](/Users/will/Code/spark-ios/SparkApp/Sources/Explore/HealthExploreView.swift:657) takes the maximum `sync_status.*.last_event_time` and labels it “Last synced”. The API separately includes `generated_at`, but neither field promises the last successful source sync.

**Recommendation:** display “Latest observation” only when the event semantics justify it; expose actual integration sync completion separately. `generated_at` can describe report generation, not source freshness. Investigate why this source event lies in the future instead of silently clamping it to now. Until resolved, avoid making a freshness promise from it.

**Acceptance:** future observation timestamps do not become future sync times; partial source coverage is visible; missing sync metadata is labelled honestly.

### 19. High — Check-in history contradicts the completed check-in until the view reloads

Day initially showed a completed morning check-in and an entirely empty “LAST 28 DAYS · 0 logged” grid. After leaving and returning to Day, the history showed “1 logged”. This is a stale-view defect, not evidence that the user's check-in was lost.

[CheckInHeatmapCard.swift:27](/Users/will/Code/spark-ios/SparkApp/Sources/Today/Cards/CheckInHeatmapCard.swift:27) loads local history into `@State` only in a date-keyed task. Meanwhile, `TodayViewModel.revalidateCheckIns` saves fresh records through another model context. There is no observed query or refresh revision connecting that update to the heatmap. History also reads only locally cached days, so it cannot claim a complete 28-day remote history after fresh installation.

**Recommendation:** refresh this projection when check-in data changes, and fetch the documented history before making a full-period claim. Show “Loading history” or an explicitly partial state until coverage is established.

**Acceptance:** a completed check-in updates both representations without switching tabs; fresh installs distinguish unrequested history from zero completed days.

### 20. High — Large text destroys the meaning of Day's statistics

At the largest requested system size, the spending figure becomes “£5…” and labels break into fragments such as “STE / PS”, “SPE / NT”, and “HEA / RT”. This happens despite the app-wide accessibility-3 clamp. The catch-up label stays small while its count grows. See the large-text capture; the simulator's starting setting was `large` and was restored.

**Recommendation:** replace the four fixed-width cards with a two-column grid at intermediate sizes and full-width labelled rows at accessibility sizes. Let monetary values and units remain whole. Keep the greeting short, move the action below it, and remove the global cap once the layouts adapt.

**Acceptance:** all five accessibility sizes retain complete amounts, units, labels, and actions without shrink-to-fit or sideways word wrapping.

### 21. Medium — The check-in heatmap is neither readable nor efficient to traverse

Two-digit dates visibly wrap onto two lines at the default size. [CheckInPresentation.swift:149](/Users/will/Code/spark-ios/SparkApp/Sources/CheckIn/CheckInPresentation.swift:149) uses 7-point labels in 8-point columns. The accessibility tree exposes 56 individual AM/PM cells named with only the day number; these lack month context and create a large navigation burden before the timeline. The outer history affordance is a gesture, not a labelled Button.

**Recommendation:** remove the detailed heatmap from calm Day. Replace it with “Check-ins · [verified count] this week” and an explicit History button. Put a larger, properly labelled calendar inside History, with a summary and optional day-by-day exploration. Retain month/year context in accessible dates.

**Acceptance:** no date wrapping; History is exposed as a button; users can skip the grid and hear a useful summary.

### 22. Medium — Day's briefing exposes event vocabulary instead of meaning

The greeting says “Had Balance up 9-day streak is the main signal to keep an eye on so far”; the anomaly strip is simply “Had Balance”. Timeline labels include “Had Receipt”. These technically trace to records but do not tell someone which account, what changed, or why it deserves attention. A rising balance is not inherently a warning.

**Recommendation:** use a presentation vocabulary above raw action identifiers. Name the subject and observation, with a source drill-down. When the subject is unknown, use a modest summary such as “Two changes to review”, not an unsupported personalised conclusion. Avoid making the same vague observation both the briefing and the anomaly headline.

**Acceptance:** the briefing answers what changed and where; no `Had …` event labels escape into editorial copy; claims remain grounded in available fields.

### 23. Medium — Flint's landing experience does not establish its coaching role

The live Flint tab opens directly into a long news roundup. The typography is comfortable for a reader, but there is no visible Flint heading, brief personal orientation, or coaching action before several screens of article prose. “Latest” and “Morning” mix recency and a time slot in the same selector. A newest digest is not necessarily the most useful coaching entry point.

**Recommendation:** make Flint's top level a coaching overview: current focus, one evidence-backed observation, one optional next step, and a question/check-in where supported. Put news and other long digests in a clearly labelled reading section, with summaries opening into a dedicated reader. Preserve the strong serif treatment there. This is a proposed information hierarchy, not permission to generate advice or invent goal/action APIs.

**Acceptance:** the first viewport clearly identifies Flint and its coaching purpose; a news item cannot displace the entire coaching entry point simply by being newest.

### 24. Medium — Search hides its primary input behind another search action

The Search tab's initial screen shows a heading, categories, suggestions, and an upper-right magnifying glass, but no visible text field. The user has already chosen Search and must discover another search control. Categories also mix plain nouns with developer-style prefix syntax.

**Recommendation:** show or immediately reveal the native search field on entering the Search tab, with a clear keyboard/dismiss policy. Keep plain-language categories visible; document prefix shortcuts as optional power-user help. Prefer recent queries or useful examples over a largely empty screen.

**Acceptance:** entering Search makes the input unambiguous without hunting; search modes do not prevent query execution (see finding 6).

### Runtime confirmations of existing findings

- **Heart remains “—” on a populated Day**, confirming finding 3 independently of the previous authentication failure.
- **Small controls:** AXe reports catch-up at 144 × 32 points, pending check-in at about 376 × 27 points, selected Health range at 42 × 24 points, and several timeline filter buttons with icon-sized accessibility frames. These strengthen findings 7 and 13; confirm physical hit regions during remediation rather than assuming glass-container padding belongs to each control.
- **Knowledge truncation:** the real lead title ends in an ellipsis while the next card spends a full image-height region on a decorative placeholder. “Fetch”, “Me”, and “6 blocks” offer weaker reading context than publication/source. This confirms findings 10 and 11.
- **Money chart:** the headline amount is clear, but a nearly flat, axis-free area chart occupies a large fraction of the screen. Add date/value context and point inspection; choose a domain that reveals meaningful variation without exaggerating it. Its allocation section should explicitly distinguish gross assets from net worth and expose liabilities so the totals reconcile.
- **Dark Day:** primary text adapts, but the oversized “your day so far” line remains visually very subdued. No numerical contrast ratio is claimed from this screenshot. The dark theme is not itself a defect; reduce decorative emphasis and measure important supporting copy across the gradient.
- **Double bottom controls:** Health, Money, Knowledge, and Flint place a selector immediately above the tab bar. This is native-capable UI, not intrinsically noncompliant, but its roughly two-row visual footprint competes with content. It is especially costly in Flint's reader. Put local selectors near their subject or expose them in a contextual toolbar/menu where appropriate.

## Confirmed product roles and proposed design direction

The user explicitly confirmed: **Day is the calm personal briefing; Explore is the data dashboard; Flint is the coach.** Consistency should mean shared navigation, colours, terminology, and interaction rules—not identical density. Knowledge remains the reading library and Search the retrieval tool.

| Surface | Proposed hierarchy | Retain |
| --- | --- | --- |
| Day | Date and greeting → short evidence-backed briefing → catch-up/check-in action → three useful signals → timeline | Warm time-of-day mood, personal tone, access to history |
| Explore | Clear section choice → meaningful headline value → context and trend → supporting detail | Health dashboard, accounts, metric catalogue, map |
| Knowledge | One featured article → compact reading list → source and summary → full reader | Long-form serif, rich content, source links |
| Flint | Current focus → prioritised observation → optional next step/question → supporting evidence → digest library | Coaching identity, source drill-down, dedicated long-form reader |
| Search | Search field → understandable categories → useful recent queries → grouped results | Native search tab and advanced shortcuts |
| Details | Value or subject → meaning/context → trend/content → source and advanced details | Shared destinations and entity links |
| Settings/forms | Native grouped presentation, clear labels and consistent cancellation/save | Existing native Form and navigation foundation |

Use Comfortaa sparingly for identity and editorial headings; SF for navigation, controls, and most data; the existing serif for sustained reading; monospaced text for actual technical content and aligned digits when useful. A timestamp need not look like an identifier. Use primary text for facts and actions, secondary for supporting context, and tertiary mainly for nonessential decoration. Apple's [typography guidance](https://developer.apple.com/design/human-interface-guidelines/typography?changes=_5) supports clear hierarchy and scaling meaningful interface icons with text.

The boldest change is to remove the requirement that each piece of information occupy its own glass card. Fewer containers, stronger headings, fuller text labels, and one clear action would make the interface feel more confident and easier to scan.

Real-data constraints for the redesign: preserve units and dates; show partial coverage honestly; handle long names and missing artwork; expose source attribution for overlapping workout records. The observed cross-source workout pairs are evidence that this case exists, not proof that all dashboard endpoints duplicate workouts. Do not merge them solely because titles or times resemble each other.

## Delivery order and acceptance checks

1. Correct misleading catch-up and baseline states, Heart mapping, search prefixes, and solid-fill contrast. These are bounded defects.
2. Adapt large text and primary tap targets; make theme foreground/background handling coherent.
3. Separate content surfaces from glass controls, restore navigation titles, and standardise filters and refresh behaviour.
4. Redesign Day and Knowledge using realistic content; then refine charts, check-in editing, and onboarding.

Before treating the review as visually verified, run the app on a small supported iPhone and a large one; use landscape and supported iPad window sizes; test default text and accessibility 5, light/dark and all manual backgrounds, Increase Contrast, Reduce Transparency, Reduce Motion, and VoiceOver. Exercise empty, partial, stale, failed, long-text, missing-image, large-currency-value, and historical-date cases. Check core flows with a keyboard if iPad is supported. No compliance percentage is claimed from source-pattern counts.

Updated delivery priority: correct Health contributor semantics and false freshness, stale check-in history, missing Heart data, and large-text data loss first. Then reshape Day around one concise briefing and one primary action; retain richer comparison in Explore and give Flint a coaching overview separate from digest reading. Follow with content surfaces, Knowledge density, Search entry, charts, and consistent recovery states.

Outstanding validation: small iPhone, iPad/window resizing, landscape, all text sizes on every tab, Increase Contrast, Reduce Transparency, Reduce Motion, actual VoiceOver focus/action traversal, detailed editing flows, and physical touch hit testing. These remain open; this is not a blanket accessibility conformance claim. Catch-up was deliberately not opened during the live pass to avoid marking the user's items read.

Apple references for this follow-up: [Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/), [Typography](https://developer.apple.com/design/human-interface-guidelines/typography), [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), and [Branding](https://developer.apple.com/design/human-interface-guidelines/branding). The Axiom design/accessibility guidance shaped the content-versus-control separation, large-text checks, semantic labelling, and explicit confidence limits.
