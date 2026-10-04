import Foundation
import Testing
@testable import SparkKit

@Suite("EventRoute decoding")
struct EventRouteDecodingTests {
    @Test("decodes a workout route and its summary")
    func decodesRoute() throws {
        let route = try JSONDecoder().decode(EventRoute.self, from: Data("""
        {
          "points": [{"lat": 51.5, "lng": -0.12}, {"lat": 51.51, "lng": -0.13}, {"lat": 51.505, "lng": -0.11}],
          "total_points": 1840,
          "distance": 5.02,
          "distance_unit": "km",
          "duration_seconds": 1500
        }
        """.utf8))

        #expect(route.points.count == 3)
        #expect(route.points.first == EventRoute.Point(lat: 51.5, lng: -0.12))
        #expect(route.totalPoints == 1840)
        #expect(route.distance == 5.02)
        #expect(route.distanceUnit == "km")
        #expect(route.durationSeconds == 1500)
        #expect(route.isDrawable)

        let bounds = try #require(route.bounds)
        #expect(bounds.minLat == 51.5)
        #expect(bounds.maxLat == 51.51)
        #expect(bounds.minLng == -0.13)
        #expect(bounds.maxLng == -0.11)
        #expect(abs(bounds.centerLat - 51.505) < 0.000_001)
        #expect(abs(bounds.span().lat - 0.013) < 0.000_001)
    }

    @Test("tolerates missing summary fields and short routes")
    func decodesSparseRoute() throws {
        let route = try JSONDecoder().decode(EventRoute.self, from: Data("""
        {"points": [{"lat": 1, "lng": 2}], "distance": null, "distance_unit": null, "duration_seconds": null}
        """.utf8))

        #expect(route.totalPoints == 1)
        #expect(route.distance == nil)
        #expect(!route.isDrawable)
        #expect(route.bounds?.span().lat == 0.005)

        let empty = try JSONDecoder().decode(EventRoute.self, from: Data("{}".utf8))
        #expect(empty.points.isEmpty)
        #expect(empty.bounds == nil)
    }

    @Test("event detail reports whether a route is available")
    func detailHasRouteFlag() throws {
        let withRoute = try JSONDecoder().decode(EventDetail.self, from: Data("""
        {"id": "evt_run", "service": "apple_health", "domain": "health", "action": "did_workout", "has_route": true}
        """.utf8))
        let withoutRoute = try JSONDecoder().decode(EventDetail.self, from: Data("""
        {"id": "evt_tx", "service": "monzo", "domain": "money", "action": "card_payment"}
        """.utf8))

        #expect(withRoute.hasRoute)
        #expect(!withoutRoute.hasRoute)
    }

    @Test("route endpoint reads the event's route without the ETag cache")
    func routeEndpoint() {
        let endpoint = EventsEndpoint.route(id: "evt_run")

        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/events/evt_run/route")
        #expect(endpoint.usesETag == false)
    }
}
