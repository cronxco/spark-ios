import Foundation

public enum FlintSchedulesEndpoint {
    /// GET /flint/schedules
    public static func list() -> Endpoint<FlintSchedulesResponse> {
        Endpoint(method: .get, path: "/flint/schedules", usesETag: false)
    }

    /// PUT /flint/schedules/{routine}
    ///
    /// The backend validates the times and cron and answers `422` with field errors when they are
    /// malformed, so nothing invalid is ever stored.
    public static func update(
        routine: String,
        enabled: Bool?,
        schedule: FlintSchedule
    ) -> Endpoint<FlintRoutineScheduleResponse> {
        var payload: [String: Any] = [:]
        if let enabled { payload["enabled"] = enabled }
        if let frequency = schedule.frequency { payload["frequency"] = frequency }
        if let days = schedule.days, !days.isEmpty { payload["days"] = days }
        if let dayOfMonth = schedule.dayOfMonth, !dayOfMonth.isEmpty {
            payload["day_of_month"] = Int(dayOfMonth) ?? dayOfMonth
        }
        if let times = schedule.times, !times.isEmpty { payload["times"] = times }
        if let cron = schedule.cron, !cron.trimmingCharacters(in: .whitespaces).isEmpty {
            payload["cron"] = cron
        }
        let body = try? JSONSerialization.data(withJSONObject: payload)
        return Endpoint(
            method: .put,
            path: "/flint/schedules/\(routine)",
            body: body,
            contentType: "application/json"
        )
    }
}
