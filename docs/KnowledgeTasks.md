# Knowledge tasks and projects

Branch `feat/tasks-projects` targets `main`. Backend branch targets Spark `dev`. Canonical scope: https://docs.cronx.co/doc/feature-plan-tasks-projects-yR0SgCAZ0n.

Knowledge has Tasks and Projects sections. Tasks support Inbox/Today/All/History/Deleted, search, calendar dates in the captured task timezone, day/week/persistent duration, deadlines/review/exact reminders, priority/order, recurrence, project/thread links, related context, activity, complete/reopen/cancel/reactivate/delete/restore and bulk operations. Projects support outcome/status/target/next action/progress and removal without deleting tasks. Looking Ahead task rows open the canonical task in Knowledge.

Task and project deep links route to Knowledge. Integration recovery links and notification Reconnect actions retain reauthentication intent and reuse the existing OAuth coordinator. A cancelled flow does not resolve the incident; backend verification does.

Task capture/edit/actions are saved to a protected, atomic JSON outbox before transport, scoped to account and API environment. Restart preserves pending bodies and mutation IDs. Transport/5xx failures retry; validation, authorization and version conflicts remain visible without automatic overwrite. Existing tasks remain canonical until the server acknowledges a change. One pending change per task avoids silently composing commands against stale versions. Logout erases task caches/outboxes and invalidates in-flight persistence. Project writes require connectivity.

Portable Swift contract tests run in Linux; full app source parses and the offline store is type-checked with stubbed API dependencies. Native app integration tests have been added for restart/replay, version conflict and routing, but have not been run here. Before release, run Tuist generation, Xcode builds and the native suites, then test VoiceOver/Dynamic Type, offline termination/restart/logout, account/environment switching and physical-device OAuth/APNs routes.

Outline write-back is implemented on the server but blocked by default until the deployed provider proves conditional revision writes and marker/formatting round trips. The UI shows pending/blocked/conflict/error state and offers the source link and Retry. This branch does not certify that provider.

Remaining accepted product scope is tracked in the canonical plan and backend `docs/Guides/KnowledgeTasks.md`: entity-detail quick capture, project-level context links, future-series/end-date editing, proposal editing before acceptance, richer reminder presets, full historical relationships and an explicit offline draft-merge editor. These branches are a substantial initial implementation, not a claim that every acceptance journey or release gate is complete.
