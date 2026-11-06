import Foundation
import SparkKit
import Testing

@testable import Spark

@Suite("Explore map day")
struct MapDayTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }

    private func at(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    /// Thursday 30 October 2026, as the backend sends it.
    private var thursday: [MapDataPoint] {
        [
            MapDataPoint(id: "tram", kind: .transaction, lat: 55.9636, lng: -3.1867, title: "Lothian Buses Edtrams", subtitle: "£0.10", time: at("2026-10-30T12:00:03Z"), service: "monzo", domain: "money"),
            MapDataPoint(id: "coffee-2", kind: .transaction, lat: 55.86160, lng: -4.25080, title: "Kaffateria", subtitle: "£6.80", time: at("2026-10-30T09:40:14Z"), service: "monzo", domain: "money"),
            MapDataPoint(id: "coffee-1", kind: .transaction, lat: 55.86161, lng: -4.25081, title: "Kaffateria", subtitle: "£3.30", time: at("2026-10-30T08:33:44Z"), service: "monzo", domain: "money"),
            MapDataPoint(id: "gilmour", kind: .place, lat: 55.933, lng: -3.172, title: "27 Gilmour Road, Edinburgh", visitCount: 1, lastVisitAt: at("2026-10-30T14:45:42Z")),
            MapDataPoint(id: "pollokshaws", kind: .place, lat: 55.824, lng: -4.29, title: "Pollokshaws West", visitCount: 1, lastVisitAt: at("2026-10-30T11:32:20Z")),
            // Saved places visited on other days, or never, are not stops.
            MapDataPoint(id: "sydney", kind: .place, lat: -33.86, lng: 151.2, title: "Sydney", visitCount: 3, lastVisitAt: at("2026-10-26T07:29:33Z")),
            MapDataPoint(id: "station", kind: .place, lat: 51.51, lng: -0.08, title: "Liverpool Street"),
        ]
    }

    @Test("the day's stops are its events and the places last visited that day, in time order")
    func stopsInOrder() {
        let day = calendar.startOfDay(for: at("2026-10-30T12:00:00Z"))
        let stops = MapViewModel.stops(from: thursday, on: day, calendar: calendar)
        #expect(stops.map(\.id) == ["coffee-1", "coffee-2", "pollokshaws", "tram", "gilmour"])
    }

    @Test("stops at the same spot share a pin")
    func pinsGroupBySpot() {
        let day = calendar.startOfDay(for: at("2026-10-30T12:00:00Z"))
        let pins = MapPinGroup.group(MapViewModel.stops(from: thursday, on: day, calendar: calendar))
        #expect(pins.count == 4)
        #expect(pins.first?.stops.map(\.id) == ["coffee-1", "coffee-2"])
    }

    @Test("places sort by visits, then by the latest visit")
    func placesByVisits() {
        let places = thursday.filter { $0.kind == .place }
        #expect(MapViewModel.sorted(places, by: .visits).map(\.id) == ["sydney", "gilmour", "pollokshaws", "station"])
        #expect(MapViewModel.sorted(places, by: .recent).first?.id == "gilmour")
        #expect(MapViewModel.sorted(places, by: .name).first?.id == "gilmour")
    }

    @Test("a place's context counts its visits; an event's is its address")
    func context() {
        let gilmour = thursday.first { $0.id == "gilmour" }
        let sydney = thursday.first { $0.id == "sydney" }
        #expect(gilmour?.mapContext == "First visit")
        #expect(sydney?.mapContext == "3 visits")
        let paid = MapDataPoint(id: "x", kind: .transaction, lat: 0, lng: 0, title: "Kaffateria", address: "5 Dundas Street, Glasgow")
        #expect(paid.mapContext == "5 Dundas Street, Glasgow")
    }

    @Test("stop times are exact and 24-hour, in local time")
    func stopTimes() {
        let london = TimeZone(identifier: "Europe/London")!
        let coffee = thursday.first { $0.id == "coffee-2" }
        let gilmour = thursday.first { $0.id == "gilmour" }
        let station = thursday.first { $0.id == "station" }
        #expect(coffee?.stopTimeLabel(in: london) == "09:40")
        #expect(gilmour?.stopTimeLabel(in: london) == "14:45")
        #expect(station?.stopTimeLabel(in: london) == nil)
        let late = MapDataPoint(id: "late", kind: .transaction, lat: 0, lng: 0, title: "Late", time: at("2026-07-01T23:05:00Z"))
        #expect(late.stopTimeLabel(in: london) == "00:05")
    }

    @Test("a failed load says what failed, not that the map is unavailable")
    func failureWording() {
        let url = URL(string: "https://spark.cronx.co/api/v1/mobile/map/data")!
        let server = MapViewModel.failure(for: APIError.httpStatus(500, nil, url))
        #expect(server.title == "Spark couldn’t load this day")
        #expect(server.message.contains("HTTP 500"))

        #expect(MapViewModel.failure(for: APIError.transport(URLError(.notConnectedToInternet))).title == "You’re offline")
        #expect(MapViewModel.failure(for: APIError.unauthorized).title == "Signed out")
        #expect(MapViewModel.failure(for: APIError.decoding(CocoaError(.coderReadCorrupt))).title == "Couldn’t read this day")
    }
}
