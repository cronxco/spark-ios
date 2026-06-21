import Foundation

public enum AnomaliesEndpoint {
    private static let encoder = JSONEncoder()

    /// POST /anomalies/{id}/acknowledge
    /// id is the MetricTrend UUID from the Up to Speed feed anomaly item.
    public static func acknowledge(
        id: String,
        note: String? = nil,
        suppressUntil: Date? = nil
    ) -> Endpoint<AnomalyAcknowledgeResponse> {
        let body = try? encoder.encode(AnomalyAcknowledgeRequest(note: note, suppressUntil: suppressUntil))
        return Endpoint(
            method: .post,
            path: "/anomalies/\(id)/acknowledge",
            body: body,
            contentType: "application/json"
        )
    }
}
