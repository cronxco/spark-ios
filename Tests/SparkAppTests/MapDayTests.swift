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
}
