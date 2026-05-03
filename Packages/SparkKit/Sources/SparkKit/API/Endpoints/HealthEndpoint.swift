import Foundation

public enum HealthEndpoint {
    /// POST /health/samples
    public static func submit(samples: [HealthSample]) -> Endpoint<HealthSubmitResponse> {
        let body = try? JSONEncoder().encode(HealthSampleBatch(samples: samples))
        return Endpoint(method: .post, path: "/health/samples", body: body, contentType: "application/json")
    }
}
