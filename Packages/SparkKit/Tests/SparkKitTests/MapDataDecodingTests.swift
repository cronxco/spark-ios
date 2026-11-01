import Foundation
import Testing
@testable import SparkKit

@Suite("Map data decoding")
struct MapDataDecodingTests {
    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    @Test("decodes markers, with the domain on events and visits on places")
    func decodesMarkers() throws {
        let response = try decoder().decode(MapDataResponse.self, from: Data("""
        {
          "meta": {"date": "2026-10-30", "timezone": "Europe/London"},
          "clusters": [],
          "markers": {
            "events": [{
              "id": "af1e46bc", "kind": "transaction", "lat": 55.8616, "lng": -4.2508,
              "title": "Kaffateria", "subtitle": "£6.80", "time": "2026-10-30T09:40:14+00:00",
              "service": "monzo", "domain": "money", "address": "5 Dundas Street, Glasgow, G1 2AH, United Kingdom"
            }],
            "places": [{
              "id": "aacc948d", "kind": "place", "lat": 55.933, "lng": -3.172,
              "title": "27 Gilmour Road, Edinburgh", "subtitle": null, "time": null, "service": null,
              "visit_count": 1, "last_visit_at": "2026-10-30T14:45:42+00:00", "category": null
            }]
          }
        }
        """.utf8))

        #expect(response.clusters.isEmpty)
        #expect(response.allPoints.count == 2)

        let payment = try #require(response.markers.events.first)
        #expect(payment.kind == .transaction)
        #expect(payment.domain == "money")
        #expect(payment.address == "5 Dundas Street, Glasgow, G1 2AH, United Kingdom")
        #expect(payment.stopTime == payment.time)

        let place = try #require(response.markers.places.first)
        #expect(place.visitCount == 1)
        #expect(place.time == nil)
        #expect(place.stopTime == ISO8601DateFormatter().date(from: "2026-10-30T14:45:42Z"))
    }

    @Test("decodes an older server's markers without the new fields")
    func decodesLegacyMarkers() throws {
        let response = try decoder().decode(MapDataResponse.self, from: Data("""
        {"markers": {"events": [], "places": [{"id": "p", "kind": "place", "lat": 1, "lng": 2, "title": "Home"}]}}
        """.utf8))

        let place = try #require(response.markers.places.first)
        #expect(place.visitCount == nil)
        #expect(place.stopTime == nil)
        #expect(response.clusters.isEmpty)
    }

    @Test("decodes a clustered response, whose markers are an empty array")
    func decodesClusters() throws {
        let response = try decoder().decode(MapDataResponse.self, from: Data("""
        {"clusters": [{"lat": 51.5, "lng": -0.13, "count": 312}, {"lat": 55.86, "lng": -4.25, "count": 240}], "markers": []}
        """.utf8))

        #expect(response.allPoints.isEmpty)
        #expect(response.clusters.count == 2)
        #expect(response.clusters.first?.count == 312)
    }

    @Test("still fails on a malformed marker object")
    func rejectsMalformedMarkers() {
        #expect(throws: DecodingError.self) {
            try decoder().decode(MapDataResponse.self, from: Data("""
            {"markers": {"events": [{"id": "x"}], "places": []}}
            """.utf8))
        }
    }

    @Test("the world box covers every coordinate")
    func worldBox() {
        #expect(BoundingBox.world.queryValue == "-90.0,-180.0,90.0,180.0")
    }
}
