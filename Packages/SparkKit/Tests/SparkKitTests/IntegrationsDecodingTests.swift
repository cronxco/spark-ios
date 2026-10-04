import Foundation
import Testing
@testable import SparkKit

@Suite("Integrations decoding")
struct IntegrationsDecodingTests {
    @Test("list decodes data envelope with null status")
    func listDecodesDataEnvelopeWithNullStatus() throws {
        let json = """
        {
          "data": [
            {
              "id": "fba067e7-675e-4675-8af2-4ae3e6f9f75e",
              "instance_type": "metrics",
              "name": "Metrics",
              "service": "apple_health",
              "status": null
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(IntegrationsEndpoint.ListResponse.self, from: Data(json.utf8))

        #expect(response.data.count == 1)
        #expect(response.data[0].id == "fba067e7-675e-4675-8af2-4ae3e6f9f75e")
        #expect(response.data[0].status == nil)
        #expect(response.data[0].statusValue == "unknown")
    }

    @Test("list decodes non-null status")
    func listDecodesNonNullStatus() throws {
        let json = """
        {
          "data": [
            {
              "id": "integration_1",
              "instance_type": "metrics",
              "name": "Metrics",
              "service": "apple_health",
              "status": "active"
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(IntegrationsEndpoint.ListResponse.self, from: Data(json.utf8))

        #expect(response.data[0].status == "active")
        #expect(response.data[0].statusValue == "active")
    }

    @Test("detail maps null integration status to unknown")
    func detailMapsNullIntegrationStatusToUnknown() throws {
        let json = """
        {
          "integration": {
            "id": "integration_1",
            "instance_type": "metrics",
            "name": "Metrics",
            "service": "apple_health",
            "status": null
          },
          "last_sync_at": null,
          "coverage_percent": null,
          "recent_events": [],
          "oauth_start_url": null,
          "domain": "health",
          "status_message": null
        }
        """

        let detail = try JSONDecoder().decode(IntegrationDetail.self, from: Data(json.utf8))

        #expect(detail.integration.status == nil)
        #expect(detail.status == .unknown)
        #expect(detail.status.label == "Unknown")
    }

    @Test("status mapping covers known statuses and unknown strings")
    func statusMappingCoversKnownStatusesAndUnknownStrings() {
        #expect(Integration(id: "1", service: "s", name: "n", status: nil).statusValue == "unknown")
        #expect(IntegrationDetail(integration: Integration(id: "2", service: "s", name: "n", status: "active")).status == .upToDate)
        #expect(IntegrationDetail(integration: Integration(id: "3", service: "s", name: "n", status: "syncing")).status == .syncing)
        #expect(IntegrationDetail(integration: Integration(id: "4", service: "s", name: "n", status: "needs_reauth")).status == .needsReauth)
        #expect(IntegrationDetail(integration: Integration(id: "5", service: "s", name: "n", status: "broken")).status == .error("broken"))
    }

    @Test("detail decodes the backend's show response")
    func detailDecodesBackendShowResponse() throws {
        // Shape of IntegrationsController::show on the backend.
        let json = """
        {
          "integration": {
            "id": "integration_1",
            "service": "oura",
            "name": "Sleep",
            "instance_type": "sleep",
            "status": "needs_update",
            "domain": "health",
            "paused": false,
            "last_sync_at": "2026-09-26T09:00:00+00:00",
            "next_update_at": "2026-09-26T10:00:00+00:00",
            "schedule_summary": null
          },
          "last_sync_at": "2026-09-26T09:00:00+00:00",
          "coverage_percent": null,
          "recent_events": [
            {
              "id": "event_1",
              "time": "2026-09-26T08:55:00+00:00",
              "service": "oura",
              "domain": "health",
              "action": "had_sleep_score",
              "group_key": "oura:had_sleep_score:object_1"
            }
          ],
          "domain": "health",
          "status_message": "Overdue for an update.",
          "supports_reauth": true,
          "oauth_start_url": "https://spark.cronx.co/api/v1/mobile/integrations/integration_1/oauth/start"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let detail = try decoder.decode(IntegrationDetail.self, from: Data(json.utf8))

        #expect(detail.status == .needsUpdate)
        #expect(detail.status.needsAttention)
        #expect(detail.canReauthorise)
        #expect(detail.recentEvents.count == 1)
        #expect(detail.integration.domain == "health")
        #expect(detail.integration.paused == false)
        #expect(detail.integration.nextUpdateAt != nil)
        #expect(detail.lastSyncAt != nil)
    }

    @Test("reauth falls back to the URL when the backend predates supports_reauth")
    func reauthFallsBackToURL() {
        let integration = Integration(id: "1", service: "oura", name: "Sleep")
        #expect(!IntegrationDetail(integration: integration).canReauthorise)
        #expect(IntegrationDetail(integration: integration, oauthStartURL: URL(string: "https://example.test")).canReauthorise)
        #expect(!IntegrationDetail(integration: integration, oauthStartURL: URL(string: "https://example.test"), supportsReauth: false).canReauthorise)
    }

    @Test("status keys from Integration::statusKey map onto the shared vocabulary")
    func statusKeysMapOntoSharedVocabulary() {
        #expect(IntegrationStatus(rawStatus: "up_to_date") == .upToDate)
        #expect(IntegrationStatus(rawStatus: "processing") == .syncing)
        #expect(IntegrationStatus(rawStatus: "needs_update") == .needsUpdate)
        #expect(IntegrationStatus(rawStatus: "paused") == .paused)
        #expect(IntegrationStatus(rawStatus: "stale") == .stale)
        #expect(!IntegrationStatus.stale.needsAttention)
        #expect(!IntegrationStatus.paused.needsAttention)
        #expect(IntegrationStatus.needsUpdate.label == "Needs update")
        #expect(Integration(id: "1", service: "s", name: "n", status: "stale").statusKind == .stale)
    }

    @Test("last_run decodes and a partial run is not reported as up to date")
    func lastRunPartialOverridesUpToDate() throws {
        let json = """
        {
          "data": [
            {
              "id": "integration_1",
              "service": "monzo",
              "name": "Transactions",
              "status": "up_to_date",
              "last_run": {
                "status": "partial",
                "requested_at": "2026-10-03T09:00:00+00:00",
                "started_at": "2026-10-03T09:00:02+00:00",
                "finished_at": "2026-10-03T09:01:10+00:00",
                "processed_jobs": 3,
                "failed_jobs": 1,
                "error": "Could not save the event"
              }
            }
          ]
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let integration = try decoder.decode(IntegrationsEndpoint.ListResponse.self, from: Data(json.utf8)).data[0]

        let run = try #require(integration.lastRun)
        #expect(run.statusKind == .partial)
        #expect(!run.isInFlight)
        #expect(run.processedJobs == 3)
        #expect(run.failedJobs == 1)
        #expect(run.error == "Could not save the event")
        #expect(run.finishedAt != nil)
        #expect(integration.statusKind == .error("Partly updated"))
        #expect(integration.statusKind.needsAttention)
    }

    @Test("a missing last_run leaves the backend status as it was")
    func missingLastRunFallsBackToStatus() throws {
        let json = """
        { "data": [ { "id": "i1", "service": "oura", "name": "Sleep", "status": "up_to_date" } ] }
        """

        let integration = try JSONDecoder().decode(IntegrationsEndpoint.ListResponse.self, from: Data(json.utf8)).data[0]

        #expect(integration.lastRun == nil)
        #expect(integration.statusKind == .upToDate)
    }

    @Test("a run in flight reads as syncing and a failed run overrides needs_update")
    func runStatesMapOntoIntegrationStatus() {
        let inFlight = Integration(id: "1", service: "s", name: "n", status: "processing", lastRun: IntegrationRun(status: "fetching"))
        #expect(inFlight.lastRun?.isInFlight == true)
        #expect(inFlight.statusKind == .syncing)

        let failed = Integration(id: "2", service: "s", name: "n", status: "needs_update", lastRun: IntegrationRun(status: "failed"))
        #expect(failed.statusKind == .error("Last update failed"))

        let paused = Integration(id: "3", service: "s", name: "n", status: "paused", lastRun: IntegrationRun(status: "failed"))
        #expect(paused.statusKind == .paused)

        let finished = Integration(id: "4", service: "s", name: "n", status: "up_to_date", lastRun: IntegrationRun(status: "up_to_date"))
        #expect(finished.statusKind == .upToDate)

        let unrecognised = Integration(id: "5", service: "s", name: "n", status: "up_to_date", lastRun: IntegrationRun(status: "queued_somewhere"))
        #expect(unrecognised.lastRun?.statusKind == .other("queued_somewhere"))
        #expect(unrecognised.statusKind == .upToDate)
    }

    @Test("a malformed optional last_run field does not fail the integration")
    func lastRunToleratesMalformedFields() throws {
        let json = """
        { "data": [ { "id": "i1", "service": "oura", "name": "Sleep", "status": "up_to_date",
          "last_run": { "status": "failed", "requested_at": 12, "failed_jobs": "one", "error": null } } ] }
        """

        let integration = try JSONDecoder().decode(IntegrationsEndpoint.ListResponse.self, from: Data(json.utf8)).data[0]

        #expect(integration.lastRun?.statusKind == .failed)
        #expect(integration.lastRun?.failedJobs == nil)
        #expect(integration.statusKind == .error("Last update failed"))
    }

    @Test("the detail shows the backend's message for a failed run")
    func detailUsesStatusMessageForFailedRun() {
        let integration = Integration(id: "1", service: "s", name: "n", status: "up_to_date", lastRun: IntegrationRun(status: "partial"))

        #expect(IntegrationDetail(integration: integration).status == .error("Partly updated"))
        #expect(
            IntegrationDetail(integration: integration, statusMessage: "Some of the last update couldn't be processed.").status
                == .error("Some of the last update couldn't be processed.")
        )
    }

    @Test("sync and pause carry the detail read's version as If-Match")
    func conditionalWritesCarryIfMatch() throws {
        let sync = IntegrationsEndpoint.syncNow(id: "i1", etag: "\"v1\"")
        #expect(sync.path == "/integrations/i1/sync")
        #expect(sync.headers["If-Match"] == "\"v1\"")

        let pause = IntegrationsEndpoint.setPaused(id: "i1", paused: true, etag: "\"v1\"")
        #expect(pause.method == .post)
        #expect(pause.path == "/integrations/i1/pause")
        #expect(pause.headers["If-Match"] == "\"v1\"")
        let body = try JSONSerialization.jsonObject(with: #require(pause.body)) as? [String: Bool]
        #expect(body?["paused"] == true)
    }

    @Test("the conflict re-read bypasses the ETag cache")
    func detailForWriteBypassesETagCache() {
        let endpoint = IntegrationsEndpoint.detailForWrite(id: "i1")
        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/integrations/i1")
        #expect(endpoint.usesETag == false)
        #expect(IntegrationsEndpoint.detail(id: "i1").usesETag)
    }
}
