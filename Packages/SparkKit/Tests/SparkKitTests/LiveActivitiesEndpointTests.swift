import Foundation
import Testing
@testable import SparkKit

@Suite("Live Activities endpoint")
struct LiveActivitiesEndpointTests {
    @Test("create, rotate, update and end use documented routes and JSON keys")
    func contracts() throws {
        let create = LiveActivitiesEndpoint.create(activityID: "activity", token: "push", type: "sleep", contentState: ["phase": "preparing"])
        #expect(create.method == .post)
        #expect(create.path == "/live-activities")
        let body = try #require(create.body)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(json?["activity_id"] as? String == "activity")
        #expect(json?["activity_type"] as? String == "sleep")
        #expect(json?["push_token"] as? String == "push")

        #expect(LiveActivitiesEndpoint.registerToken(activityID: "7", token: "rotated").path == "/live-activities/7/tokens")
        #expect(LiveActivitiesEndpoint.update(activityID: "7", state: ["phase": "sleeping"]).path == "/live-activities/7")
        #expect(LiveActivitiesEndpoint.end(activityID: "7").path == "/live-activities/7")
    }

    @Test("server token accepts numeric record ID")
    func tokenDecoding() throws {
        let token = try JSONDecoder().decode(LiveActivityToken.self, from: Data("""
        {"id": 7, "activity_id": "activity", "activity_type": "sleep", "starts_at": null, "ends_at": null, "last_pushed_at": null}
        """.utf8))
        #expect(token.id == "7")
        #expect(token.activityID == "activity")
    }
}
