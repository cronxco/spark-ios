import Foundation

public enum MapEndpoint {
    /// GET /map/data?bbox=lat1,lng1,lat2,lng2[&date=YYYY-MM-DD]
    public static func points(bbox: BoundingBox, date: Date? = nil) -> Endpoint<[MapDataPoint]> {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "bbox", value: bbox.queryValue)
        ]
        if let date {
            query.append(URLQueryItem(name: "date", value: Self.dayFormatter.string(from: date)))
        }
        return Endpoint(method: .get, path: "/map/data", query: query)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
