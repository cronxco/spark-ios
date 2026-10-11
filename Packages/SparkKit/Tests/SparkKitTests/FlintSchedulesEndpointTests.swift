import Foundation
import Testing
@testable import SparkKit

@Suite("Flint schedules endpoint")
struct FlintSchedulesEndpointTests {
    @Test("list decodes routines with several times and a cron")
    func listDecodes() throws {
        let json = """
        {"data": [
          {"routine": "topics", "enabled": true,
           "schedule": {"frequency": "daily", "times": ["08:00", "18:00"]},
           "default_time": "21:00", "next_run": "2026-10-13T17:00:00+00:00"},
          {"routine": "money_close", "enabled": false,
           "schedule": {"frequency": "monthly", "day_of_month": 2},
           "default_time": "09:00", "next_run": null},
          {"routine": "news_roundup", "enabled": true,
           "schedule": {"cron": "30 7 * * 1-5"},
           "default_time": "07:00", "next_run": null}
        ]}
        """
        let response = try JSONDecoder().decode(FlintSchedulesResponse.self, from: Data(json.utf8))

        #expect(response.routines.count == 3)
        #expect(response.routines[0].schedule?.times == ["08:00", "18:00"])
        #expect(response.routines[0].nextRun != nil)
        #expect(response.routines[1].schedule?.dayOfMonth == "2")
        #expect(response.routines[1].nextRun == nil)
        #expect(response.routines[2].schedule?.cron == "30 7 * * 1-5")
        #expect(response.routines[2].displayName == "News roundup")
    }

    @Test("update sends a PUT with only the filled fields")
    func updateBody() throws {
        let endpoint = FlintSchedulesEndpoint.update(
            routine: "topics",
            enabled: true,
            schedule: FlintSchedule(frequency: "weekly", days: ["mon", "thu"], times: ["09:00"], cron: "  ")
        )

        #expect(endpoint.method == .put)
        #expect(endpoint.path == "/flint/schedules/topics")
        let body = try #require(endpoint.body)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["enabled"] as? Bool == true)
        #expect(object["frequency"] as? String == "weekly")
        #expect(object["days"] as? [String] == ["mon", "thu"])
        #expect(object["times"] as? [String] == ["09:00"])
        #expect(object["cron"] == nil)
        #expect(object["day_of_month"] == nil)
    }

    @Test("a monthly day of the month goes up as a number, and keywords stay text")
    func dayOfMonthEncoding() throws {
        let numeric = FlintSchedulesEndpoint.update(routine: "money_close", enabled: nil, schedule: FlintSchedule(frequency: "monthly", dayOfMonth: "2"))
        let keyword = FlintSchedulesEndpoint.update(routine: "money_close", enabled: nil, schedule: FlintSchedule(frequency: "monthly", dayOfMonth: "last"))

        let numericBody = try #require(numeric.body)
        let keywordBody = try #require(keyword.body)
        let numericObject = try #require(JSONSerialization.jsonObject(with: numericBody) as? [String: Any])
        let keywordObject = try #require(JSONSerialization.jsonObject(with: keywordBody) as? [String: Any])
        #expect(numericObject["day_of_month"] as? Int == 2)
        #expect(keywordObject["day_of_month"] as? String == "last")
    }
}
