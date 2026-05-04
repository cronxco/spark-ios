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
}
